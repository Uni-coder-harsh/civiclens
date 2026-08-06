import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:image/image.dart' as img;
import '../../shared/report_payload.dart';

/// Parameters passed into the background isolate for quality evaluation.
class _QualityGateParams {
  final String imagePath;
  const _QualityGateParams(this.imagePath);
}

/// Entry point for the quality gate isolate computation.
/// Must be a top-level function — Isolate.run() requires this.
Future<ImageQualityGate> _evaluateInIsolate(_QualityGateParams params) async {
  final bytes = await File(params.imagePath).readAsBytes();
  final original = img.decodeImage(bytes);
  if (original == null) return ImageQualityGate.noSubject;

  // Downscale to 320×240 for fast DSP processing
  final small = img.copyResize(original, width: 320, height: 240);
  final grayscale = img.grayscale(small);

  // ── Blur Detection (Variance of Laplacian) ──────────────────────────────
  // Apply Laplacian-like edge score using neighbour pixel differences
  final width = grayscale.width;
  final height = grayscale.height;
  final values = <double>[];

  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final center = _getLuminance(grayscale, x, y);
      final top = _getLuminance(grayscale, x, y - 1);
      final bottom = _getLuminance(grayscale, x, y + 1);
      final left = _getLuminance(grayscale, x - 1, y);
      final right = _getLuminance(grayscale, x + 1, y);

      final laplacian =
          (4 * center - top - bottom - left - right).abs().toDouble();
      values.add(laplacian);
    }
  }

  double mean = 0;
  for (final v in values) {
    mean += v;
  }
  mean /= values.length;

  double variance = 0;
  for (final v in values) {
    variance += pow(v - mean, 2);
  }
  variance /= values.length;

  if (variance < 80.0) return ImageQualityGate.blurry;

  // ── Exposure Detection (Mean Luminance) ─────────────────────────────────
  double totalLuminance = 0;
  int pixelCount = 0;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      totalLuminance += _getLuminance(grayscale, x, y);
      pixelCount++;
    }
  }

  final meanLuminance = totalLuminance / pixelCount;

  if (meanLuminance < 40) return ImageQualityGate.tooDark;
  if (meanLuminance > 220) return ImageQualityGate.overexposed;

  return ImageQualityGate.ok;
}

double _getLuminance(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  // Use red channel from grayscale image (r == g == b for grayscale)
  return pixel.r.toDouble();
}

/// On-device image quality precheck — blur and exposure DSP via a background isolate.
///
/// Ensures the UI thread remains responsive at 60fps during heavy computation.
class QualityGate {
  /// Evaluates image quality in a background Isolate.
  ///
  /// Returns an [ImageQualityGate] value:
  /// - [ImageQualityGate.ok] — passed
  /// - [ImageQualityGate.blurry] — variance-of-Laplacian score < 80
  /// - [ImageQualityGate.tooDark] — mean luminance < 40
  /// - [ImageQualityGate.overexposed] — mean luminance > 220
  /// - [ImageQualityGate.noSubject] — image could not be decoded
  Future<ImageQualityGate> evaluate(String imagePath) async {
    return Isolate.run(() => _evaluateInIsolate(_QualityGateParams(imagePath)));
  }
}
