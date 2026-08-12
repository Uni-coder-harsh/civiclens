import 'package:flutter/material.dart';
import '../../../shared/report_payload.dart';

// ── Color palette per defect class ───────────────────────────────────────────
const _classColors = {
  'D00_Longitudinal_Crack': Color(0xFFFF6B35),  // Orange
  'D10_Transverse_Crack':   Color(0xFFFFD93D),  // Yellow
  'D20_Alligator_Crack':    Color(0xFFFF3B3B),  // Red
  'D30_Other_Corruption':   Color(0xFF6BCB77),  // Green
  'D40_Pothole':            Color(0xFFE040FB),  // Purple
};

Color _colorForClass(String className) =>
    _classColors[className] ?? const Color(0xFF00E5FF);

// ── Painter ───────────────────────────────────────────────────────────────────

class _DetectionPainter extends CustomPainter {
  final AiDetectionResult analysis;
  final Size imageDisplaySize;

  const _DetectionPainter({
    required this.analysis,
    required this.imageDisplaySize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!analysis.hasDetections) return;

    final scaleX = imageDisplaySize.width / analysis.imageWidth;
    final scaleY = imageDisplaySize.height / analysis.imageHeight;

    for (final det in analysis.detections) {
      final bb = det.boundingBox;
      final color = _colorForClass(det.className);

      final left   = bb.x1 * scaleX;
      final top    = bb.y1 * scaleY;
      final right  = bb.x2 * scaleX;
      final bottom = bb.y2 * scaleY;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      // Filled semi-transparent background
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withOpacity(0.12)
          ..style = PaintingStyle.fill,
      );

      // Corner bracket strokes instead of a full box (cleaner look)
      final borderPaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final cornerLen = (rect.width * 0.22).clamp(10.0, 28.0);

      // Top-left
      canvas.drawLine(rect.topLeft, rect.topLeft.translate(cornerLen, 0), borderPaint);
      canvas.drawLine(rect.topLeft, rect.topLeft.translate(0, cornerLen), borderPaint);
      // Top-right
      canvas.drawLine(rect.topRight, rect.topRight.translate(-cornerLen, 0), borderPaint);
      canvas.drawLine(rect.topRight, rect.topRight.translate(0, cornerLen), borderPaint);
      // Bottom-left
      canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(cornerLen, 0), borderPaint);
      canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(0, -cornerLen), borderPaint);
      // Bottom-right
      canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(-cornerLen, 0), borderPaint);
      canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(0, -cornerLen), borderPaint);

      // Label pill
      _drawLabel(canvas, rect, det, color);
    }
  }

  void _drawLabel(Canvas canvas, Rect rect, AiDetectionItem det, Color color) {
    final label = '${det.displayName} ${(det.confidence * 100).toStringAsFixed(0)}%';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const pillPadH = 7.0;
    const pillPadV = 4.0;
    final pillW = textPainter.width + pillPadH * 2;
    final pillH = textPainter.height + pillPadV * 2;

    // Keep pill inside canvas
    final pillX = rect.left.clamp(0.0, double.infinity);
    final pillY = (rect.top - pillH - 4).clamp(0.0, double.infinity);
    final pillRect = Rect.fromLTWH(pillX, pillY, pillW, pillH);

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect.inflate(1), const Radius.circular(5)),
      Paint()..color = Colors.black38,
    );
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(4)),
      Paint()..color = color,
    );
    // Text
    textPainter.paint(canvas, Offset(pillRect.left + pillPadH, pillRect.top + pillPadV));
  }

  @override
  bool shouldRepaint(_DetectionPainter old) =>
      old.analysis != analysis || old.imageDisplaySize != imageDisplaySize;
}

// ── Public Widget ─────────────────────────────────────────────────────────────

/// Renders an image with ONNX detection bounding boxes drawn on top.
/// Flutter draws the boxes client-side from bbox coordinates — no annotated image needed.
class DetectionOverlay extends StatelessWidget {
  final String imageUrl;
  final AiDetectionResult? analysis;

  const DetectionOverlay({
    super.key,
    required this.imageUrl,
    this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Base image
            Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A1A2E),
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 48),
                ),
              ),
            ),

            // Detection overlay
            if (analysis != null && analysis!.hasDetections)
              RepaintBoundary(
                child: CustomPaint(
                  painter: _DetectionPainter(
                    analysis: analysis!,
                    imageDisplaySize: displaySize,
                  ),
                  size: displaySize,
                ),
              ),

            // "No detection" hint
            if (analysis != null && !analysis!.hasDetections)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'No defects detected by AI',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Severity Badge ────────────────────────────────────────────────────────────

class AiSeverityBadge extends StatelessWidget {
  final AiSeverity severity;

  const AiSeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (severity.severityLabel) {
      'critical' => (const Color(0xFFFF3B3B), Icons.warning_rounded),
      'high'     => (const Color(0xFFFF6B35), Icons.error_outline_rounded),
      'medium'   => (const Color(0xFFFFD93D), Icons.info_outline_rounded),
      _          => (const Color(0xFF6BCB77), Icons.check_circle_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            severity.severityLabel.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${severity.severityScore.toStringAsFixed(0)}/100',
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Detection List Card ───────────────────────────────────────────────────────

class AiDetectionList extends StatelessWidget {
  final AiDetectionResult analysis;

  const AiDetectionList({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (!analysis.hasDetections) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_off_rounded, color: Colors.white30, size: 20),
            SizedBox(width: 12),
            Text(
              'No road defects detected in this image.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...analysis.detections.map((det) {
          final color = _colorForClass(det.className);
          final bb = det.boundingBox;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        det.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Area: ${bb.width}×${bb.height}px  •  '
                        '(${bb.x1},${bb.y1}) → (${bb.x2},${bb.y2})',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(det.confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
