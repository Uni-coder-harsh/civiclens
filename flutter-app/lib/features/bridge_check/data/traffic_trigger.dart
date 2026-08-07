import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Threshold for z-axis spike that indicates heavy vehicle traffic.
/// Units: m/s² above the ~9.81 g baseline.
const double _kSpikeThresholdMs2 = 2.5;

/// Minimum tilt tolerance — phone is considered "flat on deck" when the
/// combined x+y tilt vector magnitude is below this value (m/s²).
const double _kFlatTiltThresholdMs2 = 1.8;

/// Windowed envelope: if the peak z-spike in the last [_kEnvelopeWindowMs] ms
/// exceeds [_kSpikeThresholdMs2] we fire a traffic event.
const int _kEnvelopeWindowMs = 500;

/// Holds one timestamped accelerometer reading.
class AccelSample {
  final double x, y, z;
  final DateTime timestamp;

  const AccelSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });
}

/// Outcome of a tilt-flatness check.
enum FlatCheckResult { flat, tilted, unknown }

/// Watches the accelerometer stream and fires events when:
///   1. The device appears to be flat on the bridge deck.
///   2. A traffic-induced z-axis spike is detected.
///
/// Neither value is stored beyond the rolling window — this class is pure
/// signal processing, no disk I/O.
class TrafficTrigger {
  final _trafficController = StreamController<void>.broadcast();
  final _flatController = StreamController<FlatCheckResult>.broadcast();

  StreamSubscription<AccelerometerEvent>? _accelSub;

  // Rolling window of recent z samples for envelope detection.
  final List<AccelSample> _window = [];
  FlatCheckResult _lastFlatResult = FlatCheckResult.unknown;

  /// Fires whenever a traffic-induced spike is detected.
  Stream<void> get trafficDetected => _trafficController.stream;

  /// Fires whenever the flatness state changes (or on every sample if you need
  /// to poll). Consumers use this to gate the "Start" button.
  Stream<FlatCheckResult> get flatnessChanged => _flatController.stream;

  /// The latest flat-check result — useful for synchronous reads.
  FlatCheckResult get currentFlatness => _lastFlatResult;

  /// Start listening to the accelerometer.
  void start() {
    _accelSub?.cancel();
    _window.clear();

    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval, // ~20ms
    ).listen(_onSample);
  }

  /// Stop the sensor subscription and close streams.
  void dispose() {
    _accelSub?.cancel();
    _trafficController.close();
    _flatController.close();
  }

  void _onSample(AccelerometerEvent event) {
    final now = DateTime.now();
    final sample = AccelSample(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: now,
    );

    _window.add(sample);
    _pruneWindow(now);
    _checkFlatness(sample);
    _checkTrafficSpike();
  }

  /// Remove samples older than [_kEnvelopeWindowMs].
  void _pruneWindow(DateTime now) {
    final cutoff = now.subtract(Duration(milliseconds: _kEnvelopeWindowMs));
    _window.removeWhere((s) => s.timestamp.isBefore(cutoff));
  }

  /// Phone is "flat on deck" when the vector sum of x and y is low
  /// (gravity is mostly captured by z).
  void _checkFlatness(AccelSample sample) {
    final tiltMagnitude = sqrt(sample.x * sample.x + sample.y * sample.y);
    final result = tiltMagnitude < _kFlatTiltThresholdMs2
        ? FlatCheckResult.flat
        : FlatCheckResult.tilted;

    if (result != _lastFlatResult) {
      _lastFlatResult = result;
      if (!_flatController.isClosed) {
        _flatController.add(result);
      }
    }
  }

  /// Check if any sample in the rolling window has a z-spike above threshold.
  /// The absolute z value minus gravity (9.81) gives the dynamic acceleration.
  void _checkTrafficSpike() {
    for (final s in _window) {
      final dynamicZ = (s.z.abs() - 9.81).abs();
      if (dynamicZ >= _kSpikeThresholdMs2) {
        if (!_trafficController.isClosed) {
          _trafficController.add(null);
        }
        // Only fire once per window sweep — clear to prevent duplicate events.
        _window.clear();
        return;
      }
    }
  }
}
