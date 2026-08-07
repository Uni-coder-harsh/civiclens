import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/defect.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';
import '../data/witness_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class _ConfirmState {
  final NearbyDefect? defect;
  final bool isLoading;
  final bool isOutOfRange;
  final bool isSubmitted;
  final String? error;
  final double? witnessLat;
  final double? witnessLng;

  const _ConfirmState({
    this.defect,
    this.isLoading = false,
    this.isOutOfRange = false,
    this.isSubmitted = false,
    this.error,
    this.witnessLat,
    this.witnessLng,
  });

  _ConfirmState copyWith({
    NearbyDefect? defect,
    bool? isLoading,
    bool? isOutOfRange,
    bool? isSubmitted,
    String? error,
    double? witnessLat,
    double? witnessLng,
    bool clearError = false,
  }) =>
      _ConfirmState(
        defect: defect ?? this.defect,
        isLoading: isLoading ?? this.isLoading,
        isOutOfRange: isOutOfRange ?? this.isOutOfRange,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        error: clearError ? null : (error ?? this.error),
        witnessLat: witnessLat ?? this.witnessLat,
        witnessLng: witnessLng ?? this.witnessLng,
      );
}

class _ConfirmNotifier extends Notifier<_ConfirmState> {
  static const _maxRangeMeters = 50.0;

  @override
  _ConfirmState build() => const _ConfirmState();

  Future<void> loadDefect(String reportId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(witnessRepositoryProvider);
      // Fetch nearby for this specific report by getting current position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final nearby = await repo.fetchWitnessableNearby(
        pos.latitude,
        pos.longitude,
        radiusMeters: 500,
      );
      final defect = nearby.cast<NearbyDefect?>().firstWhere(
            (d) => d!.reportId == reportId,
            orElse: () => null,
          );
      state = state.copyWith(
        defect: defect,
        witnessLat: pos.latitude,
        witnessLng: pos.longitude,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> submit({String? witnessPhotoPath}) async {
    final defect = state.defect;
    if (defect == null) return;

    // Hard GPS distance check
    if (state.witnessLat == null || state.witnessLng == null) {
      state = state.copyWith(error: 'Cannot read your GPS position.');
      return;
    }

    final distanceMeters = _haversine(
      state.witnessLat!,
      state.witnessLng!,
      defect.latitude,
      defect.longitude,
    );

    if (distanceMeters > _maxRangeMeters) {
      state = state.copyWith(
        isOutOfRange: true,
        error:
            'You are ${distanceMeters.round()}m from the report. You must be within ${_maxRangeMeters.round()}m to confirm.',
      );
      return;
    }

    state =
        state.copyWith(isLoading: true, clearError: true, isOutOfRange: false);

    try {
      final session = ref.read(authSessionProvider);
      final repo = ref.read(witnessRepositoryProvider);
      await repo.submitWitnessConfirmation(
        WitnessConfirmation(
          reportId: defect.reportId,
          witnessUserId: session.userId,
          capture: GeoCapture(
            latitude: state.witnessLat!,
            longitude: state.witnessLng!,
            altitudeMeters: 0,
            accuracyMeters: 5,
            bearingDegrees: 0,
            speedMps: 0,
            capturedAtUtc: DateTime.now().toUtc(),
          ),
          afterPhotoPath: witnessPhotoPath,
          atUtc: DateTime.now().toUtc(),
        ),
      );
      state = state.copyWith(isLoading: false, isSubmitted: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Haversine formula — returns distance in meters.
  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // Earth radius in meters
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}

final _confirmNotifierProvider =
    NotifierProvider<_ConfirmNotifier, _ConfirmState>(_ConfirmNotifier.new);

// ── Witness Confirm Page ──────────────────────────────────────────────────────

/// Route: `/witness/:reportId`
///
/// Confirmation screen for WitnessMode peer confirmations.
/// Enforces a hard GPS check (≤50m) before allowing submission.
/// Shows +5 Witness Civic Score toast on success.
class WitnessConfirmPage extends ConsumerStatefulWidget {
  final String reportId;

  const WitnessConfirmPage({super.key, required this.reportId});

  @override
  ConsumerState<WitnessConfirmPage> createState() => _WitnessConfirmPageState();
}

class _WitnessConfirmPageState extends ConsumerState<WitnessConfirmPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_confirmNotifierProvider.notifier).loadDefect(widget.reportId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_confirmNotifierProvider);

    // Show success screen
    if (state.isSubmitted) {
      return _SuccessScreen(onDone: () => context.pop());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Witness Confirmation',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
      ),
      body: state.isLoading && state.defect == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Explainer header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.visibility_rounded,
                            color: Color(0xFF60A5FA), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WitnessMode Active',
                                style: TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Earn +5 Civic Score for confirming this report. You must be within 50m of the report location.',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Report info card
                  if (state.defect != null)
                    _ReportPreview(defect: state.defect!)
                  else if (state.error != null && state.defect == null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // GPS Range indicator
                  _GpsRangeWidget(
                    isOutOfRange: state.isOutOfRange,
                    witnessLat: state.witnessLat,
                    witnessLng: state.witnessLng,
                    defectLat: state.defect?.latitude,
                    defectLng: state.defect?.longitude,
                  ),
                  const SizedBox(height: 20),

                  // Error message
                  if (state.error != null && state.defect != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFDC2626).withOpacity(0.3)),
                      ),
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontFamily: 'Inter',
                          fontSize: 13,
                        ),
                      ),
                    ),

                  // Confirm button
                  ElevatedButton.icon(
                    onPressed: (state.isLoading || state.defect == null)
                        ? null
                        : () => ref
                            .read(_confirmNotifierProvider.notifier)
                            .submit(),
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                        state.isLoading ? 'Submitting…' : 'Confirm Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      disabledBackgroundColor:
                          const Color(0xFF3B82F6).withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _ReportPreview extends StatelessWidget {
  final NearbyDefect defect;

  const _ReportPreview({required this.defect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.broken_image_rounded,
                  color: Color(0xFF64748B), size: 40),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _categoryLabel(defect.category),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${defect.latitude.toStringAsFixed(4)}°, ${defect.longitude.toStringAsFixed(4)}°',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontFamily: 'Inter',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(ReportCategory c) {
    switch (c) {
      case ReportCategory.pothole:
        return 'Pothole';
      case ReportCategory.roadCrack:
        return 'Road Crack';
      case ReportCategory.bridgeDeck:
        return 'Bridge Deck';
      case ReportCategory.bridgePier:
        return 'Bridge Pier';
      case ReportCategory.bridgeCrack:
        return 'Bridge Crack';
      case ReportCategory.guardrail:
        return 'Guardrail';
      case ReportCategory.manhole:
        return 'Manhole';
      case ReportCategory.other:
        return 'Other';
    }
  }
}

class _GpsRangeWidget extends StatelessWidget {
  final bool isOutOfRange;
  final double? witnessLat;
  final double? witnessLng;
  final double? defectLat;
  final double? defectLng;

  const _GpsRangeWidget({
    required this.isOutOfRange,
    required this.witnessLat,
    required this.witnessLng,
    required this.defectLat,
    required this.defectLng,
  });

  @override
  Widget build(BuildContext context) {
    final hasGps = witnessLat != null && witnessLng != null;
    final color = isOutOfRange
        ? const Color(0xFFDC2626)
        : hasGps
            ? const Color(0xFF22C55E)
            : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isOutOfRange
                ? Icons.location_off_rounded
                : hasGps
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOutOfRange
                  ? 'Out of range — move closer to the report location'
                  : hasGps
                      ? 'GPS acquired — you are within confirmation range'
                      : 'Acquiring GPS position…',
              style: TextStyle(
                color: color,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessScreen extends StatelessWidget {
  final VoidCallback onDone;

  const _SuccessScreen({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (ctx, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 56),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Confirmation Submitted!',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF0D9488)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  '+5 Witness Civic Score',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Thank you for helping verify civic infrastructure issues in your community.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to Map',
                    style: TextStyle(
                        fontFamily: 'Inter', fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
