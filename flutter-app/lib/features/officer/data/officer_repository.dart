import '../../../core/network/api_providers.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for officer-specific API actions.
///
/// Every mutating method is role-guarded: it throws [ForbiddenException] if
/// the active session is not `officer` or `admin`.
class OfficerRepository {
  final Ref _ref;

  OfficerRepository(this._ref);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Fetches the officer triage queue, optionally filtered by [status] / [zone].
  Future<List<TicketSummary>> fetchQueue({
    DefectStatus? status,
    String? zone,
  }) {
    final api = _ref.read(apiClientProvider);
    return api.fetchTicketQueue(
      forRole: UserRole.officer,
      status: status,
      zone: zone,
    );
  }

  // ── Mutations (role-guarded) ───────────────────────────────────────────────

  /// Verifies a report on-site or from photos.
  Future<ReportResponse> verifyReport(
    String reportId, {
    required bool fromSite,
    GeoCapture? siteGps,
    String? note,
  }) async {
    _requireOfficer('verifyReport');
    final api = _ref.read(apiClientProvider);
    return api.verifyReport(
      reportId,
      fromSite: fromSite,
      siteGps: siteGps,
      note: note,
    );
  }

  /// Assigns a contractor to the report with an SLA deadline.
  Future<ReportResponse> assignContractor(
    String reportId, {
    required String contractorId,
    int slaDays = 30,
  }) async {
    _requireOfficer('assignContractor');
    final api = _ref.read(apiClientProvider);
    return api.assignContractor(
      reportId,
      contractorId: contractorId,
      slaDays: slaDays,
    );
  }

  /// Rejects a report with a mandatory reason.
  Future<ReportResponse> rejectReport(
    String reportId, {
    required String reason,
  }) async {
    _requireOfficer('rejectReport');
    final api = _ref.read(apiClientProvider);
    return api.rejectReport(reportId, reason: reason);
  }

  /// Approves a contractor's submitted resolution.
  Future<ReportResponse> approveResolution(String reportId) async {
    _requireOfficer('approveResolution');
    final api = _ref.read(apiClientProvider);
    return api.approveResolution(reportId);
  }

  // ── Guard ─────────────────────────────────────────────────────────────────

  void _requireOfficer(String action) {
    final session = _ref.read(authSessionProvider);
    if (!session.isOfficer) {
      throw ForbiddenException(action, UserRole.officer);
    }
  }
}

final officerRepositoryProvider = Provider<OfficerRepository>((ref) {
  return OfficerRepository(ref);
});
