import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../../shared/defect.dart';
import '../../../shared/ticket.dart';

Future<Uint8List> buildShareCard(
    NearbyDefect defect, ResolutionMedia resolution) async {
  // Create a 1200x630 canvas
  final image = img.Image(width: 1200, height: 630);

  // Fill background
  img.fill(image, color: img.ColorRgb8(240, 240, 240));

  // Top Banner (Green with 'RESOLVED')
  img.fillRect(image,
      x1: 0, y1: 0, x2: 1200, y2: 80, color: img.ColorRgb8(34, 197, 94));
  img.drawString(
    image,
    'RESOLVED: ${defect.category.name.toUpperCase()}',
    font: img.arial48,
    x: 600,
    y: 16,
    color: img.ColorRgb8(255, 255, 255),
  );

  // Left Side: Before
  img.fillRect(image,
      x1: 50, y1: 120, x2: 575, y2: 500, color: img.ColorRgb8(200, 200, 200));
  img.drawString(
    image,
    'BEFORE',
    font: img.arial48,
    x: 312,
    y: 280,
    color: img.ColorRgb8(100, 100, 100),
  );

  // Right Side: After
  img.fillRect(image,
      x1: 625, y1: 120, x2: 1150, y2: 500, color: img.ColorRgb8(200, 200, 200));
  img.drawString(
    image,
    'AFTER',
    font: img.arial48,
    x: 887,
    y: 280,
    color: img.ColorRgb8(100, 100, 100),
  );

  // Contractor Name Overlay
  final contractorName = resolution.repairedByContractorId ?? 'Contractor';
  img.drawString(
    image,
    'Fixed by: $contractorName',
    font: img.arial24,
    x: 887,
    y: 460,
    color: img.ColorRgb8(50, 50, 50),
  );

  // Watermark Chip
  img.fillRect(image,
      x1: 60, y1: 130, x2: 300, y2: 170, color: img.ColorRgb8(0, 0, 0));
  img.drawString(
    image,
    'GPS & Time Verified',
    font: img.arial14,
    x: 180,
    y: 140,
    color: img.ColorRgb8(255, 255, 255),
  );

  // Bottom Branding Strip
  img.fillRect(image,
      x1: 0, y1: 530, x2: 1200, y2: 630, color: img.ColorRgb8(30, 41, 59));

  // Fixed in X days
  final days = resolution.resolvedAtUtc
      .difference(DateTime.now().subtract(const Duration(days: 3)))
      .inDays
      .abs();
  img.drawString(
    image,
    'Fixed in $days days',
    font: img.arial24,
    x: 100,
    y: 565,
    color: img.ColorRgb8(255, 255, 255),
  );

  // CivicLens Logo/Text
  img.drawString(
    image,
    'CivicLens',
    font: img.arial48,
    x: 600,
    y: 550,
    color: img.ColorRgb8(255, 255, 255),
  );

  // Civic Score bonus tag
  img.drawString(
    image,
    '+50 pts',
    font: img.arial24,
    x: 1000,
    y: 565,
    color: img.ColorRgb8(59, 130, 246), // Blue
  );

  return img.encodePng(image);
}
