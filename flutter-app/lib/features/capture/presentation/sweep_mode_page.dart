import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/geo/geo_capture_service.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../shared/report_payload.dart';
import '../../../core/sensor/sensor_processing_service.dart';
import '../../report/data/draft_queue_repository.dart';
import '../../../core/auth/auth_session.dart';

/// Sweep Mode / Mobile Road Scan Page
///
/// Continuous road-condition scanning mode that captures camera frames,
/// accelerometer, gyroscope, and GPS coordinates concurrently.
class SweepModePage extends ConsumerStatefulWidget {
  const SweepModePage({super.key});

  @override
  ConsumerState<SweepModePage> createState() => _SweepModePageState();
}

class _SweepModePageState extends ConsumerState<SweepModePage>
    with WidgetsBindingObserver {
  static const int _kIntervalSeconds = 5;

  final _permService = PermissionService();
  final _geoService = GeoCaptureService();
  final _sensorService = SensorProcessingService();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  bool _isInitialising = true;
  bool _isSweeping = false;
  bool _hasError = false;
  String? _errorMessage;

  // Configuration
  String _selectedVehicle = 'CAR';
  String _selectedMount = 'CAR_DASHBOARD';

  // Sensor diagnostics
  Map<String, SensorAvailability> _sensorStatuses = {};
  double _actualSamplingRate = 0.0;
  double _gpsAccuracy = 0.0;
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _speed = 0.0;

  // Real-time stream subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<GpsAccuracyBadge>? _gpsBadgeSub;
  Timer? _metricsTimer;

  // Counters and event records
  int _captureCount = 0;
  int _vibrationEventCount = 0;
  DateTime? _sweepStartTime;
  bool _loopActive = false;

  final List<double> _verticalAccelBuffer = [];
  double _lastZDyn = 0.0;
  int _lastVibrationEventTimeMs = 0;

  // Tracked items for the final summary
  Map<String, dynamic>? _lastVisualEvent;
  final List<Map<String, dynamic>> _detectedVibrations = [];
  final List<MultimodalRoadEvent> _correlatedEvents = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialise();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSweep();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _stopSweep();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initialise();
    }
  }

  Future<void> _initialise() async {
    setState(() {
      _isInitialising = true;
      _hasError = false;
    });

    final result = await _permService.requestCapturePermissions();
    if (result != PermissionResult.granted) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Camera permission denied.';
          _isInitialising = false;
        });
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('No cameras available');

      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();

      // Diagnostics check
      _sensorStatuses = await _sensorService.checkSensorAvailability();

      if (mounted) {
        setState(() => _isInitialising = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isInitialising = false;
        });
      }
    }
  }

  void _startSweep() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _sensorService.resetBaseline();
    _verticalAccelBuffer.clear();
    _detectedVibrations.clear();
    _correlatedEvents.clear();
    _lastVisualEvent = null;

    setState(() {
      _isSweeping = true;
      _captureCount = 0;
      _vibrationEventCount = 0;
      _sweepStartTime = DateTime.now();
      _loopActive = true;
    });

    // Start GPS Badge stream
    _geoService.startStream();
    _gpsBadgeSub = _geoService.accuracyBadgeStream.listen((badge) {
      // Geolocator stream triggers coordinate updates
      _updateCoordinates();
    });

    // Start IMU streams
    final startTimeMs = DateTime.now().millisecondsSinceEpoch;
    var accelSampleCount = 0;

    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((event) {
      accelSampleCount++;
      final zDyn = _sensorService.getVerticalDynamicAcceleration(event.x, event.y, event.z);
      _verticalAccelBuffer.add(zDyn);
      if (_verticalAccelBuffer.length > 50) {
        _verticalAccelBuffer.removeAt(0);
      }

      // Track sampling rate dynamically
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTimeMs;
      if (elapsed > 0) {
        setState(() {
          _actualSamplingRate = (accelSampleCount * 1000 / elapsed);
        });
      }

      // Perform sliding window math
      if (_verticalAccelBuffer.length >= 10) {
        final rms = sqrt(_verticalAccelBuffer.map((v) => v * v).reduce((a, b) => a + b) / _verticalAccelBuffer.length);
        final peak = _verticalAccelBuffer.map((v) => v.abs()).reduce(max);
        final jerk = (zDyn - _lastZDyn) / 0.02; // Assumed ~50Hz dt
        _lastZDyn = zDyn;

        _sensorService.updateBaselineStats(rms, peak, jerk);
        final vibrationScore = _sensorService.getZScoreVibration(rms, peak, jerk);

        if (vibrationScore > _sensorService.thresholdVibration) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - _lastVibrationEventTimeMs > 2000) { // Debounce 2 seconds
            _lastVibrationEventTimeMs = nowMs;
            _vibrationEventCount++;
            _detectedVibrations.add({
              'timestamp_ms': nowMs,
              'vibration_score': vibrationScore,
              'peak': peak,
              'rms': rms,
              'jerk': jerk,
            });

            // Correlate with last visual detection
            _correlateVisualAndVibration(nowMs, vibrationScore);
          }
        }
      }
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((_) {});

    // Start camera loop
    _runCaptureLoop();
  }

  void _stopSweep() {
    if (!_isSweeping) return;

    setState(() {
      _isSweeping = false;
      _loopActive = false;
    });

    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _gpsBadgeSub?.cancel();
    _gpsBadgeSub = null;
    _geoService.stopStream();

    _showSummaryReport();
  }

  Future<void> _updateCoordinates() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 2),
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _gpsAccuracy = pos.accuracy;
          _speed = pos.speed;
        });
      }
    } catch (_) {}
  }

  void _correlateVisualAndVibration(int vibTimeMs, double vibScore) {
    if (_lastVisualEvent == null) return;

    final visualTimeMs = _lastVisualEvent!['timestamp_ms'] as int;
    final visualConfidence = _lastVisualEvent!['confidence'] as double;
    final visualClass = _lastVisualEvent!['class'] as String;
    final imagePath = _lastVisualEvent!['image_path'] as String;

    final quality = _sensorService.calculateQuality(
      gpsAccuracyMeters: _gpsAccuracy,
      actualSampleRateHz: _actualSamplingRate,
      requestSampleRateHz: 50.0,
      mountType: _selectedMount,
    );

    final mme = _sensorService.correlateEvent(
      vibrationTimeMs: vibTimeMs,
      vibrationScore: vibScore,
      latitude: _latitude,
      longitude: _longitude,
      speedMps: _speed,
      quality: quality,
      visualTimeMs: visualTimeMs,
      visualConfidence: visualConfidence,
      visualClass: visualClass,
      imagePath: imagePath,
    );

    if (mme != null) {
      setState(() {
        _correlatedEvents.add(mme);
      });
      _saveMultimodalDraft(mme);
    }
  }

  Future<void> _saveMultimodalDraft(MultimodalRoadEvent mme) async {
    final session = ref.read(authSessionProvider);
    final payload = ReportPayload(
      id: mme.id,
      userId: session.userId,
      category: mme.visualClass == 'pothole'
          ? ReportCategory.pothole
          : ReportCategory.roadCrack,
      severity: mme.fusedEvidenceScore > 0.8
          ? ReportSeverity.critical
          : (mme.fusedEvidenceScore > 0.6 ? ReportSeverity.high : ReportSeverity.medium),
      description: 'Multimodal Road Scan: Fused Evidence ${(mme.fusedEvidenceScore * 100).toStringAsFixed(0)}% (Auto-Correlated)',
      capture: GeoCapture(
        latitude: mme.latitude,
        longitude: mme.longitude,
        altitudeMeters: 0,
        accuracyMeters: mme.sensorQuality * 10.0,
        bearingDegrees: 0,
        speedMps: mme.speedMps,
        capturedAtUtc: DateTime.now().toUtc(),
      ),
      imagePath: mme.imagePath ?? '',
      qualityGate: ImageQualityGate.ok,
      isGuest: session.isGuest,
    );

    try {
      final repo = ref.read(draftQueueRepositoryProvider);
      await repo.saveDraft(payload);
      debugPrint('[SweepMode] Successfully saved multimodal correlated draft: ${mme.id}');
    } catch (e) {
      debugPrint('[SweepMode] Failed to save draft: $e');
    }
  }

  Future<void> _runCaptureLoop() async {
    while (_loopActive && mounted) {
      await _captureFrame();
      for (var i = 0; i < _kIntervalSeconds * 10 && _loopActive; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _captureFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final xFile = await _cameraController!.takePicture();
      await _updateCoordinates();

      // Mock visual AI checks
      final hasVisualDefect = Random().nextDouble() > 0.6; // 40% chance of visual defect
      final confidence = hasVisualDefect ? 0.7 + Random().nextDouble() * 0.25 : 0.0;
      final defectClass = hasVisualDefect ? (Random().nextBool() ? 'pothole' : 'crack') : 'none';

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (hasVisualDefect) {
        _lastVisualEvent = {
          'timestamp_ms': nowMs,
          'confidence': confidence,
          'class': defectClass,
          'image_path': xFile.path,
        };
      }

      if (mounted) {
        setState(() => _captureCount++);
      }
    } catch (e) {
      debugPrint('[SweepMode] Frame capture error: $e');
    }
  }

  void _showSummaryReport() {
    final elapsed = _sweepStartTime != null
        ? DateTime.now().difference(_sweepStartTime!).inSeconds
        : 0;
    final mm = (elapsed ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsed % 60).toString().padLeft(2, '0');

    final quality = _sensorService.calculateQuality(
      gpsAccuracyMeters: _gpsAccuracy,
      actualSampleRateHz: _actualSamplingRate,
      requestSampleRateHz: 50.0,
      mountType: _selectedMount,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ROAD SCAN COMPLETE',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Stat Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _SummaryStatCard(label: 'Duration', value: '$mm:$ss', icon: Icons.timer_rounded, color: const Color(0xFF38BDF8)),
                      _SummaryStatCard(label: 'Sensor Quality', value: '${(quality.overallQuality * 100).toStringAsFixed(0)}%', icon: Icons.verified_user_rounded, color: const Color(0xFF34D399)),
                      _SummaryStatCard(label: 'Visual Frames', value: '$_captureCount', icon: Icons.camera_alt_rounded, color: const Color(0xFFF472B6)),
                      _SummaryStatCard(label: 'Vibrations', value: '$_vibrationEventCount', icon: Icons.sensors_rounded, color: const Color(0xFFFBBF24)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Fused correlated count banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, color: Color(0xFF818CF8), size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_correlatedEvents.length} Correlated Events',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Aligned visual defects with physical dynamic impacts into single drafts.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'DETECTED ROAD EVENTS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 12),

                  if (_correlatedEvents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No correlated impact events detected.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._correlatedEvents.map((e) => Card(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 20),
                            ),
                            title: Text(
                              '${e.visualClass?.toUpperCase() ?? "POTHOLE"} CANDIDATE',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              'Location: ${e.latitude.toStringAsFixed(4)}, ${e.longitude.toStringAsFixed(4)} • Speed: ${(e.speedMps * 3.6).toStringAsFixed(0)} km/h',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(e.fusedEvidenceScore * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const Text('Evidence', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                              ],
                            ),
                          ),
                        )),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('View Draft Queue', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isInitialising) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF4F46E5)),
            SizedBox(height: 12),
            Text(
              'Initialising camera...',
              style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFEF4444), size: 56),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Camera error',
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontFamily: 'Inter'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initialise,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Camera preview ──
        CameraPreview(_cameraController!),

        // ── Thin rule-of-thirds overlay ──
        CustomPaint(
          painter: _SweepGridPainter(),
        ),

        // ── Settings Panel (Visible only when not sweeping) ──
        if (!_isSweeping)
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ROAD SCAN CONFIGURATION',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedVehicle,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Vehicle',
                            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF334155)), borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'CAR', child: Text('Car')),
                            DropdownMenuItem(value: 'BIKE', child: Text('Motorcycle/Scooter')),
                            DropdownMenuItem(value: 'BICYCLE', child: Text('Bicycle')),
                            DropdownMenuItem(value: 'TRUCK', child: Text('Heavy Truck/Bus')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedVehicle = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMount,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Mount',
                            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF334155)), borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'CAR_DASHBOARD', child: Text('Dashboard Mount')),
                            DropdownMenuItem(value: 'CAR_WINDSHIELD', child: Text('Windshield Holder')),
                            DropdownMenuItem(value: 'BIKE_HANDLEBAR', child: Text('Handlebar Mount')),
                            DropdownMenuItem(value: 'HANDHELD', child: Text('Handheld (Degraded)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMount = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // ── Real-Time Diagnostics HUD ──
        if (_isSweeping)
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'REAL-TIME SENSOR DIAGNOSTICS',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                      Text(
                        'Sampling: ${_actualSamplingRate.toStringAsFixed(0)} Hz',
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SensorIndicator(label: 'ACCEL', active: _sensorStatuses['accelerometer'] == SensorAvailability.available),
                      _SensorIndicator(label: 'GYRO', active: _sensorStatuses['gyroscope'] == SensorAvailability.available),
                      _SensorIndicator(label: 'GPS', active: _sensorStatuses['gps'] == SensorAvailability.available),
                      Text(
                        'Accuracy: ±${_gpsAccuracy.toStringAsFixed(1)}m',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // ── Top HUD ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: _TopHud(
              isSweeping: _isSweeping,
              captureCount: _captureCount,
              sweepStartTime: _sweepStartTime,
              onClose: () {
                if (_isSweeping) {
                  _stopSweep();
                } else {
                  context.pop();
                }
              },
            ),
          ),
        ),

        // ── Bottom controls ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: _BottomControls(
              isSweeping: _isSweeping,
              onStart: _startSweep,
              onStop: _stopSweep,
              intervalSeconds: _kIntervalSeconds,
            ),
          ),
        ),

        // ── Capture flash ──
        if (_isSweeping)
          _CaptureFlashOverlay(captureCount: _captureCount),
      ],
    );
  }
}

class _SensorIndicator extends StatelessWidget {
  final String label;
  final bool active;

  const _SensorIndicator({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  final bool isSweeping;
  final int captureCount;
  final DateTime? sweepStartTime;
  final VoidCallback onClose;

  const _TopHud({
    required this.isSweeping,
    required this.captureCount,
    required this.sweepStartTime,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final elapsed = sweepStartTime != null
        ? DateTime.now().difference(sweepStartTime!).inSeconds
        : 0;
    final mm = (elapsed ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsed % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
          const Spacer(),
          if (isSweeping) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fiber_manual_record,
                      color: Colors.white, size: 10),
                  const SizedBox(width: 4),
                  Text(
                    '$mm:$ss',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$captureCount frames',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final bool isSweeping;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final int intervalSeconds;

  const _BottomControls({
    required this.isSweeping,
    required this.onStart,
    required this.onStop,
    required this.intervalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isSweeping
                ? 'Mobile Road Scan active • Auto-capturing every ${intervalSeconds}s'
                : 'Sweep Mode: continuous visual-inertial road scanning',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontFamily: 'Inter',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: isSweeping ? onStop : onStart,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isSweeping
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4F46E5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isSweeping
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF4F46E5))
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                isSweeping ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureFlashOverlay extends StatefulWidget {
  final int captureCount;

  const _CaptureFlashOverlay({required this.captureCount});

  @override
  State<_CaptureFlashOverlay> createState() => _CaptureFlashOverlayState();
}

class _CaptureFlashOverlayState extends State<_CaptureFlashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = Tween(begin: 0.0, end: 0.3).animate(_controller);
  }

  @override
  void didUpdateWidget(_CaptureFlashOverlay old) {
    super.didUpdateWidget(old);
    if (widget.captureCount != _lastCount) {
      _lastCount = widget.captureCount;
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => Container(
        color: Colors.white.withValues(alpha: _opacity.value),
      ),
    );
  }
}

class _SweepGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (var i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 1; i <= 2; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_SweepGridPainter old) => false;
}
