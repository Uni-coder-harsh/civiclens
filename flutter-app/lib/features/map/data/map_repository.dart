import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../shared/defect.dart';
import '../../../shared/report_payload.dart';

/// Repository wrapping the map-related [InfrastructureApi] calls.
class MapRepository {
  final Ref _ref;

  MapRepository(this._ref);

  /// Fetches nearby defects within [radiusMeters] of ([lat], [lng]).
  /// Optionally filtered by [statuses].
  Future<List<NearbyDefect>> fetchNearbyDefects(
    double lat,
    double lng,
    double radiusMeters, {
    List<DefectStatus>? statuses,
  }) {
    final api = _ref.read(apiClientProvider);
    return api.fetchNearbyDefects(lat, lng, radiusMeters, statuses: statuses);
  }

  /// Fetches coverage cells for the given bounding box at [zoom] level.
  Future<List<CoverageCell>> fetchCoverage(
    double swLat,
    double swLng,
    double neLat,
    double neLng,
    int zoom,
  ) {
    final api = _ref.read(apiClientProvider);
    return api.fetchCoverage(swLat, swLng, neLat, neLng, zoom);
  }
}

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return MapRepository(ref);
});
