import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../shared/defect.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';

/// Repository for WitnessMode — fetches nearby unverified reports and
/// submits peer confirmations.
class WitnessRepository {
  final Ref _ref;

  WitnessRepository(this._ref);

  /// Returns unverified [NearbyDefect] items within [radiusMeters] of
  /// ([lat], [lng]) that are eligible for witness confirmation.
  Future<List<NearbyDefect>> fetchWitnessableNearby(
    double lat,
    double lng, {
    double radiusMeters = 50,
  }) {
    final api = _ref.read(apiClientProvider);
    return api.fetchWitnessableNearby(lat, lng, radiusMeters: radiusMeters);
  }

  /// Submits a peer [WitnessConfirmation] record to the server.
  Future<ReportResponse> submitWitnessConfirmation(
    WitnessConfirmation confirmation,
  ) {
    final api = _ref.read(apiClientProvider);
    return api.submitWitnessConfirmation(confirmation);
  }
}

final witnessRepositoryProvider = Provider<WitnessRepository>((ref) {
  return WitnessRepository(ref);
});
