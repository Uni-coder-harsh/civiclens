import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ShareSheet extends StatelessWidget {
  final Uint8List pngBytes;

  const ShareSheet({super.key, required this.pngBytes});

  static Future<void> show(BuildContext context, Uint8List bytes) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareSheet(pngBytes: bytes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Report Resolved!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this civic improvement with your community.',
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              pngBytes,
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // In a real app, use image_gallery_saver or similar.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to gallery (mock)')),
                    );
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final xFile =
                        XFile.fromData(pngBytes, mimeType: 'image/png');
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [xFile],
                        text: 'Check out this civic improvement on CivicLens!',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
