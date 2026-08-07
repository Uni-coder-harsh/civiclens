import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_providers.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/vibration_payload.dart';
import '../data/fft_analyzer.dart';
import '../data/sensor_recorder.dart';
import '../data/traffic_trigger.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum BridgeCheckPhase {
  /// Initial state — show instructions.
  idle,

  /// Waiting for phone to be placed flat on deck.
  awaitingFlat,

  /// Phone is flat; listening for traffic spike to auto-trigger.
  detecting,

  /// 30-second recording in progress.
  recording,

  /// FFT computation running on isolate.
  computing,

  /// Result available.
  done,

  /// Error occurred.
  error,
}

class BridgeCheckState {
  final BridgeCheckPhase phase;
  final bool phoneFlatOnDeck;
  final bool trafficTriggered;
  final int recordingElapsedMs;
  final FftSummary? fftSummary;
  final AcousticDiagnosticResult? result;
  final String? errorMessage;

  const BridgeCheckState({
    this.phase = BridgeCheckPhase.idle,
    this.phoneFlatOnDeck = false,
    this.trafficTriggered = false,
    this.recordingElapsedMs = 0,
    this.fftSummary,
    this.result,
    this.errorMessage,
  });

  BridgeCheckState copyWith({
    BridgeCheckPhase? phase,
    bool? phoneFlatOnDeck,
    bool? trafficTriggered,
    int? recordingElapsedMs,
    FftSummary? fftSummary,
    AcousticDiagnosticResult? result,
    String? errorMessage,
  }) {
    return BridgeCheckState(
      phase: phase ?? this.phase,
      phoneFlatOnDeck: phoneFlatOnDeck ?? this.phoneFlatOnDeck,
      trafficTriggered: trafficTriggered ?? this.trafficTriggered,
      recordingElapsedMs: recordingElapsedMs ?? this.recordingElapsedMs,
      fftSummary: fftSummary ?? this.fftSummary,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class BridgeCheckController extends Notifier<BridgeCheckState> {
  final _trigger = TrafficTrigger();
  final _recorder = SensorRecorder();

  StreamSubscription<void>? _trafficSub;
  StreamSubscription<FlatCheckResult>? _flatSub;
  Timer? _elapsedTimer;

  @override
  BridgeCheckState build() {
    ref.onDispose(_cleanup);
    return const BridgeCheckState();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call when user taps "Start Bridge Check" — transitions to [awaitingFlat].
  void beginFlatcheckPhase() {
    _cleanup();
    state = const BridgeCheckState(phase: BridgeCheckPhase.awaitingFlat);
    _trigger.start();

    // Listen for flatness changes.
    _flatSub = _trigger.flatnessChanged.listen(_onFlatnessChanged);

    // Listen for traffic spikes — only act when flat.
    _trafficSub = _trigger.trafficDetected.listen((_) => _onTrafficSpike());
  }

  /// Called when user manually taps the mic button (bypass auto-trigger).
  Future<void> startRecordingManually() async {
    if (state.phase != BridgeCheckPhase.detecting) return;
    await _startRecording(triggered: false);
  }

  /// Reset back to idle.
  void reset() {
    _cleanup();
    state = const BridgeCheckState(phase: BridgeCheckPhase.idle);
  }

  // ── Internal state transitions ─────────────────────────────────────────────

  void _onFlatnessChanged(FlatCheckResult flatness) {
    final isFlat = flatness == FlatCheckResult.flat;
    if (state.phase == BridgeCheckPhase.awaitingFlat && isFlat) {
      state = state.copyWith(
        phase: BridgeCheckPhase.detecting,
        phoneFlatOnDeck: true,
      );
    } else if (state.phase == BridgeCheckPhase.detecting && !isFlat) {
      state = state.copyWith(
        phase: BridgeCheckPhase.awaitingFlat,
        phoneFlatOnDeck: false,
      );
    } else {
      state = state.copyWith(phoneFlatOnDeck: isFlat);
    }
  }

  Future<void> _onTrafficSpike() async {
    if (state.phase != BridgeCheckPhase.detecting) return;
    if (!state.phoneFlatOnDeck) return;
    await _startRecording(triggered: true);
  }

  Future<void> _startRecording({required bool triggered}) async {
    // Cancel flatness/traffic subscriptions — we're now recording.
    _trafficSub?.cancel();
    _flatSub?.cancel();

    state = state.copyWith(
      phase: BridgeCheckPhase.recording,
      trafficTriggered: triggered,
      recordingElapsedMs: 0,
    );

    // Tick elapsed timer every 500ms for UI progress display.
    final startTime = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final elapsed =
          DateTime.now().difference(startTime).inMilliseconds;
      state = state.copyWith(recordingElapsedMs: elapsed);
    });

    try {
      final result = await _recorder.record();
      _elapsedTimer?.cancel();

      state = state.copyWith(phase: BridgeCheckPhase.computing);
      await _computeAndSubmit(result, triggered: triggered);
    } catch (e) {
      _elapsedTimer?.cancel();
      state = state.copyWith(
        phase: BridgeCheckPhase.error,
        errorMessage: 'Recording failed: $e',
      );
    }
  }

  Future<void> _computeAndSubmit(
    RecordingResult recording, {
    required bool triggered,
  }) async {
    try {
      // Run FFT on a compute() isolate — never on the UI thread.
      final fft = await analyzeAccelSamples(
        samples: List<double>.from(recording.accelZSamples),
        sampleRateHz: recording.actualSampleRateHz,
      );

      state = state.copyWith(fftSummary: fft);

      // Build VibrationPayload.
      final session = ref.read(authSessionProvider);
      final capture = GeoCapture(
        latitude: 0,
        longitude: 0,
        altitudeMeters: 0,
        accuracyMeters: 0,
        bearingDegrees: 0,
        speedMps: 0,
        capturedAtUtc: DateTime.now().toUtc(),
      );

      final payload = VibrationPayload(
        id: const Uuid().v4(),
        userId: session.userId,
        capture: capture,
        durationMs: recording.durationMs,
        channels: [
          SensorChannel(
            name: 'accel_z',
            sampleRateHz: recording.actualSampleRateHz,
            // WAV is sent as a multipart file — accelZ summary only in metadata.
            samples: const [], // intentionally empty; raw data is in wavPath
            encoding: 'float32',
          ),
        ],
        fftSummary: fft,
        phoneFlatOnDeck: state.phoneFlatOnDeck,
        trafficTriggered: triggered,
      );

      // Submit to API.
      final api = ref.read(apiClientProvider);
      final diagnosticResult = await api.submitAcousticDiagnostic(payload);

      state = state.copyWith(
        phase: BridgeCheckPhase.done,
        result: diagnosticResult,
      );
    } catch (e) {
      state = state.copyWith(
        phase: BridgeCheckPhase.error,
        errorMessage: 'Analysis failed: $e',
      );
    }
  }

  void _cleanup() {
    _trafficSub?.cancel();
    _flatSub?.cancel();
    _elapsedTimer?.cancel();
    _trigger.dispose();
    _recorder.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final bridgeCheckControllerProvider =
    NotifierProvider<BridgeCheckController, BridgeCheckState>(
  BridgeCheckController.new,
);
