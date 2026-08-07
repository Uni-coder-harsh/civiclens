import 'package:flutter/material.dart';
import '../../../core/geo/geo_capture_service.dart';

/// CustomPainter that draws the camera viewfinder overlay:
/// - Corner bracket framing markers
/// - Rule-of-thirds grid at 20% opacity
/// - Live GPS status badge
/// - Category hint text
class OverlayPainter extends CustomPainter {
  final GpsAccuracyBadge gpsBadge;
  final String categoryHint;

  const OverlayPainter({
    required this.gpsBadge,
    this.categoryHint = 'Center defect in frame • Ensure good lighting',
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawRuleOfThirdsGrid(canvas, size);
    _drawCornerBrackets(canvas, size);
    _drawHintText(canvas, size);
    _drawGpsBadge(canvas, size);
  }

  void _drawRuleOfThirdsGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.20)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Vertical lines at 1/3 and 2/3
    final vLine1 = size.width / 3;
    final vLine2 = size.width * 2 / 3;
    canvas.drawLine(Offset(vLine1, 0), Offset(vLine1, size.height), paint);
    canvas.drawLine(Offset(vLine2, 0), Offset(vLine2, size.height), paint);

    // Horizontal lines at 1/3 and 2/3
    final hLine1 = size.height / 3;
    final hLine2 = size.height * 2 / 3;
    canvas.drawLine(Offset(0, hLine1), Offset(size.width, hLine1), paint);
    canvas.drawLine(Offset(0, hLine2), Offset(size.width, hLine2), paint);
  }

  void _drawCornerBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.90)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const margin = 24.0;
    const bracketLen = 36.0;

    // Top-left
    canvas.drawLine(const Offset(margin, margin),
        const Offset(margin + bracketLen, margin), paint);
    canvas.drawLine(const Offset(margin, margin),
        const Offset(margin, margin + bracketLen), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - margin, margin),
        Offset(size.width - margin - bracketLen, margin), paint);
    canvas.drawLine(Offset(size.width - margin, margin),
        Offset(size.width - margin, margin + bracketLen), paint);

    // Bottom-left
    canvas.drawLine(Offset(margin, size.height - margin),
        Offset(margin + bracketLen, size.height - margin), paint);
    canvas.drawLine(Offset(margin, size.height - margin),
        Offset(margin, size.height - margin - bracketLen), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - margin, size.height - margin),
        Offset(size.width - margin - bracketLen, size.height - margin), paint);
    canvas.drawLine(Offset(size.width - margin, size.height - margin),
        Offset(size.width - margin, size.height - margin - bracketLen), paint);
  }

  void _drawHintText(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: categoryHint,
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withOpacity(0.85),
          fontWeight: FontWeight.w500,
          shadows: const [
            Shadow(blurRadius: 6, color: Colors.black54),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: size.width - 32);
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, 48),
    );
  }

  void _drawGpsBadge(Canvas canvas, Size size) {
    final isLocked = gpsBadge.state == GpsLockState.locked;
    final badgeColor =
        isLocked ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);

    const badgeWidth = 130.0;
    const badgeHeight = 28.0;
    const badgeX = 16.0;
    final badgeY = size.height - badgeHeight - 80.0;

    // Badge background
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.fill;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeX, badgeY, badgeWidth, badgeHeight),
      const Radius.circular(14),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Badge colored dot
    final dotPaint = Paint()
      ..color = badgeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(badgeX + 14, badgeY + badgeHeight / 2),
      5,
      dotPaint,
    );

    // Badge text
    final textPainter = TextPainter(
      text: TextSpan(
        text: gpsBadge.label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(badgeX + 24, badgeY + (badgeHeight - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) =>
      oldDelegate.gpsBadge.state != gpsBadge.state ||
      oldDelegate.gpsBadge.label != gpsBadge.label ||
      oldDelegate.categoryHint != categoryHint;
}

/// Widget wrapper that renders [OverlayPainter] over the camera preview.
class CameraOverlay extends StatelessWidget {
  final GpsAccuracyBadge gpsBadge;
  final String categoryHint;

  const CameraOverlay({
    super.key,
    required this.gpsBadge,
    this.categoryHint = 'Center defect in frame • Ensure good lighting',
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: OverlayPainter(
        gpsBadge: gpsBadge,
        categoryHint: categoryHint,
      ),
      child: const SizedBox.expand(),
    );
  }
}
