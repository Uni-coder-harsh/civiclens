import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/feature_flags.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/defect.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

          // Top overlay: Status pill + Role Action Pill + Coverage toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Map title & status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
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
                      Text(
                        'CivicLens',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
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

                // Role action shortcut badge
                const _RoleActionPill(),
                const SizedBox(width: 8),

                // Coverage toggle
                GestureDetector(
                  onTap: () =>
                      ref.read(_mapNotifierProvider.notifier).toggleCoverage(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              : Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Heatmap',
                          style: TextStyle(
                            color: mapState.showCoverage
                                ? Colors.white
                                : Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
            bottom: 90,
            left: 16,
            child: _PinLegend(),
          ),

          // My location button
          Positioned(
            bottom: 90,
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

          // Bottom Dual-Action Cluster (Modes Sheet + Primary Report Defect FAB)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Field Modes Hub Trigger
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => const _FieldModesBottomSheet(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.95),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFF818CF8).withOpacity(0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                              Theme.of(context).brightness == Brightness.light
                                  ? 0.1
                                  : 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_mosaic_rounded,
                            color: Color(0xFF818CF8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Modes',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Primary Report Defect FAB
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/capture'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.5),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Report Defect',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
          color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
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
        child: Icon(icon, color: Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8), size: 20),
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
                child: Text(
                  'View Report',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
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

// ── Top Role Action Pill ───────────────────────────────────────────────────────

class _RoleActionPill extends ConsumerWidget {
  const _RoleActionPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    IconData icon;
    String label;
    Color color;
    String route;

    switch (session.role) {
      case UserRole.officer:
        icon = Icons.dashboard_customize_rounded;
        label = 'Triage';
        color = const Color(0xFFF59E0B);
        route = '/officer/dashboard';
      case UserRole.contractor:
        icon = Icons.construction_rounded;
        label = 'Hub';
        color = const Color(0xFFD97706);
        route = '/contractor/dashboard';
      default:
        icon = Icons.badge_rounded;
        label = 'Passports';
        color = const Color(0xFFD97706);
        route = '/contractor-search';
    }

    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Field Modes Bottom Sheet ──────────────────────────────────────────────────

class _FieldModesBottomSheet extends StatelessWidget {
  const _FieldModesBottomSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF475569),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Field Capture & Reporting Hub',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select an acquisition mode for civic defect assessment',
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      fontFamily: 'Inter',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  color: isLight
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Modes Grid
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _FieldModeCard(
                    icon: Icons.camera_enhance_rounded,
                    title: 'Standard Defect Capture',
                    subtitle:
                        'Single-shot capture with AI quality gate & EXIF geo-watermark',
                    badge: 'Default',
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push('/capture');
                    },
                  ),
                  const SizedBox(height: 10),
                  _FieldModeCard(
                    icon: Icons.directions_walk_rounded,
                    title: 'Corridor Sweep Mode',
                    subtitle:
                        'Continuous 5s auto-capture for long road stretches',
                    badge: 'Auto Scan',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push('/capture/sweep');
                    },
                  ),
                  if (FeatureFlags.bridgeCheck) ...[
                    const SizedBox(height: 10),
                    _FieldModeCard(
                      icon: Icons.settings_input_antenna_rounded,
                      title: 'Acoustic Bridge Check',
                      subtitle:
                          '30s accelerometer & WAV FFT vibration analysis',
                      badge: 'High Accuracy',
                      color: const Color(0xFF818CF8),
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push('/bridge-check');
                      },
                    ),
                  ],
                  if (FeatureFlags.droneUpload) ...[
                    const SizedBox(height: 10),
                    _FieldModeCard(
                      icon: Icons.flight_takeoff_rounded,
                      title: 'Drone Aerial Ingestion',
                      subtitle:
                          'Chunked 5MB video upload with pause & resume',
                      badge: 'Multipart',
                      color: const Color(0xFF0EA5E9),
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push('/drone-upload');
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final VoidCallback onTap;

  const _FieldModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(isLight ? 0.08 : 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(isLight ? 0.35 : 0.24),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(isLight ? 0.14 : 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurface,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(isLight ? 0.15 : 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: color,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      fontFamily: 'Inter',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.6), size: 14),
          ],
        ),
      ),
    );
  }
}

