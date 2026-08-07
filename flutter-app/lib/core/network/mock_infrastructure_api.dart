import 'dart:math';

import '../../shared/contractor.dart';
import '../../shared/defect.dart';
import '../../shared/escalation.dart';
import '../../shared/report_payload.dart';
import '../../shared/ticket.dart';
import '../../shared/vibration_payload.dart';
import 'infrastructure_api.dart';

class MockInfrastructureApi implements InfrastructureApi {
  static const Duration _simulatedLatency = Duration(milliseconds: 400);

  // In-memory data stores
  final Map<String, NearbyDefect> _defects = {};
  final Map<String, TicketSummary> _tickets = {};
  final Map<String, List<ReportEvent>> _timelines = {};
  final Map<String, ResolutionMedia> _resolutions = {};
  final Map<String, List<ContractorReply>> _replies = {};
  final Map<String, ContractorPassport> _passports = {};
  final List<ContractorSummary> _leaderboard = [];

  MockInfrastructureApi() {
    _seedData();
  }

  void _seedData() {
    final now = DateTime.now().toUtc();

    // Seeded Contractor Identity
    const contractorSummary = ContractorSummary(
      contractorId: 'ctr_pune_infra',
      companyName: 'Pune Infra Buildtech Ltd',
      grade: 4.6,
      activeDefects: 3,
      completedProjects: 42,
      streakMonths: 8,
      kycVerified: true,
    );
    _leaderboard.add(contractorSummary);

    _passports['ctr_pune_infra'] = ContractorPassport(
      summary: contractorSummary,
      projects: [
        ContractorProject(
          projectId: 'prj_01',
          name: 'Z-Bridge Structural Maintenance',
          scope: 'bridge',
          zone: 'Pune Central',
          startedAtUtc: now.subtract(const Duration(days: 120)),
          completedAtUtc: now.subtract(const Duration(days: 10)),
          rating: 4.8,
          defectsAttributed: 12,
        ),
      ],
      defects: [
        ContractorDefectRef(
          reportId: 'report_04',
          category: ReportCategory.roadCrack,
          status: DefectStatus.assigned,
          reportedAtUtc: now.subtract(const Duration(days: 2)),
          severityWeight: 1.5,
        ),
      ],
      scoreBreakdown: const ScoreBreakdown(
        quality: 4.7,
        timeliness: 4.5,
        safety: 4.8,
        compliance: 4.4,
      ),
      warranties: [
        WarrantyState(
          defectId: 'report_07',
          warrantyExpiresAtUtc: now.add(const Duration(days: 355)),
          recurrences: 0,
          scorePenaltyApplied: 0.0,
        ),
      ],
    );

    // 8 Seeded Defects around Pune (18.5204, 73.8567)
    final seeded = [
      // 1. Critical Bridge Crack at Z-Bridge Pune
      _DefectSeed(
        id: 'report_01',
        category: ReportCategory.bridgeCrack,
        severity: ReportSeverity.critical,
        status: DefectStatus.aiVerified,
        lat: 18.5166,
        lng: 73.8427,
        watermarkVerified: true,
        aiConfidence: 0.96,
        zone: 'Deccan Gymkhana',
        thumb: 'https://images.unsplash.com/photo-1541888946425-d0fbb186a5b7',
      ),
      // 2. Duplicate pair candidate #1
      _DefectSeed(
        id: 'report_02',
        category: ReportCategory.pothole,
        severity: ReportSeverity.high,
        status: DefectStatus.submitted,
        lat: 18.5204,
        lng: 73.8567,
        watermarkVerified: true,
        aiConfidence: 0.88,
        zone: 'Shivajinagar',
        thumb: 'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7',
      ),
      // 3. Duplicate pair candidate #2 within 4 meters
      _DefectSeed(
        id: 'report_03',
        category: ReportCategory.pothole,
        severity: ReportSeverity.high,
        status: DefectStatus.submitted,
        lat: 18.52043,
        lng: 73.85672,
        watermarkVerified: true,
        aiConfidence: 0.89,
        zone: 'Shivajinagar',
        thumb: 'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7',
      ),
      // 4. Assigned Road Crack
      _DefectSeed(
        id: 'report_04',
        category: ReportCategory.roadCrack,
        severity: ReportSeverity.medium,
        status: DefectStatus.assigned,
        lat: 18.5250,
        lng: 73.8500,
        contractorId: 'ctr_pune_infra',
        watermarkVerified: true,
        aiConfidence: 0.91,
        zone: 'Model Colony',
        thumb: 'https://images.unsplash.com/photo-1578991624414-276ef23a534f',
      ),
      // 5. In-Progress Manhole Cover
      _DefectSeed(
        id: 'report_05',
        category: ReportCategory.manhole,
        severity: ReportSeverity.high,
        status: DefectStatus.inProgress,
        lat: 18.5180,
        lng: 73.8600,
        contractorId: 'ctr_pune_infra',
        watermarkVerified: true,
        aiConfidence: 0.94,
        zone: 'FC Road',
        thumb: 'https://images.unsplash.com/photo-1509114397022-ed747cca3f65',
      ),
      // 6. Awaiting Acceptance Defect
      _DefectSeed(
        id: 'report_06',
        category: ReportCategory.guardrail,
        severity: ReportSeverity.medium,
        status: DefectStatus.awaitAcceptance,
        lat: 18.5300,
        lng: 73.8400,
        contractorId: 'ctr_pune_infra',
        watermarkVerified: true,
        aiConfidence: 0.85,
        zone: 'Aundh',
        thumb: 'https://images.unsplash.com/photo-1590486803833-1c5dc8ddd4c8',
      ),
      // 7. Resolved Defect with before/after photos
      _DefectSeed(
        id: 'report_07',
        category: ReportCategory.pothole,
        severity: ReportSeverity.low,
        status: DefectStatus.resolved,
        lat: 18.5100,
        lng: 73.8550,
        contractorId: 'ctr_pune_infra',
        watermarkVerified: true,
        aiConfidence: 0.95,
        zone: 'Swargate',
        thumb: 'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7',
      ),
      // 8. Rejected Defect
      _DefectSeed(
        id: 'report_08',
        category: ReportCategory.other,
        severity: ReportSeverity.low,
        status: DefectStatus.rejected,
        lat: 18.5050,
        lng: 73.8620,
        watermarkVerified: false,
        aiConfidence: 0.40,
        zone: 'Bibwewadi',
        thumb: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413',
      ),
    ];

    for (final s in seeded) {
      final capture = GeoCapture(
        latitude: s.lat,
        longitude: s.lng,
        altitudeMeters: 560.0,
        accuracyMeters: 4.5,
        bearingDegrees: 180.0,
        speedMps: 0.0,
        capturedAtUtc: now.subtract(const Duration(hours: 12)),
      );

      _defects[s.id] = NearbyDefect(
        reportId: s.id,
        status: s.status,
        category: s.category,
        latitude: s.lat,
        longitude: s.lng,
        contractorId: s.contractorId,
        thumbnailUrl: s.thumb,
        watermarkVerified: s.watermarkVerified,
      );

      final sla = s.status == DefectStatus.assigned ||
              s.status == DefectStatus.inProgress ||
              s.status == DefectStatus.awaitAcceptance
          ? SlaClock(
              stage: s.status.name,
              deadlineUtc: now.add(const Duration(days: 20)),
              daysRemaining: 20,
              norm: 'PWD',
            )
          : null;

      _tickets[s.id] = TicketSummary(
        reportId: s.id,
        status: s.status,
        category: s.category,
        severity: s.severity,
        capture: capture,
        zone: s.zone,
        thumbnailUrl: s.thumb,
        watermarkVerified: s.watermarkVerified,
        aiConfidence: s.aiConfidence,
        daysInStatus: 2,
        slaClock: sla,
        assignedContractorId: s.contractorId,
      );

      _timelines[s.id] = [
        ReportEvent(
          eventId: 'evt_${s.id}_01',
          reportId: s.id,
          fromStatus: DefectStatus.submitted,
          toStatus: DefectStatus.submitted,
          action: TicketAction.created,
          actorRole: UserRole.citizen,
          actorId: 'usr_citizen_01',
          actorLabel: 'Citizen Reporter',
          location: capture,
          verifiedFromSite: true,
          atUtc: now.subtract(const Duration(hours: 12)),
        ),
      ];

      if (s.status != DefectStatus.submitted) {
        _timelines[s.id]!.add(
          ReportEvent(
            eventId: 'evt_${s.id}_02',
            reportId: s.id,
            fromStatus: DefectStatus.submitted,
            toStatus: s.status,
            action: TicketAction.aiVerdict,
            actorRole: UserRole.admin,
            actorId: 'system_ai',
            actorLabel: 'CivicLens AI System',
            verifiedFromSite: false,
            note:
                'AI confidence: ${(s.aiConfidence * 100).toStringAsFixed(0)}%',
            atUtc: now.subtract(const Duration(hours: 11)),
          ),
        );
      }
    }

    // Resolution media for report_07
    _resolutions['report_07'] = ResolutionMedia(
      reportId: 'report_07',
      afterPhotoUrls: [
        'https://images.unsplash.com/photo-1541888946425-d0fbb186a5b7',
      ],
      contractorNote: 'Pothole filled with cold asphalt mix and compacted.',
      resolvedAtUtc: now.subtract(const Duration(hours: 2)),
      repairedByContractorId: 'ctr_pune_infra',
    );
  }

  double _calculateDistanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const p = pi / 180;
    final dx = (lng2 - lng1) * 111320 * cos(lat1 * p);
    final dy = (lat2 - lat1) * 110540;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  Future<ReportResponse> uploadInfrastructureReport(
    ReportPayload payload, {
    void Function(int sent, int total)? onProgress,
  }) async {
    await Future.delayed(_simulatedLatency);
    onProgress?.call(100, 100);

    final now = DateTime.now().toUtc();
    const status = DefectStatus.aiVerified;

    final defect = NearbyDefect(
      reportId: payload.id,
      status: status,
      category: payload.category,
      latitude: payload.capture.latitude,
      longitude: payload.capture.longitude,
      contractorId: payload.contractorId,
      thumbnailUrl: payload.thumbnailPath ?? payload.imagePath,
      watermarkVerified: true,
    );
    _defects[payload.id] = defect;

    final ticket = TicketSummary(
      reportId: payload.id,
      status: status,
      category: payload.category,
      severity: payload.severity,
      capture: payload.capture,
      zone: 'Pune Central',
      thumbnailUrl: payload.thumbnailPath ?? payload.imagePath,
      watermarkVerified: true,
      aiConfidence: 0.92,
      daysInStatus: 0,
      assignedContractorId: payload.contractorId,
    );
    _tickets[payload.id] = ticket;

    _timelines[payload.id] = [
      ReportEvent(
        eventId: 'evt_${payload.id}_created',
        reportId: payload.id,
        fromStatus: DefectStatus.submitted,
        toStatus: DefectStatus.submitted,
        action: TicketAction.created,
        actorRole: UserRole.citizen,
        actorId: payload.userId.isNotEmpty ? payload.userId : 'guest_user',
        actorLabel: payload.isGuest ? 'Guest Citizen' : 'Registered Citizen',
        location: payload.capture,
        verifiedFromSite: true,
        atUtc: now,
      ),
      ReportEvent(
        eventId: 'evt_${payload.id}_ai',
        reportId: payload.id,
        fromStatus: DefectStatus.submitted,
        toStatus: status,
        action: TicketAction.aiVerdict,
        actorRole: UserRole.admin,
        actorId: 'system_ai',
        actorLabel: 'CivicLens AI System',
        verifiedFromSite: false,
        note: 'Verified with 92% confidence',
        atUtc: now,
      ),
    ];

    return ReportResponse(
      reportId: payload.id,
      status: status,
      aiConfidence: '92%',
      aiLabel: payload.category.name,
      assignedContractorId: payload.contractorId,
      civicScoreDelta: 25,
      createdAtUtc: now,
    );
  }

  @override
  Future<NearbyDefect> fetchDefect(String reportId) async {
    await Future.delayed(_simulatedLatency);
    final d = _defects[reportId];
    if (d == null) {
      throw Exception('Defect not found: $reportId');
    }
    return d;
  }

  @override
  Future<List<DuplicateMatch>> checkDuplicates(
      double lat, double lng, double radiusMeters) async {
    await Future.delayed(_simulatedLatency);
    final matches = <DuplicateMatch>[];
    for (final d in _defects.values) {
      final dist = _calculateDistanceMeters(lat, lng, d.latitude, d.longitude);
      if (dist <= radiusMeters) {
        matches.add(
          DuplicateMatch(
            existingReportId: d.reportId,
            distanceMeters: dist,
            status: d.status,
            contractorId: d.contractorId,
            thumbnailUrl: d.thumbnailUrl,
          ),
        );
      }
    }
    matches.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return matches;
  }

  @override
  Future<ReportResponse> attachToTicket(
      String sourceReportId, String targetReportId) async {
    await Future.delayed(_simulatedLatency);
    final target = _tickets[targetReportId];
    if (target == null) throw Exception('Target ticket not found');

    final now = DateTime.now().toUtc();
    _timelines[targetReportId]?.add(
      ReportEvent(
        eventId: 'evt_${targetReportId}_attach_${now.millisecondsSinceEpoch}',
        reportId: targetReportId,
        fromStatus: target.status,
        toStatus: target.status,
        action: TicketAction.attach,
        actorRole: UserRole.citizen,
        actorId: 'usr_citizen',
        actorLabel: 'Citizen Reporter (Duplicate Attached)',
        verifiedFromSite: true,
        note: 'Attached source report: $sourceReportId',
        atUtc: now,
      ),
    );

    return ReportResponse(
      reportId: targetReportId,
      status: target.status,
      civicScoreDelta: 10,
      createdAtUtc: now,
    );
  }

  @override
  Future<List<TicketSummary>> fetchTicketQueue({
    UserRole? forRole,
    DefectStatus? status,
    String? zone,
  }) async {
    await Future.delayed(_simulatedLatency);
    return _tickets.values.where((t) {
      if (status != null && t.status != status) return false;
      if (zone != null && t.zone != zone) return false;
      if (forRole == UserRole.contractor &&
          t.assignedContractorId != 'ctr_pune_infra') {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<List<ReportEvent>> fetchReportTimeline(String reportId) async {
    await Future.delayed(_simulatedLatency);
    return _timelines[reportId] ?? [];
  }

  @override
  Future<List<NearbyDefect>> fetchWitnessableNearby(
    double lat,
    double lng, {
    double radiusMeters = 50,
  }) async {
    await Future.delayed(_simulatedLatency);
    return _defects.values.where((d) {
      if (d.status == DefectStatus.submitted ||
          d.status == DefectStatus.aiVerified) {
        final dist =
            _calculateDistanceMeters(lat, lng, d.latitude, d.longitude);
        return dist <= radiusMeters;
      }
      return false;
    }).toList();
  }

  @override
  Future<ReportResponse> submitWitnessConfirmation(
      WitnessConfirmation confirmation) async {
    await Future.delayed(_simulatedLatency);
    final t = _tickets[confirmation.reportId];
    if (t == null) throw Exception('Report not found');

    final now = DateTime.now().toUtc();
    _timelines[confirmation.reportId]?.add(
      ReportEvent(
        eventId: 'evt_${confirmation.reportId}_witness',
        reportId: confirmation.reportId,
        fromStatus: t.status,
        toStatus: t.status,
        action: TicketAction.verify,
        actorRole: UserRole.citizen,
        actorId: confirmation.witnessUserId,
        actorLabel: 'Witness Peer Confirm',
        location: confirmation.capture,
        verifiedFromSite: true,
        note: 'Witness confirmed report from location',
        atUtc: confirmation.atUtc,
      ),
    );

    return ReportResponse(
      reportId: confirmation.reportId,
      status: t.status,
      civicScoreDelta: 15,
      createdAtUtc: now,
    );
  }

  @override
  Future<ReportResponse> verifyReport(
    String reportId, {
    required bool fromSite,
    GeoCapture? siteGps,
    String? note,
  }) async {
    await Future.delayed(_simulatedLatency);
    final ticket = _tickets[reportId];
    if (ticket == null) throw Exception('Ticket not found');

    final now = DateTime.now().toUtc();
    const newStatus = DefectStatus.aiVerified;

    _updateTicketStatus(reportId, newStatus);

    _timelines[reportId]?.add(
      ReportEvent(
        eventId: 'evt_${reportId}_off_verify',
        reportId: reportId,
        fromStatus: ticket.status,
        toStatus: newStatus,
        action: TicketAction.verify,
        actorRole: UserRole.officer,
        actorId: 'user_off_01',
        actorLabel: 'Officer · Pune Municipal Corp',
        location: siteGps,
        verifiedFromSite: fromSite,
        note: note ?? 'On-site officer verification complete',
        atUtc: now,
      ),
    );

    return ReportResponse(
      reportId: reportId,
      status: newStatus,
      civicScoreDelta: 0,
      createdAtUtc: now,
    );
  }

  @override
  Future<ReportResponse> assignContractor(
    String reportId, {
    required String contractorId,
    int slaDays = 30,
  }) async {
    await Future.delayed(_simulatedLatency);
    final ticket = _tickets[reportId];
    if (ticket == null) throw Exception('Ticket not found');

    final now = DateTime.now().toUtc();
    const newStatus = DefectStatus.assigned;

    final sla = SlaClock(
      stage: 'assigned',
      deadlineUtc: now.add(Duration(days: slaDays)),
      daysRemaining: slaDays,
      norm: 'PWD',
    );

    _tickets[reportId] = TicketSummary(
      reportId: ticket.reportId,
      status: newStatus,
      category: ticket.category,
      severity: ticket.severity,
      capture: ticket.capture,
      zone: ticket.zone,
      thumbnailUrl: ticket.thumbnailUrl,
      watermarkVerified: ticket.watermarkVerified,
      aiConfidence: ticket.aiConfidence,
      daysInStatus: 0,
      slaClock: sla,
      assignedContractorId: contractorId,
    );

    final d = _defects[reportId];
    if (d != null) {
      _defects[reportId] = NearbyDefect(
        reportId: d.reportId,
        status: newStatus,
        category: d.category,
        latitude: d.latitude,
        longitude: d.longitude,
        contractorId: contractorId,
        thumbnailUrl: d.thumbnailUrl,
        watermarkVerified: d.watermarkVerified,
      );
    }

    _timelines[reportId]?.add(
      ReportEvent(
        eventId: 'evt_${reportId}_assign',
        reportId: reportId,
        fromStatus: ticket.status,
        toStatus: newStatus,
        action: TicketAction.assign,
        actorRole: UserRole.officer,
        actorId: 'user_off_01',
        actorLabel: 'Officer · Pune Municipal Corp',
        verifiedFromSite: false,
        note: 'Assigned to contractor $contractorId with $slaDays days SLA',
        atUtc: now,
      ),
    );

    return ReportResponse(
      reportId: reportId,
      status: newStatus,
      assignedContractorId: contractorId,
      civicScoreDelta: 0,
      createdAtUtc: now,
      slaClock: sla,
    );
  }

  @override
  Future<ReportResponse> rejectReport(
    String reportId, {
    required String reason,
  }) async {
    await Future.delayed(_simulatedLatency);
    final ticket = _tickets[reportId];
    if (ticket == null) throw Exception('Ticket not found');

    final now = DateTime.now().toUtc();
    const newStatus = DefectStatus.rejected;
    _updateTicketStatus(reportId, newStatus);

    _timelines[reportId]?.add(
      ReportEvent(
        eventId: 'evt_${reportId}_reject',
        reportId: reportId,
        fromStatus: ticket.status,
        toStatus: newStatus,
        action: TicketAction.reject,
        actorRole: UserRole.officer,
        actorId: 'user_off_01',
        actorLabel: 'Officer · Pune Municipal Corp',
        verifiedFromSite: false,
        note: reason,
        atUtc: now,
      ),
    );

    return ReportResponse(
      reportId: reportId,
      status: newStatus,
      civicScoreDelta: 0,
      createdAtUtc: now,
    );
  }

  @override
  Future<ReportResponse> approveResolution(String reportId) async {
    await Future.delayed(_simulatedLatency);
    final ticket = _tickets[reportId];
    if (ticket == null) throw Exception('Ticket not found');

    final now = DateTime.now().toUtc();
    const newStatus = DefectStatus.resolved;
    _updateTicketStatus(reportId, newStatus);

    _timelines[reportId]?.add(
      ReportEvent(
        eventId: 'evt_${reportId}_approve',
        reportId: reportId,
        fromStatus: ticket.status,
        toStatus: newStatus,
        action: TicketAction.approve,
        actorRole: UserRole.officer,
        actorId: 'user_off_01',
        actorLabel: 'Officer · Pune Municipal Corp',
        verifiedFromSite: true,
        note: 'Resolution approved by officer',
        atUtc: now,
      ),
    );

    return ReportResponse(
      reportId: reportId,
      status: newStatus,
      civicScoreDelta: 50,
      createdAtUtc: now,
    );
  }

  @override
  Future<ReportResponse> claimTicket(String reportId) async {
    await Future.delayed(_simulatedLatency);
    final ticket = _tickets[reportId];
    if (ticket == null) throw Exception('Ticket not found');

    final now = DateTime.now().toUtc();
    const newStatus = DefectStatus.inProgress;
    _updateTicketStatus(reportId, newStatus);

    _timelines[reportId]?.add(
      ReportEvent(
        eventId: 'evt_${reportId}_claim',
        reportId: reportId,
        fromStatus: ticket.status,
        toStatus: newStatus,
        action: TicketAction.claim,
        actorRole: UserRole.contractor,
        actorId: 'ctr_pune_infra',
        actorLabel: 'Pune Infra Buildtech Ltd',
        verifiedFromSite: true,
        note: 'Work commenced by contractor',
        atUtc: now,
      ),
    );

    return ReportResponse(
      reportId: reportId,
      status: newStatus,
      assignedContractorId: 'ctr_pune_infra',
      civicScoreDelta: 0,
      createdAtUtc: now,
    );
  }

  @override
  Future<ReportResponse> submitResolutionMedia(
    String reportId,
    ResolutionMedia media,
  ) async {
    await Future.delayed(_simulatedLatency);
    final ticket = _tickets[reportId];
    if (ticket == null) throw Exception('Ticket not found');

    final now = DateTime.now().toUtc();
    const newStatus = DefectStatus.awaitAcceptance;

    _resolutions[reportId] = media;
    _updateTicketStatus(reportId, newStatus);

    _timelines[reportId]?.add(
      ReportEvent(
        eventId: 'evt_${reportId}_submit_after',
        reportId: reportId,
        fromStatus: ticket.status,
        toStatus: newStatus,
        action: TicketAction.submitAfterPhoto,
        actorRole: UserRole.contractor,
        actorId: 'ctr_pune_infra',
        actorLabel: 'Pune Infra Buildtech Ltd',
        verifiedFromSite: true,
        note: media.contractorNote,
        atUtc: now,
      ),
    );

    return ReportResponse(
      reportId: reportId,
      status: newStatus,
      civicScoreDelta: 0,
      createdAtUtc: now,
    );
  }

  @override
  Future<void> submitContractorReply(
    String reportId,
    ContractorReply reply,
  ) async {
    await Future.delayed(_simulatedLatency);
    _replies.putIfAbsent(reportId, () => []).add(reply);

    final t = _tickets[reportId];
    if (t != null) {
      _timelines[reportId]?.add(
        ReportEvent(
          eventId: 'evt_${reportId}_reply_${reply.replyId}',
          reportId: reportId,
          fromStatus: t.status,
          toStatus: t.status,
          action: TicketAction.reply,
          actorRole: UserRole.contractor,
          actorId: reply.contractorId,
          actorLabel: 'Pune Infra Buildtech Ltd',
          verifiedFromSite: false,
          note: reply.body,
          atUtc: reply.atUtc,
        ),
      );
    }
  }

  @override
  Future<AcousticDiagnosticResult> submitAcousticDiagnostic(
      VibrationPayload payload) async {
    await Future.delayed(_simulatedLatency);
    return AcousticDiagnosticResult(
      id: payload.id,
      dominantFrequencyHz: payload.fftSummary?.dominantFrequencyHz ?? 14.5,
      energy: payload.fftSummary?.energy ?? 0.082,
      heavyVehicleCount: payload.fftSummary?.heavyVehicleCount ?? 3,
      distressIndex: 0.24,
      suggestedAction: 'schedule_inspection',
      analyzedAtUtc: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<ContractorSummary>> fetchLeaderboard({int limit = 50}) async {
    await Future.delayed(_simulatedLatency);
    return _leaderboard.take(limit).toList();
  }

  @override
  Future<ContractorPassport> fetchContractorPassport(
      String contractorId) async {
    await Future.delayed(_simulatedLatency);
    final passport = _passports[contractorId];
    if (passport == null) {
      throw Exception('Contractor passport not found: $contractorId');
    }
    return passport;
  }

  @override
  Future<List<NearbyDefect>> fetchNearbyDefects(
    double lat,
    double lng,
    double radiusMeters, {
    List<DefectStatus>? statuses,
  }) async {
    await Future.delayed(_simulatedLatency);
    return _defects.values.where((d) {
      if (statuses != null && !statuses.contains(d.status)) return false;
      final dist = _calculateDistanceMeters(lat, lng, d.latitude, d.longitude);
      return dist <= radiusMeters;
    }).toList();
  }

  @override
  Future<List<CoverageCell>> fetchCoverage(
    double swLat,
    double swLng,
    double neLat,
    double neLng,
    int zoom,
  ) async {
    await Future.delayed(_simulatedLatency);
    return const [
      CoverageCell(
        x: 1204,
        y: 890,
        zoom: 14,
        reportCount: 15,
        verifiedCount: 12,
        lastReportDaysAgo: 1,
      ),
      CoverageCell(
        x: 1205,
        y: 890,
        zoom: 14,
        reportCount: 8,
        verifiedCount: 7,
        lastReportDaysAgo: 3,
      ),
    ];
  }

  @override
  Future<ResolutionMedia> fetchResolution(String reportId) async {
    await Future.delayed(_simulatedLatency);
    final r = _resolutions[reportId];
    if (r == null) {
      return ResolutionMedia(
        reportId: reportId,
        afterPhotoUrls: const [],
        contractorNote: 'Resolution in progress',
        resolvedAtUtc: DateTime.now().toUtc(),
      );
    }
    return r;
  }

  @override
  Future<CivicScore> fetchCivicScore(String userId) async {
    await Future.delayed(_simulatedLatency);
    return const CivicScore(
      total: 340,
      reportsSubmitted: 12,
      reportsVerified: 10,
      resolutionsCompleted: 8,
      streakDays: 5,
      breakdown: [
        ScoreBreakdownDimension(
            name: 'Report Accuracy', points: 150, maxPoints: 200),
        ScoreBreakdownDimension(
            name: 'Peer Verifications', points: 100, maxPoints: 150),
        ScoreBreakdownDimension(
            name: 'Resolution Confirmation', points: 90, maxPoints: 100),
      ],
    );
  }

  @override
  Future<List<ReportResponse>> fetchMyReports(String userId) async {
    await Future.delayed(_simulatedLatency);
    return _tickets.values.map((t) {
      return ReportResponse(
        reportId: t.reportId,
        status: t.status,
        aiConfidence: '${(t.aiConfidence * 100).toStringAsFixed(0)}%',
        aiLabel: t.category.name,
        assignedContractorId: t.assignedContractorId,
        civicScoreDelta: 25,
        createdAtUtc: DateTime.now().toUtc().subtract(const Duration(days: 2)),
        slaClock: t.slaClock,
      );
    }).toList();
  }

  @override
  Future<List<ReportResponse>> syncPendingDrafts(
      List<ReportPayload> drafts) async {
    await Future.delayed(_simulatedLatency);
    final responses = <ReportResponse>[];
    for (final draft in drafts) {
      final res = await uploadInfrastructureReport(draft);
      responses.add(res);
    }
    return responses;
  }

  void _updateTicketStatus(String reportId, DefectStatus status) {
    final t = _tickets[reportId];
    if (t != null) {
      _tickets[reportId] = TicketSummary(
        reportId: t.reportId,
        status: status,
        category: t.category,
        severity: t.severity,
        capture: t.capture,
        zone: t.zone,
        thumbnailUrl: t.thumbnailUrl,
        watermarkVerified: t.watermarkVerified,
        aiConfidence: t.aiConfidence,
        daysInStatus: 0,
        slaClock: t.slaClock,
        assignedContractorId: t.assignedContractorId,
      );
    }

    final d = _defects[reportId];
    if (d != null) {
      _defects[reportId] = NearbyDefect(
        reportId: d.reportId,
        status: status,
        category: d.category,
        latitude: d.latitude,
        longitude: d.longitude,
        contractorId: d.contractorId,
        thumbnailUrl: d.thumbnailUrl,
        watermarkVerified: d.watermarkVerified,
      );
    }
  }
}

class _DefectSeed {
  final String id;
  final ReportCategory category;
  final ReportSeverity severity;
  final DefectStatus status;
  final double lat;
  final double lng;
  final String? contractorId;
  final bool watermarkVerified;
  final double aiConfidence;
  final String zone;
  final String thumb;

  _DefectSeed({
    required this.id,
    required this.category,
    required this.severity,
    required this.status,
    required this.lat,
    required this.lng,
    this.contractorId,
    required this.watermarkVerified,
    required this.aiConfidence,
    required this.zone,
    required this.thumb,
  });
}
