import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/geo/geo_capture_service.dart';
import '../../../core/permissions/permission_service.dart';
import '../data/capture_repository.dart';
import '../../../shared/report_payload.dart';
import 'overlay_painter.dart';

// Enum mirroring the capture flow state machine from §7.3
enum CaptureState {
  idle,
  requestingPermission,
  warmup,
  capturing,
  metadataLocked,
  qualityGate,
  watermarked,
  previewReview,
  savingDraft,
  saved,
}

/// Main camera capture screen.
///
/// State machine: idle → requestingPermission → warmup → capturing
///   → metadataLocked → qualityGate → watermarked → previewReview
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  final _repo = CaptureRepository();
  final _permService = PermissionService();

  CameraController? _controller;
  CaptureState _state = CaptureState.idle;
  GpsAccuracyBadge _gpsBadge =
      const GpsAccuracyBadge(GpsLockState.cold, 'Acquiring...');
  String? _statusMessage;
  List<CameraDescription> _cameras = [];
  bool _shutterEnabled = false;
  bool _privacyTipVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    setState(() => _state = CaptureState.requestingPermission);

    final result = await _permService.requestCapturePermissions();
    if (result == PermissionResult.permanentlyDenied && mounted) {
      await _permService.showPermissionDeniedDialog(context);
    }
    if (result != PermissionResult.granted) {
      if (mounted) context.pop();
      return;
    }

    setState(() => _state = CaptureState.warmup);
    await _initCamera();
    _startGps();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      _showMessage('No camera found on this device');
      return;
    }

    _controller = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  void _startGps() {
    _repo.startGpsStream();
    _repo.accuracyBadgeStream.listen((badge) {
      if (mounted) {
        setState(() {
          _gpsBadge = badge;
          _shutterEnabled = badge.state == GpsLockState.locked;
        });
      }
    });

    // Hide privacy tip after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _privacyTipVisible = false);
    });
  }

  Future<void> _onShutter() async {
    if (!_shutterEnabled || _controller == null) return;

    setState(() {
      _state = CaptureState.capturing;
      _statusMessage = 'Capturing...';
    });

    try {
      // Capture photo
      final xFile = await _controller!.takePicture();

      setState(() {
        _state = CaptureState.metadataLocked;
        _statusMessage = 'Locking metadata...';
      });

      setState(() {
        _state = CaptureState.qualityGate;
        _statusMessage = 'Checking quality...';
      });

      final reportId = const Uuid().v4();
      final result = await _repo.processCapture(
        rawImagePath: xFile.path,
        reportId: reportId,
        // ignore: use_build_context_synchronously
        context: mounted ? context : null,
      );

      setState(() {
        _state = CaptureState.watermarked;
        _statusMessage = null;
      });

      if (mounted) {
        context.push('/capture/preview', extra: result);
      }
    } on QualityGateException catch (e) {
      setState(() {
        _state = CaptureState.idle;
        _statusMessage = null;
        _shutterEnabled = _gpsBadge.state == GpsLockState.locked;
      });
      _showQualityFailureToast(e.verdict);
    } catch (e) {
      setState(() {
        _state = CaptureState.idle;
        _statusMessage = null;
        _shutterEnabled = _gpsBadge.state == GpsLockState.locked;
      });
      _showMessage('Capture failed: ${e.toString()}');
    }
  }

  void _showQualityFailureToast(ImageQualityGate verdict) {
    final message = switch (verdict) {
      ImageQualityGate.blurry => '📷 Photo too blurry — hold steady',
      ImageQualityGate.tooDark => '🔦 Too dark — move to better lighting',
      ImageQualityGate.overexposed => '☀️ Too bright — avoid direct light',
      ImageQualityGate.noSubject => '🔍 No subject detected — try again',
      ImageQualityGate.ok => null,
    };
    if (message != null) _showMessage(message);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(msg,
            style: const TextStyle(color: Colors.white, fontFamily: 'Inter')),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repo.stopGpsStream();
    _controller?.dispose();
    super.dispose();
  }

  bool get _isProcessing =>
      _state == CaptureState.capturing ||
      _state == CaptureState.metadataLocked ||
      _state == CaptureState.qualityGate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_controller != null && _controller!.value.isInitialized)
            CameraPreview(_controller!)
          else
            _buildWarmupView(),

          // Overlay painter (grid + brackets + GPS badge + hint)
          if (_controller != null && _controller!.value.isInitialized)
            CameraOverlay(gpsBadge: _gpsBadge),

          // Privacy tip banner
          if (_privacyTipVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _PrivacyTipBanner(
                onClose: () => setState(() => _privacyTipVisible = false),
              ),
            ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF4F46E5)),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage ?? 'Processing...',
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),

          // Top Bar: Back button + Capture Mode Switcher
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CameraModePill(
                        label: 'Single',
                        icon: Icons.camera_alt_rounded,
                        isSelected: true,
                        onTap: () {},
                      ),
                      _CameraModePill(
                        label: 'Sweep',
                        icon: Icons.directions_walk_rounded,
                        isSelected: false,
                        onTap: () async {
                          final c = _controller;
                          _controller = null;
                          if (c != null) {
                            await c.dispose();
                          }
                          if (context.mounted) {
                            context.pushReplacement('/capture/sweep');
                          }
                        },
                      ),
                      if (FeatureFlags.bridgeCheck)
                        _CameraModePill(
                          label: 'Bridge',
                          icon: Icons.settings_input_antenna_rounded,
                          isSelected: false,
                          onTap: () => context.push('/bridge-check'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarmupView() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF4F46E5)),
            const SizedBox(height: 16),
            Text(
              _state == CaptureState.requestingPermission
                  ? 'Requesting permissions...'
                  : 'Warming up camera...',
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'Inter', fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 28,
        top: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── In-Camera Pro Mode Switcher ────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CameraModePill(
                  label: 'Bridge',
                  icon: Icons.settings_input_antenna_rounded,
                  isSelected: false,
                  onTap: () => context.pushReplacement('/bridge-check'),
                ),
                const SizedBox(width: 4),
                _CameraModePill(
                  label: 'Photo',
                  icon: Icons.camera_alt_rounded,
                  isSelected: true,
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                _CameraModePill(
                  label: 'Sweep',
                  icon: Icons.directions_walk_rounded,
                  isSelected: false,
                  onTap: () async {
                    final c = _controller;
                    _controller = null;
                    if (c != null) {
                      await c.dispose();
                    }
                    if (context.mounted) {
                      context.pushReplacement('/capture/sweep');
                    }
                  },
                ),
              ],
            ),
          ),

          // GPS lock warning or shutter
          if (!_shutterEnabled && !_isProcessing)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Waiting for GPS lock...',
                style: TextStyle(
                  color: Colors.amber.withOpacity(0.9),
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          // Shutter button
          GestureDetector(
            onTap: _shutterEnabled && !_isProcessing ? _onShutter : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _shutterEnabled
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  width: 4,
                ),
                color: _shutterEnabled
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _shutterEnabled
                        ? Colors.white
                        : Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyTipBanner extends StatelessWidget {
  final VoidCallback onClose;

  const _PrivacyTipBanner({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 56,
        left: 16,
        right: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          const Icon(Icons.privacy_tip_outlined,
              color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Privacy Tip: Avoid capturing faces or license plates',
              style: TextStyle(
                color: Color(0xFFE2E8F0),
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close_rounded,
                color: Color(0xFF94A3B8), size: 18),
          ),
        ],
      ),
    );
  }
}

// ── In-Camera Mode Pill ────────────────────────────────────────────────────────

class _CameraModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CameraModePill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontFamily: 'Inter',
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
