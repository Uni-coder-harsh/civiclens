import 'report_payload.dart';

/// Pin Color Legend Specification / Constants for DefectStatus and styling:
/// - submitted & underReview: Amber `#FFBF00`
/// - aiVerified: Orange `#FF7F00`
/// - assigned & inProgress: Blue `#007AFF`
/// - awaitAcceptance: Cyan `#00C7BE`
/// - resolved: Green `#34C759`
/// - rejected: Grey `#8E8E93`
/// - reopened: Red `#FF3B30`
/// - watermarkVerified: Adds inner checkmark badge ring.
/// - critical severity: Adds outer dark-red pulsing/static halo `#990000`.
abstract class PinStyleConstants {
  static const String colorAmber = '#FFBF00';
  static const String colorOrange = '#FF7F00';
  static const String colorBlue = '#007AFF';
  static const String colorCyan = '#00C7BE';
  static const String colorGreen = '#34C759';
  static const String colorGrey = '#8E8E93';
  static const String colorRed = '#FF3B30';
  static const String colorCriticalHalo = '#990000';
}

class NearbyDefect {
  final String reportId;
  final DefectStatus status;
  final ReportCategory category;
  final double latitude;
  final double longitude;
  final String? contractorId;
  final String thumbnailUrl;
  final bool watermarkVerified;
  final String? address;
  final String? aiSeverity;
  final String? aiLabel;
  final double? aiConfidence;
  final String? imageUrl;

  const NearbyDefect({
    required this.reportId,
    required this.status,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.contractorId,
    required this.thumbnailUrl,
    required this.watermarkVerified,
    this.address,
    this.aiSeverity,
    this.aiLabel,
    this.aiConfidence,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'status': status.name,
        'category': category.name,
        'latitude': latitude,
        'longitude': longitude,
        'contractor_id': contractorId,
        'thumbnail_url': thumbnailUrl,
        'watermark_verified': watermarkVerified,
        'address': address,
        'ai_severity': aiSeverity,
        'ai_label': aiLabel,
        'ai_confidence': aiConfidence,
        'image_url': imageUrl,
      };

  factory NearbyDefect.fromJson(Map<String, dynamic> json) => NearbyDefect(
        reportId: json['report_id'] as String,
        status: DefectStatus.values.byName(json['status'] as String),
        category: ReportCategory.values.byName(json['category'] as String),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        contractorId: json['contractor_id'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String? ?? '',
        watermarkVerified: json['watermark_verified'] as bool? ?? false,
        address: json['address'] as String?,
        aiSeverity: json['ai_severity'] as String?,
        aiLabel: json['ai_label'] as String?,
        aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
        imageUrl: json['image_url'] as String?,
      );
}

class DuplicateMatch {
  final String existingReportId;
  final double distanceMeters;
  final DefectStatus status;
  final String? contractorId;
  final String thumbnailUrl;

  const DuplicateMatch({
    required this.existingReportId,
    required this.distanceMeters,
    required this.status,
    this.contractorId,
    required this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
        'existing_report_id': existingReportId,
        'distance_m': distanceMeters,
        'status': status.name,
        'contractor_id': contractorId,
        'thumbnail_url': thumbnailUrl,
      };

  factory DuplicateMatch.fromJson(Map<String, dynamic> json) => DuplicateMatch(
        existingReportId: json['existing_report_id'] as String,
        distanceMeters: (json['distance_m'] as num).toDouble(),
        status: DefectStatus.values.byName(json['status'] as String),
        contractorId: json['contractor_id'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      );
}

class CoverageCell {
  final int x;
  final int y;
  final int zoom;
  final int reportCount;
  final int verifiedCount;
  final int lastReportDaysAgo;

  const CoverageCell({
    required this.x,
    required this.y,
    required this.zoom,
    required this.reportCount,
    required this.verifiedCount,
    required this.lastReportDaysAgo,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'zoom': zoom,
        'report_count': reportCount,
        'verified_count': verifiedCount,
        'last_report_days_ago': lastReportDaysAgo,
      };

  factory CoverageCell.fromJson(Map<String, dynamic> json) => CoverageCell(
        x: json['x'] as int,
        y: json['y'] as int,
        zoom: json['zoom'] as int,
        reportCount: json['report_count'] as int,
        verifiedCount: json['verified_count'] as int,
        lastReportDaysAgo: json['last_report_days_ago'] as int,
      );
}
