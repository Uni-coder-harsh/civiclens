import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../shared/defect.dart';
import '../../../shared/report_payload.dart';
import '../data/map_repository.dart';

// ── Map State ─────────────────────────────────────────────────────────────────

class _MapViewState {
  final List<NearbyDefect> defects;
  final bool isLoading;
  final bool showCoverage;
  final NearbyDefect? selectedDefect;

  const _MapViewState({
    this.defects = const [],
    this.isLoading = false,
    this.showCoverage = false,
    this.selectedDefect,
  });

  _MapViewState copyWith({
    List<NearbyDefect>? defects,
    bool? isLoading,
    bool? showCoverage,
    NearbyDefect? selectedDefect,
    bool clearSelected = false,
  }) =>
      _MapViewState(
        defects: defects ?? this.defects,
        isLoading: isLoading ?? this.isLoading,
        showCoverage: showCoverage ?? this.showCoverage,
        selectedDefect:
            clearSelected ? null : (selectedDefect ?? this.selectedDefect),
      );
}

class _MapNotifier extends Notifier<_MapViewState> {
  Timer? _debounce;
  CameraPosition? _lastCamera;

  @override
  _MapViewState build() => const _MapViewState();

  void onCameraIdle(CameraPosition position) {
    _lastCamera = position;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchDefects(position.target.latitude, position.target.longitude);
    });
  }

  Future<void> _fetchDefects(double lat, double lng) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(mapRepositoryProvider);
      final defects = await repo.fetchNearbyDefects(lat, lng, 5000);
      state = state.copyWith(defects: defects, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void selectDefect(NearbyDefect? defect) {
    if (defect == null) {
      state = state.copyWith(clearSelected: true);
    } else {
      state = state.copyWith(selectedDefect: defect);
    }
  }

  void toggleCoverage() {
    state = state.copyWith(showCoverage: !state.showCoverage);
  }

  void refresh() {
    if (_lastCamera != null) {
      _fetchDefects(
        _lastCamera!.target.latitude,
        _lastCamera!.target.longitude,
      );
    }
  }
}

final _mapNotifierProvider =
    NotifierProvider<_MapNotifier, _MapViewState>(_MapNotifier.new);

// ── Map Page ──────────────────────────────────────────────────────────────────

/// Route: `/home/map`
///
/// Interactive Google Map with custom cached markers, pin tap bottom sheet,
/// debounced camera-idle refetch, and coverage heatmap toggle stub.
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  GoogleMapController? _mapController;

  static const _initialPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090), // New Delhi
    zoom: 13,
  );

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(_mapNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            style: _mapStyle,
            markers: _buildMarkers(mapState.defects),
            onMapCreated: (controller) {
              _mapController = controller;
              // Initial fetch after map ready
              ref
                  .read(_mapNotifierProvider.notifier)
                  .onCameraIdle(_initialPosition);
            },
            onCameraIdle: () {
              if (_mapController == null) return;
              _mapController!.getVisibleRegion().then((bounds) {
                final center = LatLng(
                  (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
                  (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
                );
                ref.read(_mapNotifierProvider.notifier).onCameraIdle(
                      CameraPosition(target: center),
                    );
              });
            },
          ),

          // Top overlay: Loading indicator + Coverage toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Map title pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: Color(0xFF4F46E5), size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'CivicLens Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (mapState.isLoading) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        Text(
                          '${mapState.defects.length} pins',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                // Coverage toggle
                GestureDetector(
                  onTap: () =>
                      ref.read(_mapNotifierProvider.notifier).toggleCoverage(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: mapState.showCoverage
                          ? const Color(0xFF4F46E5).withOpacity(0.9)
                          : const Color(0xFF1E293B).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: mapState.showCoverage
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.layers_rounded,
                          size: 16,
                          color: mapState.showCoverage
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Coverage',
                          style: TextStyle(
                            color: mapState.showCoverage
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Coverage heatmap stub overlay
          if (mapState.showCoverage)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [
                        const Color(0xFF4F46E5).withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Pin legend
          Positioned(
            bottom: 100,
            left: 16,
            child: _PinLegend(),
          ),

          // Capture FAB
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => context.push('/capture'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo_rounded,
                          color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Report Defect',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // My location button
          Positioned(
            bottom: 100,
            right: 16,
            child: _MapControlButton(
              icon: Icons.my_location_rounded,
              onTap: () {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(_initialPosition),
                );
              },
            ),
          ),

          // Selected defect bottom sheet
          if (mapState.selectedDefect != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _DefectBottomSheet(
                defect: mapState.selectedDefect!,
                onClose: () =>
                    ref.read(_mapNotifierProvider.notifier).selectDefect(null),
              ),
            ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(List<NearbyDefect> defects) {
    return defects.map((defect) {
      return Marker(
        markerId: MarkerId(defect.reportId),
        position: LatLng(defect.latitude, defect.longitude),
        icon: _markerIcon(defect),
        onTap: () =>
            ref.read(_mapNotifierProvider.notifier).selectDefect(defect),
        infoWindow: InfoWindow(title: defect.category.name),
      );
    }).toSet();
  }

  BitmapDescriptor _markerIcon(NearbyDefect defect) {
    // Use cached BitmapDescriptor hues as approximations for custom styling.
    // For full custom marker rendering, a separate renderMarker pipeline is needed.
    final hue = _statusHue(defect.status);
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  double _statusHue(DefectStatus s) {
    switch (s) {
      case DefectStatus.submitted:
      case DefectStatus.underReview:
        return BitmapDescriptor.hueYellow; // Amber
      case DefectStatus.aiVerified:
        return BitmapDescriptor.hueOrange; // Orange
      case DefectStatus.assigned:
      case DefectStatus.inProgress:
        return BitmapDescriptor.hueAzure; // Blue
      case DefectStatus.awaitAcceptance:
        return BitmapDescriptor.hueCyan; // Cyan
      case DefectStatus.resolved:
        return BitmapDescriptor.hueGreen; // Green
      case DefectStatus.rejected:
        return BitmapDescriptor.hueViolet; // Grey substitute
      case DefectStatus.reopened:
        return BitmapDescriptor.hueRed; // Red
      case DefectStatus.closed:
        return BitmapDescriptor.hueRose;
    }
  }

  /// Dark map style JSON to match the app's dark theme.
  static const String _mapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1E293B"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#0F172A"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#94A3B8"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#334155"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1E293B"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0F172A"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]}
]
''';
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.92),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF334155)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      ),
    );
  }
}

class _DefectBottomSheet extends StatelessWidget {
  final NearbyDefect defect;
  final VoidCallback onClose;

  const _DefectBottomSheet({required this.defect, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                // Thumbnail placeholder
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _statusColor(defect.status).withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Color(0xFF64748B),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Row(
                        children: [
                          _StatusPill(status: defect.status),
                          if (defect.watermarkVerified) ...[
                            const SizedBox(width: 6),
                            const _VerifiedBadge(),
                          ],
                        ],
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
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF64748B), size: 20),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onClose();
                  context.push('/report/detail/${defect.reportId}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'View Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(DefectStatus s) {
    switch (s) {
      case DefectStatus.submitted:
      case DefectStatus.underReview:
        return const Color(0xFFFFBF00);
      case DefectStatus.aiVerified:
        return const Color(0xFFFF7F00);
      case DefectStatus.assigned:
      case DefectStatus.inProgress:
        return const Color(0xFF007AFF);
      case DefectStatus.awaitAcceptance:
        return const Color(0xFF00C7BE);
      case DefectStatus.resolved:
        return const Color(0xFF34C759);
      case DefectStatus.rejected:
      case DefectStatus.closed:
        return const Color(0xFF8E8E93);
      case DefectStatus.reopened:
        return const Color(0xFFFF3B30);
    }
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

class _StatusPill extends StatelessWidget {
  final DefectStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.name
            .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}'),
        style: TextStyle(
          color: color,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Color get _color {
    switch (status) {
      case DefectStatus.submitted:
      case DefectStatus.underReview:
        return const Color(0xFFFFBF00);
      case DefectStatus.aiVerified:
        return const Color(0xFFFF7F00);
      case DefectStatus.assigned:
      case DefectStatus.inProgress:
        return const Color(0xFF007AFF);
      case DefectStatus.awaitAcceptance:
        return const Color(0xFF00C7BE);
      case DefectStatus.resolved:
        return const Color(0xFF34C759);
      case DefectStatus.rejected:
      case DefectStatus.closed:
        return const Color(0xFF8E8E93);
      case DefectStatus.reopened:
        return const Color(0xFFFF3B30);
    }
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 10),
          SizedBox(width: 3),
          Text(
            'Verified',
            style: TextStyle(
              color: Color(0xFF22C55E),
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendRow(color: Color(0xFFFFBF00), label: 'Submitted'),
          SizedBox(height: 4),
          _LegendRow(color: Color(0xFF007AFF), label: 'In Progress'),
          SizedBox(height: 4),
          _LegendRow(color: Color(0xFF34C759), label: 'Resolved'),
          SizedBox(height: 4),
          _LegendRow(color: Color(0xFFFF3B30), label: 'Reopened'),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontFamily: 'Inter',
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
