import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../shared/report_payload.dart';

/// GPS accuracy threshold in meters to consider a fix "locked".
const double _kLockThresholdMeters = 10.0;

/// Timeout duration for GPS lock acquisition before using best available fix.
const Duration _kLockTimeout = Duration(seconds: 20);

/// Streaming status label for the accuracy badge shown in the camera overlay.
enum GpsLockState { cold, acquiring, locked }

class GpsAccuracyBadge {
  final GpsLockState state;
  final String label;
  const GpsAccuracyBadge(this.state, this.label);
}

/// High-precision GPS locking and position stream manager.
///
/// **IMPORTANT**: Always call [stopStream] after shutter capture to prevent battery drain.
class GeoCaptureService {
  StreamSubscription<Position>? _subscription;
  final _accuracyController = StreamController<GpsAccuracyBadge>.broadcast();

  /// Stream of human-readable GPS accuracy badges for the camera overlay.
  Stream<GpsAccuracyBadge> get accuracyBadgeStream =>
      _accuracyController.stream;

  /// Starts the background GPS position stream and emits badge updates.
  void startStream() {
    _subscription?.cancel();
    _accuracyController
        .add(const GpsAccuracyBadge(GpsLockState.acquiring, 'Acquiring...'));

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      final acc = position.accuracy;
      if (acc <= _kLockThresholdMeters) {
        _accuracyController.add(GpsAccuracyBadge(
          GpsLockState.locked,
          'Locked ✓  ±${acc.toStringAsFixed(0)}m',
        ));
      } else {
        _accuracyController.add(GpsAccuracyBadge(
          GpsLockState.acquiring,
          '±${acc.toStringAsFixed(0)}m',
        ));
      }
    }, onError: (_) {
      _accuracyController
          .add(const GpsAccuracyBadge(GpsLockState.cold, 'GPS unavailable'));
    });
  }

  /// Waits for a GPS fix with accuracy ≤ [_kLockThresholdMeters] m.
  /// Falls back to the best available fix after [_kLockTimeout].
  ///
  /// Always call [stopStream] after this method returns.
  Future<GeoCapture> lockFix() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    Position? bestPosition;
    final completer = Completer<GeoCapture>();

    final sub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      bestPosition = position;
      if (position.accuracy <= _kLockThresholdMeters &&
          !completer.isCompleted) {
        completer.complete(_toGeoCapture(position));
      }
    }, onError: (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    });

    // Timeout: use best available fix
    Future.delayed(_kLockTimeout, () {
      if (!completer.isCompleted) {
        if (bestPosition != null) {
          completer.complete(_toGeoCapture(bestPosition!));
        } else {
          completer.completeError(
            TimeoutException('GPS lock timeout — no position available'),
          );
        }
      }
    });

    try {
      return await completer.future;
    } finally {
      await sub.cancel();
    }
  }

  GeoCapture _toGeoCapture(Position p) => GeoCapture(
        latitude: p.latitude,
        longitude: p.longitude,
        altitudeMeters: p.altitude,
        accuracyMeters: p.accuracy,
        bearingDegrees: p.heading,
        speedMps: p.speed,
        capturedAtUtc: p.timestamp.toUtc(),
      );

  /// Cancels the ongoing GPS position stream to prevent battery drain.
  ///
  /// Must be called immediately after shutter capture — per §9.2 spec.
  Future<void> stopStream() async {
    await _subscription?.cancel();
    _subscription = null;
    if (!_accuracyController.isClosed) {
      _accuracyController
          .add(const GpsAccuracyBadge(GpsLockState.cold, 'GPS stopped'));
    }
  }

  /// Alias for [stopStream] — matches blueprint API naming.
  Future<void> stopPositionStream() => stopStream();

  /// Dispose stream controller — call when the capture page is disposed.
  void dispose() {
    _subscription?.cancel();
    _accuracyController.close();
  }
}
