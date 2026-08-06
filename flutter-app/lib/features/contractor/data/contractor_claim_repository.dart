import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';

/// Repository for contractor-specific API actions.
///
/// Every mutating method is role-guarded: it throws [ForbiddenException] if
/// the active session role is not `contractor`.
class ContractorClaimRepository {
  final Ref _ref;

  ContractorClaimRepository(this._ref);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns the contractor's active claims queue.
  Future<List<TicketSummary>> fetchMyClaims() {
    final api = _ref.read(apiClientProvider);
    return api.fetchTicketQueue(forRole: UserRole.contractor);
  }

  // ── Mutations (role-guarded) ───────────────────────────────────────────────

  /// Claims an unclaimed ticket for the current contractor.
  Future<ReportResponse> claimTicket(String reportId) async {
    _requireContractor('claimTicket');
    final api = _ref.read(apiClientProvider);
    return api.claimTicket(reportId);
  }

  /// Submits after-photo resolution media.
  Future<ReportResponse> submitResolutionMedia(
    String reportId,
    ResolutionMedia media,
  ) async {
    _requireContractor('submitResolutionMedia');
    final api = _ref.read(apiClientProvider);
    return api.submitResolutionMedia(reportId, media);
  }

  /// Posts a right-of-reply comment on the ticket.
  Future<void> submitContractorReply(
    String reportId,
    ContractorReply reply,
  ) async {
    _requireContractor('submitContractorReply');
    final api = _ref.read(apiClientProvider);
    return api.submitContractorReply(reportId, reply);
  }

  // ── Guard ─────────────────────────────────────────────────────────────────

  void _requireContractor(String action) {
    final session = _ref.read(authSessionProvider);
    if (!session.isContractor) {
      throw ForbiddenException(action, UserRole.contractor);
    }
  }
}

final contractorClaimRepositoryProvider =
    Provider<ContractorClaimRepository>((ref) {
  return ContractorClaimRepository(ref);
});
