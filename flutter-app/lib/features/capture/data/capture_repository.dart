import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/geo/geo_capture_service.dart';
import '../../../core/imaging/quality_gate.dart';
import '../../../core/imaging/watermarker.dart';
import '../../../shared/report_payload.dart';

/// Composite result from the capture pipeline.
class CaptureResult {
  final String watermarkedPath;
  final GeoCapture geoCapture;
  final WatermarkPayload watermarkPayload;
  final ImageQualityGate qualityGate;

  const CaptureResult({
    required this.watermarkedPath,
    required this.geoCapture,
    required this.watermarkPayload,
    required this.qualityGate,
  });
}

/// Exception thrown when the quality gate fails.
class QualityGateException implements Exception {
  final ImageQualityGate verdict;
  const QualityGateException(this.verdict);

  @override
  String toString() => 'QualityGateException: ${verdict.name}';
}

/// Exception thrown when permissions are missing.
class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException(
      [this.message = 'Capture permissions denied']);

  @override
  String toString() => 'PermissionDeniedException: $message';
}

/// Central orchestration pipeline for the capture flow.
///
/// Pipeline stages per §7.3:
///   1. Verify permissions
///   2. Acquire GPS fix
///   3. Quality gate check
///   4. Watermark + EXIF write
///   5. Stop GPS stream
///   6. Return [CaptureResult]
class CaptureRepository {
  final PermissionService _permissionService;
  final GeoCaptureService _geoCaptureService;
  final QualityGate _qualityGate;
  final Watermarker _watermarker;

  CaptureRepository({
    PermissionService? permissionService,
    GeoCaptureService? geoCaptureService,
    QualityGate? qualityGate,
    Watermarker? watermarker,
  })  : _permissionService = permissionService ?? PermissionService(),
        _geoCaptureService = geoCaptureService ?? GeoCaptureService(),
        _qualityGate = qualityGate ?? QualityGate(),
        _watermarker = watermarker ?? Watermarker();

  /// Runs the full capture processing pipeline.
  ///
  /// Throws [PermissionDeniedException] if permissions are missing.
  /// Throws [QualityGateException] if quality check fails.
  Future<CaptureResult> processCapture({
    required String rawImagePath,
    required String reportId,
    BuildContext? context,
  }) async {
    // Step 1: Verify permissions
    final hasPermissions = await _permissionService.hasCapturePermissions();
    if (!hasPermissions) {
      if (context != null && context.mounted) {
        final result = await _permissionService.requestCapturePermissions();
        // Re-check mounted after async gap
        if (result == PermissionResult.permanentlyDenied) {
          if (context.mounted) {
            await _permissionService.showPermissionDeniedDialog(context);
          }
        }
        if (result != PermissionResult.granted) {
          throw const PermissionDeniedException();
        }
      } else {
        throw const PermissionDeniedException();
      }
    }

    // Step 2: Acquire high-precision GPS fix
    final geoCapture = await _geoCaptureService.lockFix();

    // Step 3: Quality gate check (runs in isolate)
    final qualityVerdict = await _qualityGate.evaluate(rawImagePath);
    if (qualityVerdict != ImageQualityGate.ok) {
      // Stop GPS stream before throwing — prevent battery drain
      await _geoCaptureService.stopStream();
      throw QualityGateException(qualityVerdict);
    }

    // Step 4: Build watermark payload with package info
    final pkgInfo = await PackageInfo.fromPlatform();
    final watermarkPayload = WatermarkPayload(
      reportId: reportId,
      capturedAtUtc: geoCapture.capturedAtUtc,
      capture: geoCapture,
      appVersion: pkgInfo.version,
      deviceModel: 'Android Device',
      osVersion: 'Android',
    );

    // Step 5: Burn watermark onto pixels + EXIF UserComment write
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/watermarked_$reportId.jpg';

    await _watermarker.burn(
      inputPath: rawImagePath,
      outputPath: outputPath,
      payload: watermarkPayload,
    );

    // Step 6: Stop GPS stream — per §9.2 spec
    await _geoCaptureService.stopStream();

    return CaptureResult(
      watermarkedPath: outputPath,
      geoCapture: geoCapture,
      watermarkPayload: watermarkPayload,
      qualityGate: qualityVerdict,
    );
  }

  /// Clean up a temporary raw image file after processing.
  Future<void> discardRawImage(String rawImagePath) async {
    try {
      final file = File(rawImagePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Expose GPS accuracy badge stream to the UI layer.
  Stream<GpsAccuracyBadge> get accuracyBadgeStream =>
      _geoCaptureService.accuracyBadgeStream;

  /// Start streaming GPS badges for the camera overlay.
  void startGpsStream() => _geoCaptureService.startStream();

  /// Stop the GPS stream.
  Future<void> stopGpsStream() => _geoCaptureService.stopStream();
}
