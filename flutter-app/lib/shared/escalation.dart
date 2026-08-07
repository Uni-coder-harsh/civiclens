class SlaClock {
  final String stage;
  final DateTime deadlineUtc;
  final int daysRemaining;
  final String norm;

  const SlaClock({
    required this.stage,
    required this.deadlineUtc,
    required this.daysRemaining,
    required this.norm,
  });

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'deadline_utc': deadlineUtc.toUtc().toIso8601String(),
        'days_remaining': daysRemaining,
        'norm': norm,
      };

  factory SlaClock.fromJson(Map<String, dynamic> json) => SlaClock(
        stage: json['stage'] as String,
        deadlineUtc: DateTime.parse(json['deadline_utc'] as String),
        daysRemaining: json['days_remaining'] as int,
        norm: json['norm'] as String,
      );
}

class EscalationEvent {
  final String reportId;
  final String fromStage;
  final String toStage;
  final String reason;
  final DateTime atUtc;

  const EscalationEvent({
    required this.reportId,
    required this.fromStage,
    required this.toStage,
    required this.reason,
    required this.atUtc,
  });

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'from_stage': fromStage,
        'to_stage': toStage,
        'reason': reason,
        'at_utc': atUtc.toUtc().toIso8601String(),
      };

  factory EscalationEvent.fromJson(Map<String, dynamic> json) =>
      EscalationEvent(
        reportId: json['report_id'] as String,
        fromStage: json['from_stage'] as String,
        toStage: json['to_stage'] as String,
        reason: json['reason'] as String,
        atUtc: DateTime.parse(json['at_utc'] as String),
      );
}
