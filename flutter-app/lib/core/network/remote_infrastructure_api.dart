import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

import '../../shared/contractor.dart';
import '../../shared/defect.dart';
import '../../shared/report_payload.dart';
import '../../shared/ticket.dart';
import '../../shared/vibration_payload.dart';
import 'infrastructure_api.dart';

class RemoteInfrastructureApi implements InfrastructureApi {
  final Dio dio;

  RemoteInfrastructureApi({required this.dio});

  @override
  Future<ReportResponse> uploadInfrastructureReport(
    ReportPayload payload, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final imagePath = payload.imagePath;
    final fileExists = imagePath.isNotEmpty &&
        !imagePath.startsWith('mock://') &&
        File(imagePath).existsSync();

    final formData = FormData.fromMap({
      'payload': jsonEncode(payload.toJson()),
      if (fileExists)
        'image': await MultipartFile.fromFile(imagePath,
            filename: 'defect_image.jpg'),
    });

    try {
      print('[Upload] Sending report to backend, image present: $fileExists');
      Response response;
      try {
        response = await dio.post(
          '/v1/reports',
          data: formData,
          onSendProgress: onProgress,
        );
      } catch (_) {
        response = await dio.post(
          '/api/v1/reports',
          data: formData,
          onSendProgress: onProgress,
        );
      }
      return ReportResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('[Upload] DioException: ${e.message}');
      if (e.response != null) {
        print('[Upload] Status: ${e.response?.statusCode}');
        print('[Upload] Body: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      print('[Upload] Unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<NearbyDefect> fetchDefect(String reportId) async {
    final response = await dio.get('/v1/reports/$reportId');
    return NearbyDefect.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<DuplicateMatch>> checkDuplicates(
      double lat, double lng, double radiusMeters) async {
    final response = await dio.get(
      '/v1/defects/duplicates',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_m': radiusMeters,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => DuplicateMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReportResponse> attachToTicket(
      String sourceReportId, String targetReportId) async {
    final response = await dio.post(
      '/v1/reports/$targetReportId/attach',
      data: {'source_report_id': sourceReportId},
    );
    return ReportResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<TicketSummary>> fetchTicketQueue({
    UserRole? forRole,
    DefectStatus? status,
    String? zone,
  }) async {
    final response = await dio.get(
      '/v1/tickets/queue',
      queryParameters: {
        if (forRole != null) 'for_role': forRole.name,
        if (status != null) 'status': status.name,
        if (zone != null) 'zone': zone,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => TicketSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ReportEvent>> fetchReportTimeline(String reportId) async {
    final response = await dio.get('/v1/reports/$reportId/timeline');
    return (response.data as List<dynamic>)
        .map((e) => ReportEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<NearbyDefect>> fetchWitnessableNearby(
    double lat,
    double lng, {
    double radiusMeters = 50,
  }) async {
    final response = await dio.get(
      '/v1/reports/witness-nearby',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_m': radiusMeters,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => NearbyDefect.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReportResponse> submitWitnessConfirmation(
      WitnessConfirmation confirmation) async {
    final response = await dio.post(
      '/v1/reports/${confirmation.reportId}/witness',
      data: confirmation.toJson(),
    );
    return ReportResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportResponse> verifyReport(
    String reportId, {
    required bool fromSite,
    GeoCapture? siteGps,
    String? note,
  }) async {
    final response = await dio.post(
      '/v1/reports/$reportId/verify',
      data: {
        'from_site': fromSite,
        if (siteGps != null) 'site_gps': siteGps.toJson(),
        if (note != null) 'note': note,
      },
    );
    return ReportResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportResponse> assignContractor(
    String reportId, {
    required String contractorId,
    int slaDays = 30,
  }) async {
    final response = await dio.post(
      '/v1/reports/$reportId/assign',
      data: {
        'contractor_id': contractorId,
        'sla_days': slaDays,
      },
    );
    return ReportResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportResponse> rejectReport(
    String reportId, {
    required String reason,
  }) async {
    final response = await dio.post(
      '/v1/reports/$reportId/reject',
      data: {'reason': reason},
    );
    return ReportResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportResponse> approveResolution(String reportId) async {
    final response = await dio.post('/v1/reports/$reportId/approve');
    return ReportResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportResponse> claimTicket(String reportId) async {
    final response = await dio.post('/v1/reports/$reportId/claim');
    return ReportResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportResponse> submitResolutionMedia(
    String reportId,
    ResolutionMedia media,
  ) async {
    final response = await dio.post(
      '/v1/reports/$reportId/resolution',
      data: media.toJson(),
    );
    return ReportResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> submitContractorReply(
    String reportId,
    ContractorReply reply,
  ) async {
    await dio.post(
      '/v1/reports/$reportId/reply',
      data: reply.toJson(),
    );
  }

  @override
  Future<AcousticDiagnosticResult> submitAcousticDiagnostic(
      VibrationPayload payload) async {
    final response = await dio.post(
      '/v1/bridge-check',
      data: payload.toJson(),
    );
    return AcousticDiagnosticResult.fromJson(
        response.data as Map<String, dynamic>);
  }

  @override
  Future<List<ContractorSummary>> fetchLeaderboard({int limit = 50}) async {
    final response = await dio.get(
      '/v1/contractors/leaderboard',
      queryParameters: {'limit': limit},
    );
    return (response.data as List<dynamic>)
        .map((e) => ContractorSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ContractorPassport> fetchContractorPassport(
      String contractorId) async {
    final response = await dio.get('/v1/contractors/$contractorId/passport');
    return ContractorPassport.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<NearbyDefect>> fetchNearbyDefects(
    double lat,
    double lng,
    double radiusMeters, {
    List<DefectStatus>? statuses,
  }) async {
    final response = await dio.get(
      '/v1/defects/nearby',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_m': radiusMeters,
        if (statuses != null) 'status': statuses.map((s) => s.name).join(','),
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => NearbyDefect.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CoverageCell>> fetchCoverage(
    double swLat,
    double swLng,
    double neLat,
    double neLng,
    int zoom,
  ) async {
    final response = await dio.get(
      '/v1/defects/coverage',
      queryParameters: {
        'sw_lat': swLat,
        'sw_lng': swLng,
        'ne_lat': neLat,
        'ne_lng': neLng,
        'zoom': zoom,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => CoverageCell.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ResolutionMedia> fetchResolution(String reportId) async {
    final response = await dio.get('/v1/reports/$reportId/resolution');
    return ResolutionMedia.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CivicScore> fetchCivicScore(String userId) async {
    final response = await dio.get('/v1/users/$userId/score');
    return CivicScore.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<ReportResponse>> fetchMyReports(String userId) async {
    final response = await dio.get('/v1/users/$userId/reports');
    return (response.data as List<dynamic>)
        .map((e) => ReportResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ReportResponse>> syncPendingDrafts(
      List<ReportPayload> drafts) async {
    final response = await dio.post(
      '/v1/reports/sync',
      data: drafts.map((d) => d.toJson()).toList(),
    );
    return (response.data as List<dynamic>)
        .map((e) => ReportResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteReport(String reportId) async {
    await dio.delete('/v1/reports/$reportId');
  }

  @override
  Future<AiDetectionResult?> fetchAiAnalysis(String reportId) async {
    try {
      final response = await dio.get('/v1/reports/$reportId/ai-analysis');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'no_inference') return null;
        return AiDetectionResult.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AiDetectionResult> retestAiAnalysis(String reportId) async {
    final response = await dio.post('/v1/reports/$reportId/ai-analysis/retest');
    return AiDetectionResult.fromJson(response.data as Map<String, dynamic>);
  }
}
