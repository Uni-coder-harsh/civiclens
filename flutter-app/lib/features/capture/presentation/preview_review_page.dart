import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/capture_repository.dart';
import '../../../shared/report_payload.dart';

/// Photo review and metadata verification screen.
///
/// Displays the watermarked image with:
/// - GPS coordinates
/// - Capture timestamp
/// - Device info
/// - Quality gate status
///
/// Action buttons: Retake (discard) or Continue to /report/form.
class PreviewReviewPage extends StatelessWidget {
  final CaptureResult captureResult;

  const PreviewReviewPage({super.key, required this.captureResult});

  @override
  Widget build(BuildContext context) {
    final geo = captureResult.geoCapture;
    final payload = captureResult.watermarkPayload;
    final qualityGate = captureResult.qualityGate;

    final lat = geo.latitude.toStringAsFixed(4);
    final lng = geo.longitude.toStringAsFixed(4);
    final coordLabel = '$lat° N,  $lng° E';
    final timestampLabel = _formatTimestamp(geo.capturedAtUtc);
    final deviceLabel = '${payload.deviceModel} · Android';
    final qualityLabel = qualityGate == ImageQualityGate.ok
        ? 'Quality Gate: Passed ✓'
        : 'Quality Gate: ${qualityGate.name}';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface, size: 24),
        ),
        title: Text(
          'Review Photo',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Watermarked image (expandable)
          Expanded(
            child: InteractiveViewer(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: Image.file(
                  File(captureResult.watermarkedPath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined,
                            color: Color(0xFF475569), size: 64),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load image\n${captureResult.watermarkedPath}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Metadata chip strip + action buttons
          _buildBottomPanel(
            context,
            coordLabel: coordLabel,
            timestampLabel: timestampLabel,
            deviceLabel: deviceLabel,
            qualityLabel: qualityLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(
    BuildContext context, {
    required String coordLabel,
    required String timestampLabel,
    required String deviceLabel,
    required String qualityLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Capture Metadata',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),

          // Metadata chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.location_on_rounded,
                label: coordLabel,
                color: Theme.of(context).colorScheme.primary,
              ),
              _MetaChip(
                icon: Icons.access_time_rounded,
                label: timestampLabel,
                color: const Color(0xFF0D9488),
              ),
              _MetaChip(
                icon: Icons.smartphone_rounded,
                label: deviceLabel,
                color: const Color(0xFF7C3AED),
              ),
              _MetaChip(
                icon: Icons.verified_rounded,
                label: qualityLabel,
                color: captureResult.qualityGate == ImageQualityGate.ok
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text(
                    'Retake',
                    style: TextStyle(
                        fontFamily: 'Inter', fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/report/form', extra: captureResult);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Looks good → Continue',
                    style: TextStyle(
                        fontFamily: 'Inter', fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}:${_pad(local.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
