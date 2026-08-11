import 'escalation.dart';

enum ReportCategory {
  pothole,
  roadCrack,
  bridgeDeck,
  bridgePier,
  bridgeCrack,
  guardrail,
  manhole,
  other,
}

enum ReportSeverity {
  low,
  medium,
  high,
  critical,
}

enum DefectStatus {
  submitted,
  underReview,
  aiVerified,
  assigned,
  inProgress,
  awaitAcceptance,
  resolved,
  rejected,
  reopened,
  closed,
}

enum SyncState {
  pending,
  uploading,
  synced,
  failed,
}

enum ImageQualityGate {
  ok,
  blurry,
  tooDark,
  overexposed,
  noSubject,
}

class GeoCapture {
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double accuracyMeters;
  final double bearingDegrees;
  final double speedMps;
  final DateTime capturedAtUtc;

  const GeoCapture({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.accuracyMeters,
    required this.bearingDegrees,
    required this.speedMps,
    required this.capturedAtUtc,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'altitude_m': altitudeMeters,
        'accuracy_m': accuracyMeters,
        'bearing_deg': bearingDegrees,
        'speed_mps': speedMps,
        'captured_at': capturedAtUtc.toUtc().toIso8601String(),
      };

  factory GeoCapture.fromJson(Map<String, dynamic> json) => GeoCapture(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        altitudeMeters: (json['altitude_m'] as num).toDouble(),
        accuracyMeters: (json['accuracy_m'] as num).toDouble(),
        bearingDegrees: (json['bearing_deg'] as num).toDouble(),
        speedMps: (json['speed_mps'] as num).toDouble(),
        capturedAtUtc: DateTime.parse(json['captured_at'] as String),
      );
}

class WatermarkPayload {
  final String reportId;
  final DateTime capturedAtUtc;
  final GeoCapture capture;
  final String appVersion;
  final String deviceModel;
  final String osVersion;

  const WatermarkPayload({
    required this.reportId,
    required this.capturedAtUtc,
    required this.capture,
    required this.appVersion,
    required this.deviceModel,
    required this.osVersion,
  });

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'captured_at': capturedAtUtc.toUtc().toIso8601String(),
        'capture': capture.toJson(),
        'app_version': appVersion,
        'device_model': deviceModel,
        'os_version': osVersion,
      };

  factory WatermarkPayload.fromJson(Map<String, dynamic> json) =>
      WatermarkPayload(
        reportId: json['report_id'] as String,
        capturedAtUtc: DateTime.parse(json['captured_at'] as String),
        capture: GeoCapture.fromJson(json['capture'] as Map<String, dynamic>),
        appVersion: json['app_version'] as String,
        deviceModel: json['device_model'] as String,
        osVersion: json['os_version'] as String,
      );
}

class ReportPayload {
  final String id;
  final String userId;
  final ReportCategory category;
  final ReportSeverity severity;
  final String description;
  final GeoCapture capture;
  final String imagePath;
  final String? thumbnailPath;
  final String? contractorId;
  final String? infrastructureId;
  final ImageQualityGate qualityGate;
  final bool isGuest;
  final String? sensorData;

  const ReportPayload({
    required this.id,
    required this.userId,
    required this.category,
    required this.severity,
    required this.description,
    required this.capture,
    required this.imagePath,
    this.thumbnailPath,
    this.contractorId,
    this.infrastructureId,
    required this.qualityGate,
    required this.isGuest,
    this.sensorData,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'category': category.name,
        'severity': severity.name,
        'description': description,
        'capture': capture.toJson(),
        'quality_gate': qualityGate.name,
        'is_guest': isGuest,
        'contractor_id': contractorId,
        'infrastructure_id': infrastructureId,
        'sensor_data': sensorData,
      };

  factory ReportPayload.fromJson(Map<String, dynamic> json) => ReportPayload(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        category: ReportCategory.values.byName(json['category'] as String),
        severity: ReportSeverity.values.byName(json['severity'] as String),
        description: json['description'] as String,
        capture: GeoCapture.fromJson(json['capture'] as Map<String, dynamic>),
        imagePath: json['image_path'] as String? ?? '',
        thumbnailPath: json['thumbnail_path'] as String?,
        contractorId: json['contractor_id'] as String?,
        infrastructureId: json['infrastructure_id'] as String?,
        qualityGate:
            ImageQualityGate.values.byName(json['quality_gate'] as String),
        isGuest: json['is_guest'] as bool,
        sensorData: json['sensor_data'] as String?,
      );
}

class ReportResponse {
  final String reportId;
  final DefectStatus status;
  final String? aiConfidence;
  final String? aiLabel;
  final String? assignedContractorId;
  final int civicScoreDelta;
  final DateTime createdAtUtc;
  final SlaClock? slaClock;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String? severity;
  final String? description;
  final String? imageUrl;
  final String? infrastructureId;
  final String? address;
  final String? passportNumber;
  final double? structuralHealthIndex;
  final String? contractorName;
  final String? contractorRole;
  final String? authority;
  final String? tenderId;
  final String? verificationStatus;
  final double? confidenceScore;
  final String? identityNote;

  const ReportResponse({
    required this.reportId,
    required this.status,
    this.aiConfidence,
    this.aiLabel,
    this.assignedContractorId,
    required this.civicScoreDelta,
    required this.createdAtUtc,
    this.slaClock,
    this.latitude,
    this.longitude,
    this.category,
    this.severity,
    this.description,
    this.imageUrl,
    this.infrastructureId,
    this.address,
    this.passportNumber,
    this.structuralHealthIndex,
    this.contractorName,
    this.contractorRole,
    this.authority,
    this.tenderId,
    this.verificationStatus,
    this.confidenceScore,
    this.identityNote,
  });

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'status': status.name,
        'ai_confidence': aiConfidence,
        'ai_label': aiLabel,
        'assigned_contractor_id': assignedContractorId,
        'civic_score_delta': civicScoreDelta,
        'created_at': createdAtUtc.toUtc().toIso8601String(),
        'sla_clock': slaClock?.toJson(),
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'severity': severity,
        'description': description,
        'image_url': imageUrl,
        'infrastructure_id': infrastructureId,
        'address': address,
        'passport_number': passportNumber,
        'structural_health_index': structuralHealthIndex,
        'contractor_name': contractorName,
        'contractor_role': contractorRole,
        'authority': authority,
        'tender_id': tenderId,
        'verification_status': verificationStatus,
        'confidence_score': confidenceScore,
        'identity_note': identityNote,
      };

  factory ReportResponse.fromJson(Map<String, dynamic> json) => ReportResponse(
        reportId: (json['report_id'] ?? json['id'] ?? '').toString(),
        status: DefectStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == (json['status'] as String? ?? '').toLowerCase(),
          orElse: () => DefectStatus.submitted,
        ),
        aiConfidence: json['ai_confidence']?.toString(),
        aiLabel: json['ai_label']?.toString(),
        assignedContractorId: json['assigned_contractor_id']?.toString(),
        civicScoreDelta: json['civic_score_delta'] is num
            ? (json['civic_score_delta'] as num).toInt()
            : int.tryParse(json['civic_score_delta']?.toString() ?? '') ?? 10,
        createdAtUtc: json['created_at_utc'] != null || json['created_at'] != null
            ? DateTime.tryParse((json['created_at_utc'] ?? json['created_at']).toString())?.toUtc() ?? DateTime.now().toUtc()
            : DateTime.now().toUtc(),
        slaClock: json['sla_clock'] != null && json['sla_clock'] is Map<String, dynamic>
            ? SlaClock.fromJson(json['sla_clock'] as Map<String, dynamic>)
            : null,
        latitude: json['latitude'] is num
            ? (json['latitude'] as num).toDouble()
            : double.tryParse(json['latitude']?.toString() ?? ''),
        longitude: json['longitude'] is num
            ? (json['longitude'] as num).toDouble()
            : double.tryParse(json['longitude']?.toString() ?? ''),
        category: json['category']?.toString(),
        severity: json['severity']?.toString(),
        description: json['description']?.toString(),
        imageUrl: json['image_url']?.toString(),
        infrastructureId: json['infrastructure_id']?.toString(),
        address: json['address']?.toString(),
        passportNumber: json['passport_number']?.toString(),
        structuralHealthIndex: json['structural_health_index'] is num
            ? (json['structural_health_index'] as num).toDouble()
            : double.tryParse(json['structural_health_index']?.toString() ?? ''),
        contractorName: json['contractor_name']?.toString(),
        contractorRole: json['contractor_role']?.toString(),
        authority: json['authority']?.toString(),
        tenderId: json['tender_id']?.toString(),
        verificationStatus: json['verification_status']?.toString(),
        confidenceScore: json['confidence_score'] is num
            ? (json['confidence_score'] as num).toDouble()
            : double.tryParse(json['confidence_score']?.toString() ?? ''),
        identityNote: json['identity_note']?.toString(),
      );
}
