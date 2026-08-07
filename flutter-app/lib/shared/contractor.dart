import 'report_payload.dart';

class ContractorSummary {
  final String contractorId;
  final String companyName;
  final double grade;
  final int activeDefects;
  final int completedProjects;
  final int streakMonths;
  final bool kycVerified;

  const ContractorSummary({
    required this.contractorId,
    required this.companyName,
    required this.grade,
    required this.activeDefects,
    required this.completedProjects,
    required this.streakMonths,
    required this.kycVerified,
  });

  Map<String, dynamic> toJson() => {
        'contractor_id': contractorId,
        'company_name': companyName,
        'grade': grade,
        'active_defects': activeDefects,
        'completed_projects': completedProjects,
        'streak_months': streakMonths,
        'kyc_verified': kycVerified,
      };

  factory ContractorSummary.fromJson(Map<String, dynamic> json) =>
      ContractorSummary(
        contractorId: json['contractor_id'] as String,
        companyName: json['company_name'] as String,
        grade: (json['grade'] as num).toDouble(),
        activeDefects: json['active_defects'] as int,
        completedProjects: json['completed_projects'] as int,
        streakMonths: json['streak_months'] as int,
        kycVerified: json['kyc_verified'] as bool? ?? false,
      );
}

class ContractorProject {
  final String projectId;
  final String name;
  final String scope;
  final String zone;
  final DateTime startedAtUtc;
  final DateTime? completedAtUtc;
  final double rating;
  final int defectsAttributed;

  const ContractorProject({
    required this.projectId,
    required this.name,
    required this.scope,
    required this.zone,
    required this.startedAtUtc,
    this.completedAtUtc,
    required this.rating,
    required this.defectsAttributed,
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'name': name,
        'scope': scope,
        'zone': zone,
        'started_at_utc': startedAtUtc.toUtc().toIso8601String(),
        'completed_at_utc': completedAtUtc?.toUtc().toIso8601String(),
        'rating': rating,
        'defects_attributed': defectsAttributed,
      };

  factory ContractorProject.fromJson(Map<String, dynamic> json) =>
      ContractorProject(
        projectId: json['project_id'] as String,
        name: json['name'] as String,
        scope: json['scope'] as String,
        zone: json['zone'] as String,
        startedAtUtc: DateTime.parse(json['started_at_utc'] as String),
        completedAtUtc: json['completed_at_utc'] != null
            ? DateTime.parse(json['completed_at_utc'] as String)
            : null,
        rating: (json['rating'] as num).toDouble(),
        defectsAttributed: json['defects_attributed'] as int,
      );
}

class ContractorDefectRef {
  final String reportId;
  final ReportCategory category;
  final DefectStatus status;
  final DateTime reportedAtUtc;
  final double severityWeight;

  const ContractorDefectRef({
    required this.reportId,
    required this.category,
    required this.status,
    required this.reportedAtUtc,
    required this.severityWeight,
  });

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'category': category.name,
        'status': status.name,
        'reported_at_utc': reportedAtUtc.toUtc().toIso8601String(),
        'severity_weight': severityWeight,
      };

  factory ContractorDefectRef.fromJson(Map<String, dynamic> json) =>
      ContractorDefectRef(
        reportId: json['report_id'] as String,
        category: ReportCategory.values.byName(json['category'] as String),
        status: DefectStatus.values.byName(json['status'] as String),
        reportedAtUtc: DateTime.parse(json['reported_at_utc'] as String),
        severityWeight: (json['severity_weight'] as num).toDouble(),
      );
}

class ScoreBreakdown {
  final double quality;
  final double timeliness;
  final double safety;
  final double compliance;

  const ScoreBreakdown({
    required this.quality,
    required this.timeliness,
    required this.safety,
    required this.compliance,
  });

  Map<String, dynamic> toJson() => {
        'quality': quality,
        'timeliness': timeliness,
        'safety': safety,
        'compliance': compliance,
      };

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) => ScoreBreakdown(
        quality: (json['quality'] as num).toDouble(),
        timeliness: (json['timeliness'] as num).toDouble(),
        safety: (json['safety'] as num).toDouble(),
        compliance: (json['compliance'] as num).toDouble(),
      );
}

class WarrantyState {
  final String defectId;
  final DateTime warrantyExpiresAtUtc;
  final int recurrences;
  final double scorePenaltyApplied;

  const WarrantyState({
    required this.defectId,
    required this.warrantyExpiresAtUtc,
    required this.recurrences,
    required this.scorePenaltyApplied,
  });

  Map<String, dynamic> toJson() => {
        'defect_id': defectId,
        'warranty_expires_at_utc':
            warrantyExpiresAtUtc.toUtc().toIso8601String(),
        'recurrences': recurrences,
        'score_penalty_applied': scorePenaltyApplied,
      };

  factory WarrantyState.fromJson(Map<String, dynamic> json) => WarrantyState(
        defectId: json['defect_id'] as String,
        warrantyExpiresAtUtc:
            DateTime.parse(json['warranty_expires_at_utc'] as String),
        recurrences: json['recurrences'] as int,
        scorePenaltyApplied: (json['score_penalty_applied'] as num).toDouble(),
      );
}

class ContractorPassport {
  final ContractorSummary summary;
  final List<ContractorProject> projects;
  final List<ContractorDefectRef> defects;
  final ScoreBreakdown scoreBreakdown;
  final List<WarrantyState> warranties;

  const ContractorPassport({
    required this.summary,
    required this.projects,
    required this.defects,
    required this.scoreBreakdown,
    required this.warranties,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'projects': projects.map((p) => p.toJson()).toList(),
        'defects': defects.map((d) => d.toJson()).toList(),
        'score_breakdown': scoreBreakdown.toJson(),
        'warranties': warranties.map((w) => w.toJson()).toList(),
      };

  factory ContractorPassport.fromJson(Map<String, dynamic> json) =>
      ContractorPassport(
        summary:
            ContractorSummary.fromJson(json['summary'] as Map<String, dynamic>),
        projects: (json['projects'] as List<dynamic>)
            .map((p) => ContractorProject.fromJson(p as Map<String, dynamic>))
            .toList(),
        defects: (json['defects'] as List<dynamic>)
            .map((d) => ContractorDefectRef.fromJson(d as Map<String, dynamic>))
            .toList(),
        scoreBreakdown: ScoreBreakdown.fromJson(
            json['score_breakdown'] as Map<String, dynamic>),
        warranties: (json['warranties'] as List<dynamic>)
            .map((w) => WarrantyState.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}
