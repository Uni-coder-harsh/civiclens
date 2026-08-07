import 'escalation.dart';
import 'report_payload.dart';

enum UserRole { citizen, officer, contractor, admin }

class ForbiddenException implements Exception {
  final String action;
  final UserRole requiredRole;

  const ForbiddenException(this.action, this.requiredRole);

  @override
  String toString() => 'ForbiddenException: $action requires $requiredRole';
}

enum TicketAction {
  created,
  aiVerdict,
  verify,
  reject,
  assign,
  claim,
  inProgress,
  submitAfterPhoto,
  approve,
  close,
  reopen,
  attach,
  escalate,
  reply,
}

abstract class RolePermissions {
  static const Set<TicketAction> citizen = {
    TicketAction.created,
    TicketAction.attach,
    TicketAction.reopen,
  };

  static const Set<TicketAction> officer = {
    TicketAction.verify,
    TicketAction.assign,
    TicketAction.reject,
    TicketAction.approve,
    TicketAction.escalate,
  };

  static const Set<TicketAction> contractor = {
    TicketAction.claim,
    TicketAction.submitAfterPhoto,
    TicketAction.reply,
  };

  static const Set<TicketAction> admin = {
    ...officer,
    TicketAction.close,
  };
}

class ReportEvent {
  final String eventId;
  final String reportId;
  final DefectStatus fromStatus;
  final DefectStatus toStatus;
  final TicketAction action;
  final UserRole actorRole;
  final String actorId;
  final String actorLabel;
  final GeoCapture? location;
  final bool verifiedFromSite;
  final String? note;
  final DateTime atUtc;

  const ReportEvent({
    required this.eventId,
    required this.reportId,
    required this.fromStatus,
    required this.toStatus,
    required this.action,
    required this.actorRole,
    required this.actorId,
    required this.actorLabel,
    this.location,
    required this.verifiedFromSite,
    this.note,
    required this.atUtc,
  });

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'report_id': reportId,
        'from_status': fromStatus.name,
        'to_status': toStatus.name,
        'action': action.name,
        'actor_role': actorRole.name,
        'actor_id': actorId,
        'actor_label': actorLabel,
        'verified_from_site': verifiedFromSite,
        'location': location?.toJson(),
        'note': note,
        'at_utc': atUtc.toUtc().toIso8601String(),
      };

  factory ReportEvent.fromJson(Map<String, dynamic> json) => ReportEvent(
        eventId: json['event_id'] as String,
        reportId: json['report_id'] as String,
        fromStatus: DefectStatus.values.byName(json['from_status'] as String),
        toStatus: DefectStatus.values.byName(json['to_status'] as String),
        action: TicketAction.values.byName(json['action'] as String),
        actorRole: UserRole.values.byName(json['actor_role'] as String),
        actorId: json['actor_id'] as String,
        actorLabel: json['actor_label'] as String,
        verifiedFromSite: json['verified_from_site'] as bool? ?? false,
        location: json['location'] != null
            ? GeoCapture.fromJson(json['location'] as Map<String, dynamic>)
            : null,
        note: json['note'] as String?,
        atUtc: DateTime.parse(json['at_utc'] as String),
      );
}

class TicketSummary {
  final String reportId;
  final DefectStatus status;
  final ReportCategory category;
  final ReportSeverity severity;
  final GeoCapture capture;
  final String zone;
  final String thumbnailUrl;
  final bool watermarkVerified;
  final double aiConfidence;
  final int daysInStatus;
  final SlaClock? slaClock;
  final String? assignedContractorId;

  const TicketSummary({
    required this.reportId,
    required this.status,
    required this.category,
    required this.severity,
    required this.capture,
    required this.zone,
    required this.thumbnailUrl,
    required this.watermarkVerified,
    required this.aiConfidence,
    required this.daysInStatus,
    this.slaClock,
    this.assignedContractorId,
  });

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'status': status.name,
        'category': category.name,
        'severity': severity.name,
        'capture': capture.toJson(),
        'zone': zone,
        'thumbnail_url': thumbnailUrl,
        'watermark_verified': watermarkVerified,
        'ai_confidence': aiConfidence,
        'days_in_status': daysInStatus,
        'sla_clock': slaClock?.toJson(),
        'assigned_contractor_id': assignedContractorId,
      };

  factory TicketSummary.fromJson(Map<String, dynamic> json) => TicketSummary(
        reportId: json['report_id'] as String,
        status: DefectStatus.values.byName(json['status'] as String),
        category: ReportCategory.values.byName(json['category'] as String),
        severity: ReportSeverity.values.byName(json['severity'] as String),
        capture: GeoCapture.fromJson(json['capture'] as Map<String, dynamic>),
        zone: json['zone'] as String,
        thumbnailUrl: json['thumbnail_url'] as String? ?? '',
        watermarkVerified: json['watermark_verified'] as bool? ?? false,
        aiConfidence: (json['ai_confidence'] as num).toDouble(),
        daysInStatus: json['days_in_status'] as int,
        slaClock: json['sla_clock'] != null
            ? SlaClock.fromJson(json['sla_clock'] as Map<String, dynamic>)
            : null,
        assignedContractorId: json['assigned_contractor_id'] as String?,
      );
}

class ContractorReply {
  final String replyId;
  final String contractorId;
  final String reportId;
  final String body;
  final bool isPublic;
  final DateTime atUtc;

  const ContractorReply({
    required this.replyId,
    required this.contractorId,
    required this.reportId,
    required this.body,
    required this.isPublic,
    required this.atUtc,
  });

  Map<String, dynamic> toJson() => {
        'reply_id': replyId,
        'contractor_id': contractorId,
        'report_id': reportId,
        'body': body,
        'is_public': isPublic,
        'at_utc': atUtc.toUtc().toIso8601String(),
      };

  factory ContractorReply.fromJson(Map<String, dynamic> json) =>
      ContractorReply(
        replyId: json['reply_id'] as String,
        contractorId: json['contractor_id'] as String,
        reportId: json['report_id'] as String,
        body: json['body'] as String,
        isPublic: json['is_public'] as bool? ?? true,
        atUtc: DateTime.parse(json['at_utc'] as String),
      );
}

class WitnessConfirmation {
  final String reportId;
  final String witnessUserId;
  final GeoCapture capture;
  final String? afterPhotoPath;
  final DateTime atUtc;

  const WitnessConfirmation({
    required this.reportId,
    required this.witnessUserId,
    required this.capture,
    this.afterPhotoPath,
    required this.atUtc,
  });

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'witness_user_id': witnessUserId,
        'capture': capture.toJson(),
        'after_photo_path': afterPhotoPath,
        'at_utc': atUtc.toUtc().toIso8601String(),
      };

  factory WitnessConfirmation.fromJson(Map<String, dynamic> json) =>
      WitnessConfirmation(
        reportId: json['report_id'] as String,
        witnessUserId: json['witness_user_id'] as String,
        capture: GeoCapture.fromJson(json['capture'] as Map<String, dynamic>),
        afterPhotoPath: json['after_photo_path'] as String?,
        atUtc: DateTime.parse(json['at_utc'] as String),
      );
}

class ResolutionMedia {
  final String reportId;
  final List<String> afterPhotoUrls;
  final String contractorNote;
  final DateTime resolvedAtUtc;
  final String? repairedByContractorId;

  const ResolutionMedia({
    required this.reportId,
    required this.afterPhotoUrls,
    required this.contractorNote,
    required this.resolvedAtUtc,
    this.repairedByContractorId,
  });

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'after_photo_urls': afterPhotoUrls,
        'contractor_note': contractorNote,
        'resolved_at_utc': resolvedAtUtc.toUtc().toIso8601String(),
        'repaired_by_contractor_id': repairedByContractorId,
      };

  factory ResolutionMedia.fromJson(Map<String, dynamic> json) =>
      ResolutionMedia(
        reportId: json['report_id'] as String,
        afterPhotoUrls: (json['after_photo_urls'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        contractorNote: json['contractor_note'] as String,
        resolvedAtUtc: DateTime.parse(json['resolved_at_utc'] as String),
        repairedByContractorId: json['repaired_by_contractor_id'] as String?,
      );
}

class ScoreBreakdownDimension {
  final String name;
  final int points;
  final int maxPoints;

  const ScoreBreakdownDimension({
    required this.name,
    required this.points,
    required this.maxPoints,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'points': points,
        'max_points': maxPoints,
      };

  factory ScoreBreakdownDimension.fromJson(Map<String, dynamic> json) =>
      ScoreBreakdownDimension(
        name: json['name'] as String,
        points: json['points'] as int,
        maxPoints: json['max_points'] as int,
      );
}

class CivicScore {
  final int total;
  final int reportsSubmitted;
  final int reportsVerified;
  final int resolutionsCompleted;
  final int streakDays;
  final List<ScoreBreakdownDimension> breakdown;

  const CivicScore({
    required this.total,
    required this.reportsSubmitted,
    required this.reportsVerified,
    required this.resolutionsCompleted,
    required this.streakDays,
    required this.breakdown,
  });

  Map<String, dynamic> toJson() => {
        'total': total,
        'reports_submitted': reportsSubmitted,
        'reports_verified': reportsVerified,
        'resolutions_completed': resolutionsCompleted,
        'streak_days': streakDays,
        'breakdown': breakdown.map((b) => b.toJson()).toList(),
      };

  factory CivicScore.fromJson(Map<String, dynamic> json) => CivicScore(
        total: json['total'] as int,
        reportsSubmitted: json['reports_submitted'] as int,
        reportsVerified: json['reports_verified'] as int,
        resolutionsCompleted: json['resolutions_completed'] as int,
        streakDays: json['streak_days'] as int,
        breakdown: (json['breakdown'] as List<dynamic>)
            .map((b) =>
                ScoreBreakdownDimension.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}
