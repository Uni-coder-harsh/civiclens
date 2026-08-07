import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';

/// Result returned when a recording window completes.
class RecordingResult {
  /// Path to the WAV file on disk (microphone audio).
  final String wavPath;

  /// All z-axis accelerometer samples collected during the window.
  final List<double> accelZSamples;

  /// Approximate sample rate achieved (samples / elapsed seconds).
  final int actualSampleRateHz;

  /// Duration of the recording window in milliseconds.
  final int durationMs;

  const RecordingResult({
    required this.wavPath,
    required this.accelZSamples,
    required this.actualSampleRateHz,
    required this.durationMs,
  });
}

/// Orchestrates a 30-second concurrent recording of:
///   • Microphone audio → WAV file on disk.
///   • Accelerometer z-axis samples → in-memory list.
///
/// Callers receive a [RecordingResult] when the window elapses.
/// The WAV file must be uploaded as multipart — NOT inlined as JSON.
class SensorRecorder {
  static const int _windowMs = 30000; // 30 second window

  final _audioRecorder = AudioRecorder();
  StreamSubscription<AccelerometerEvent>? _accelSub;

  final List<double> _accelZ = [];
  DateTime? _startTime;

  bool get isRecording => _accelSub != null;

  /// Start a 30-second concurrent audio + accelerometer recording.
  ///
  /// Returns a [RecordingResult] after [_windowMs] ms, or sooner if
  /// [stop] is called.
  Future<RecordingResult> record() async {
    final dir = await getTemporaryDirectory();
    final wavPath = '${dir.path}/bridge_accel_${const Uuid().v4()}.wav';

    // Start microphone recording to WAV.
    await _audioRecorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 705600, // 16-bit * 44100 * 1 channel
      ),
      path: wavPath,
    );

    _accelZ.clear();
    _startTime = DateTime.now();

    final completer = Completer<RecordingResult>();

    // Start accelerometer at fastest available rate.
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((event) {
      _accelZ.add(event.z);
    });

    // Auto-stop after window.
    Future.delayed(Duration(milliseconds: _windowMs), () {
      if (!completer.isCompleted) {
        _stopAndComplete(wavPath, completer);
      }
    });

    return completer.future;
  }

  /// Manually stop the recording before the 30-second window elapses.
  Future<RecordingResult?> stop() async {
    if (_startTime == null) return null;
    final dir = await getTemporaryDirectory();
    final wavPath = '${dir.path}/bridge_accel_${const Uuid().v4()}.wav';
    final completer = Completer<RecordingResult>();
    await _stopAndComplete(wavPath, completer);
    return completer.future;
  }

  Future<void> _stopAndComplete(
    String wavPath,
    Completer<RecordingResult> completer,
  ) async {
    _accelSub?.cancel();
    _accelSub = null;

    String finalPath = wavPath;
    try {
      final recorded = await _audioRecorder.stop();
      if (recorded != null) finalPath = recorded;
    } catch (_) {
      // If recorder wasn't started yet (edge case), create an empty WAV stub.
      await _writeEmptyWav(wavPath);
    }

    final elapsed = _startTime != null
        ? DateTime.now().difference(_startTime!).inMilliseconds
        : _windowMs;

    final sampleRate = elapsed > 0
        ? (_accelZ.length * 1000 / elapsed).round()
        : 50; // fallback ~50 Hz

    if (!completer.isCompleted) {
      completer.complete(RecordingResult(
        wavPath: finalPath,
        accelZSamples: List.unmodifiable(_accelZ),
        actualSampleRateHz: sampleRate,
        durationMs: elapsed,
      ));
    }

    _startTime = null;
  }

  /// Write a minimal valid WAV header + empty data chunk.
  /// Used as a fallback when the audio recorder wasn't started.
  Future<void> _writeEmptyWav(String path) async {
    final file = File(path);
    final header = _buildWavHeader(numSamples: 0, sampleRate: 44100);
    await file.writeAsBytes(header);
  }

  Uint8List _buildWavHeader({
    required int numSamples,
    required int sampleRate,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = numSamples * blockAlign;
    final chunkSize = 36 + dataSize;

    final buf = ByteData(44);
    // RIFF header
    buf.setUint8(0, 0x52); buf.setUint8(1, 0x49);
    buf.setUint8(2, 0x46); buf.setUint8(3, 0x46);
    buf.setInt32(4, chunkSize, Endian.little);
    buf.setUint8(8, 0x57); buf.setUint8(9, 0x41);
    buf.setUint8(10, 0x56); buf.setUint8(11, 0x45);
    // fmt sub-chunk
    buf.setUint8(12, 0x66); buf.setUint8(13, 0x6D);
    buf.setUint8(14, 0x74); buf.setUint8(15, 0x20);
    buf.setInt32(16, 16, Endian.little); // PCM
    buf.setUint16(20, 1, Endian.little); // PCM format
    buf.setUint16(22, numChannels, Endian.little);
    buf.setInt32(24, sampleRate, Endian.little);
    buf.setInt32(28, byteRate, Endian.little);
    buf.setUint16(32, blockAlign, Endian.little);
    buf.setUint16(34, bitsPerSample, Endian.little);
    // data sub-chunk
    buf.setUint8(36, 0x64); buf.setUint8(37, 0x61);
    buf.setUint8(38, 0x74); buf.setUint8(39, 0x61);
    buf.setInt32(40, dataSize, Endian.little);
    return buf.buffer.asUint8List();
  }

  void dispose() {
    _accelSub?.cancel();
    _audioRecorder.dispose();
  }
}
