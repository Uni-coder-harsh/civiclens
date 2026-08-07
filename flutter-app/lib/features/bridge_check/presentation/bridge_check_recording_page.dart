import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/bridge_check_controller.dart';

/// Route: `/bridge-check/recording`
///
/// Shows the live recording UI:
/// - Flatness indicator (is phone flat on deck?)
/// - Auto-trigger banner when a spike is detected
/// - Live waveform drawn by [CustomPainter] fed via a [StreamController<double>]
///   — NO setState at 200 Hz
/// - Phase banner
class BridgeCheckRecordingPage extends ConsumerStatefulWidget {
  const BridgeCheckRecordingPage({super.key});

  @override
  ConsumerState<BridgeCheckRecordingPage> createState() =>
      _BridgeCheckRecordingPageState();
}

class _BridgeCheckRecordingPageState
    extends ConsumerState<BridgeCheckRecordingPage> {
  // The waveform stream — fed by sensor data, consumed by CustomPainter.
  // Never triggers setState; the painter subscribes directly.
  final _waveformStream = StreamController<double>.broadcast();

  @override
  void initState() {
    super.initState();
    // Kick off the flatcheck phase as soon as the recording page appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bridgeCheckControllerProvider.notifier).beginFlatcheckPhase();
    });
  }

  @override
  void dispose() {
    _waveformStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bridgeCheckControllerProvider);

    // Navigate to verdict page when done.
    ref.listen<BridgeCheckState>(bridgeCheckControllerProvider, (prev, next) {
      if (next.phase == BridgeCheckPhase.done ||
          next.phase == BridgeCheckPhase.error) {
        if (context.mounted) {
          context.pushReplacement('/bridge-check/verdict');
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1C),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            ref.read(bridgeCheckControllerProvider.notifier).reset();
            context.pop();
          },
        ),
        title: Text(
          _phaseTitle(state.phase),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          children: [
            // ── Flatness indicator ────────────────────────────────────────
            _FlatnessIndicator(isFlat: state.phoneFlatOnDeck),
            const SizedBox(height: 24),

            // ── Phase status banner ───────────────────────────────────────
            _PhaseBanner(phase: state.phase),
            const SizedBox(height: 24),

            // ── Waveform ─────────────────────────────────────────────────
            Expanded(
              child: _WaveformCanvas(stream: _waveformStream.stream),
            ),

            const SizedBox(height: 24),

            // ── Progress & actions ────────────────────────────────────────
            if (state.phase == BridgeCheckPhase.recording) ...[
              _RecordingProgress(elapsedMs: state.recordingElapsedMs),
            ] else if (state.phase == BridgeCheckPhase.detecting) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(bridgeCheckControllerProvider.notifier)
                      .startRecordingManually(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF818CF8),
                    side: const BorderSide(color: Color(0xFF818CF8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.fiber_manual_record_rounded),
                  label: const Text(
                    'Record Manually',
                    style: TextStyle(
                        fontFamily: 'Inter', fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else if (state.phase == BridgeCheckPhase.computing) ...[
              const _ComputingIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  String _phaseTitle(BridgeCheckPhase phase) {
    switch (phase) {
      case BridgeCheckPhase.awaitingFlat:
        return 'Place Phone Flat';
      case BridgeCheckPhase.detecting:
        return 'Awaiting Traffic';
      case BridgeCheckPhase.recording:
        return 'Recording...';
      case BridgeCheckPhase.computing:
        return 'Analysing...';
      default:
        return 'Bridge Check';
    }
  }
}

// ── Flatness Indicator ────────────────────────────────────────────────────────

class _FlatnessIndicator extends StatelessWidget {
  final bool isFlat;

  const _FlatnessIndicator({required this.isFlat});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isFlat
            ? const Color(0xFF10B981).withOpacity(0.12)
            : const Color(0xFFF59E0B).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFlat
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFFF59E0B).withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFlat ? Icons.check_circle_rounded : Icons.phone_android_rounded,
            color: isFlat ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            isFlat
                ? 'Phone flat on deck ✓'
                : 'Place phone flat on bridge surface',
            style: TextStyle(
              color:
                  isFlat ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phase Banner ──────────────────────────────────────────────────────────────

class _PhaseBanner extends StatelessWidget {
  final BridgeCheckPhase phase;

  const _PhaseBanner({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (text, color, icon) = switch (phase) {
      BridgeCheckPhase.awaitingFlat => (
          'Waiting for phone to be flat...',
          const Color(0xFFF59E0B),
          Icons.hourglass_empty_rounded,
        ),
      BridgeCheckPhase.detecting => (
          'Waiting for vehicle spike to auto-trigger',
          const Color(0xFF818CF8),
          Icons.sensors_rounded,
        ),
      BridgeCheckPhase.recording => (
          'Recording active — stay clear of traffic!',
          const Color(0xFFEF4444),
          Icons.fiber_manual_record_rounded,
        ),
      BridgeCheckPhase.computing => (
          'Running FFT analysis on your device...',
          const Color(0xFF3B82F6),
          Icons.bar_chart_rounded,
        ),
      _ => ('Ready', const Color(0xFF94A3B8), Icons.info_outline_rounded),
    };

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Live Waveform (CustomPainter — no setState) ───────────────────────────────

class _WaveformCanvas extends StatefulWidget {
  final Stream<double> stream;

  const _WaveformCanvas({required this.stream});

  @override
  State<_WaveformCanvas> createState() => _WaveformCanvasState();
}

class _WaveformCanvasState extends State<_WaveformCanvas> {
  final _repaint = ValueNotifier<int>(0);
  final _painter = _WaveformPainter();
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen((val) {
      // Push to painter data buffer, then signal repaint via ValueNotifier.
      // No setState — painter redraws itself via the AnimatedBuilder below.
      _painter.push(val);
      _repaint.value++;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: AnimatedBuilder(
        animation: _repaint,
        builder: (context, _) => CustomPaint(
          painter: _painter,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final _samples = <double>[];
  static const int _maxSamples = 200;

  _WaveformPainter();

  void push(double value) {
    _samples.add(value);
    if (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_samples.isEmpty) {
      _drawIdleLine(canvas, size);
      return;
    }

    final paint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final midY = size.height / 2;
    final xStep = size.width / _maxSamples;

    // Normalise samples to ±1 range.
    double maxAbs = _samples.map((s) => s.abs()).reduce(max);
    if (maxAbs < 0.001) maxAbs = 1.0;

    final path = Path();
    for (var i = 0; i < _samples.length; i++) {
      final x = i * xStep;
      final y = midY - (_samples[i] / maxAbs) * (size.height * 0.4);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawIdleLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.5;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => true;
}

// ── Recording Progress ────────────────────────────────────────────────────────

class _RecordingProgress extends StatelessWidget {
  final int elapsedMs;

  const _RecordingProgress({required this.elapsedMs});

  @override
  Widget build(BuildContext context) {
    const totalMs = 30000.0;
    final progress = (elapsedMs / totalMs).clamp(0.0, 1.0);
    final remaining = ((totalMs - elapsedMs) / 1000).ceil();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF1E293B),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFEF4444)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$remaining s remaining',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontFamily: 'Inter',
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ── Computing Indicator ───────────────────────────────────────────────────────

class _ComputingIndicator extends StatelessWidget {
  const _ComputingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF3B82F6)),
          strokeWidth: 3,
        ),
        SizedBox(height: 12),
        Text(
          'Running FFT on-device...',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
