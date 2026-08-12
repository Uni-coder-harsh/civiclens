import '../../shared/contractor.dart';
import '../../shared/defect.dart';
import '../../shared/report_payload.dart';
import '../../shared/ticket.dart';
import '../../shared/vibration_payload.dart';

abstract class InfrastructureApi {
  // Reports (Citizen)
  Future<ReportResponse> uploadInfrastructureReport(
    ReportPayload payload, {
    void Function(int sent, int total)? onProgress,
  });

  Future<NearbyDefect> fetchDefect(String reportId);

  // Duplicates & attach
  Future<List<DuplicateMatch>> checkDuplicates(
      double lat, double lng, double radiusMeters);

  Future<ReportResponse> attachToTicket(
      String sourceReportId, String targetReportId);

  // Tickets & Roles (v2.2) - MUST use forRole, NEVER as
  Future<List<TicketSummary>> fetchTicketQueue({
    UserRole? forRole,
    DefectStatus? status,
    String? zone,
  });

  Future<List<ReportEvent>> fetchReportTimeline(String reportId);

  // WitnessMode (v2.3)
  Future<List<NearbyDefect>> fetchWitnessableNearby(
    double lat,
    double lng, {
    double radiusMeters = 50,
  });

  Future<ReportResponse> submitWitnessConfirmation(
      WitnessConfirmation confirmation);

  // Officer actions (v2.2)
  Future<ReportResponse> verifyReport(
    String reportId, {
    required bool fromSite,
    GeoCapture? siteGps,
    String? note,
  });

  Future<ReportResponse> assignContractor(
    String reportId, {
    required String contractorId,
    int slaDays = 30,
  });

  Future<ReportResponse> rejectReport(
    String reportId, {
    required String reason,
  });

  Future<ReportResponse> approveResolution(String reportId);

  // Contractor actions (v2.2)
  Future<ReportResponse> claimTicket(String reportId);

  Future<ReportResponse> submitResolutionMedia(
    String reportId,
    ResolutionMedia media,
  );

  Future<void> submitContractorReply(
    String reportId,
    ContractorReply reply,
  );

  // Bridge Check (Phase 2)
  Future<AcousticDiagnosticResult> submitAcousticDiagnostic(
      VibrationPayload payload);

  // Contractors & Leaderboard
  Future<List<ContractorSummary>> fetchLeaderboard({int limit = 50});

  Future<ContractorPassport> fetchContractorPassport(String contractorId);

  // Map & Coverage
  Future<List<NearbyDefect>> fetchNearbyDefects(
    double lat,
    double lng,
    double radiusMeters, {
    List<DefectStatus>? statuses,
  });

  Future<List<CoverageCell>> fetchCoverage(
    double swLat,
    double swLng,
    double neLat,
    double neLng,
    int zoom,
  );

  // Resolution / share (Phase 1 — MVP payoff)
  Future<ResolutionMedia> fetchResolution(String reportId);

  // Profile
  Future<CivicScore> fetchCivicScore(String userId);

  Future<List<ReportResponse>> fetchMyReports(String userId);

  // Sync
  Future<List<ReportResponse>> syncPendingDrafts(List<ReportPayload> drafts);

  // Delete
  Future<void> deleteReport(String reportId);

  // AI Analysis
  Future<AiDetectionResult?> fetchAiAnalysis(String reportId);
}
