import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_providers.dart';
import '../data/chunked_uploader.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum DroneUploadPhase {
  idle,
  uploading,
  paused,
  done,
  error,
}

class _DroneUploadState {
  final DroneUploadPhase phase;
  final String? filePath;
  final String? fileName;
  final int totalBytes;
  final ChunkProgress? progress;
  final String? errorMessage;
  final String? remoteUrl;

  const _DroneUploadState({
    this.phase = DroneUploadPhase.idle,
    this.filePath,
    this.fileName,
    this.totalBytes = 0,
    this.progress,
    this.errorMessage,
    this.remoteUrl,
  });

  _DroneUploadState copyWith({
    DroneUploadPhase? phase,
    String? filePath,
    String? fileName,
    int? totalBytes,
    ChunkProgress? progress,
    String? errorMessage,
    String? remoteUrl,
  }) =>
      _DroneUploadState(
        phase: phase ?? this.phase,
        filePath: filePath ?? this.filePath,
        fileName: fileName ?? this.fileName,
        totalBytes: totalBytes ?? this.totalBytes,
        progress: progress ?? this.progress,
        errorMessage: errorMessage ?? this.errorMessage,
        remoteUrl: remoteUrl ?? this.remoteUrl,
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class _DroneUploadController extends StateNotifier<_DroneUploadState> {
  final Dio _dio;
  ChunkedUploader? _uploader;

  _DroneUploadController(this._dio) : super(const _DroneUploadState());

  Future<void> pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final filePath = picked.path;
    if (filePath == null) return;

    final file = File(filePath);
    final totalBytes = await file.length();

    state = state.copyWith(
      phase: DroneUploadPhase.uploading,
      filePath: filePath,
      fileName: picked.name,
      totalBytes: totalBytes,
      progress: null,
      errorMessage: null,
    );

    _uploader?.dispose();
    _uploader = ChunkedUploader(
      dio: _dio,
      uploadUrl: '${AppConfig.apiBaseUrl}/v1/drone/upload',
    );

    _uploader!.progress.listen((progress) {
      if (mounted) {
        state = state.copyWith(progress: progress);
      }
    });

    final uploadResult = await _uploader!.upload(filePath);

    if (!mounted) return;

    if (uploadResult.success) {
      state = state.copyWith(
        phase: DroneUploadPhase.done,
        remoteUrl: uploadResult.remoteUrl,
      );
    } else {
      state = state.copyWith(
        phase: DroneUploadPhase.error,
        errorMessage: uploadResult.errorMessage,
      );
    }
  }

  void pause() {
    _uploader?.pause();
    state = state.copyWith(phase: DroneUploadPhase.paused);
  }

  void resume() {
    _uploader?.resume();
    state = state.copyWith(phase: DroneUploadPhase.uploading);
  }

  void cancel() {
    _uploader?.cancel();
    state = const _DroneUploadState();
  }

  void reset() {
    _uploader?.cancel();
    _uploader?.dispose();
    state = const _DroneUploadState();
  }

  @override
  void dispose() {
    _uploader?.dispose();
    super.dispose();
  }
}

final _droneUploadControllerProvider =
    StateNotifierProvider.autoDispose<_DroneUploadController, _DroneUploadState>(
  (ref) => _DroneUploadController(ref.watch(dioProvider)),
);

// ── Page ──────────────────────────────────────────────────────────────────────

/// Route: `/drone-upload`
///
/// Allows drone operators to upload large video files in 5 MB chunks with
/// pause/resume, per-chunk SHA-256 verification, and live progress display.
class DroneUploadPage extends ConsumerWidget {
  const DroneUploadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_droneUploadControllerProvider);
    final controller = ref.read(_droneUploadControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Drone Footage Upload',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        actions: [
          if (state.phase != DroneUploadPhase.idle)
            TextButton(
              onPressed: controller.reset,
              child: const Text('Reset',
                  style: TextStyle(color: Color(0xFFEF4444))),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ─────────────────────────────────────────────
            _InfoBanner(),
            const SizedBox(height: 24),

            // ── File info ───────────────────────────────────────────────
            if (state.fileName != null) ...[
              _FileInfoCard(
                fileName: state.fileName!,
                totalBytes: state.totalBytes,
              ),
              const SizedBox(height: 20),
            ],

            // ── Progress ─────────────────────────────────────────────────
            if (state.phase == DroneUploadPhase.uploading ||
                state.phase == DroneUploadPhase.paused) ...[
              _ProgressCard(state: state),
              const SizedBox(height: 20),
            ],

            // ── Success ──────────────────────────────────────────────────
            if (state.phase == DroneUploadPhase.done) ...[
              _SuccessCard(remoteUrl: state.remoteUrl),
              const SizedBox(height: 20),
            ],

            // ── Error ────────────────────────────────────────────────────
            if (state.phase == DroneUploadPhase.error) ...[
              _ErrorCard(message: state.errorMessage ?? 'Upload failed'),
              const SizedBox(height: 20),
            ],

            const Spacer(),

            // ── Action buttons ───────────────────────────────────────────
            _ActionButtons(state: state, controller: controller),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF818CF8)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upload MP4 drone footage. Files are split into 5 MB chunks with SHA-256 verification. '
              'Resume if connection drops.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileInfoCard extends StatelessWidget {
  final String fileName;
  final int totalBytes;

  const _FileInfoCard({required this.fileName, required this.totalBytes});

  @override
  Widget build(BuildContext context) {
    final sizeStr = _formatBytes(totalBytes);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_rounded, color: Color(0xFF10B981), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sizeStr,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _ProgressCard extends StatelessWidget {
  final _DroneUploadState state;

  const _ProgressCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final isPaused = state.phase == DroneUploadPhase.paused;
    final fraction = progress?.fraction ?? 0.0;
    final pct = (fraction * 100).toStringAsFixed(1);
    final chunkInfo = progress != null
        ? 'Chunk ${progress.chunkIndex + 1} of ${progress.totalChunks}'
        : 'Starting...';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPaused ? 'Paused' : 'Uploading',
                style: TextStyle(
                  color: isPaused ? const Color(0xFFF59E0B) : const Color(0xFF818CF8),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation(
                isPaused ? const Color(0xFFF59E0B) : const Color(0xFF4F46E5),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            chunkInfo,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          if (progress?.lastChunkSha256 != null) ...[
            const SizedBox(height: 4),
            Text(
              'SHA256: ${progress!.lastChunkSha256!.substring(0, 16)}...',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontFamily: 'Courier',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final String? remoteUrl;

  const _SuccessCard({this.remoteUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 40),
          const SizedBox(height: 12),
          const Text(
            'Upload Complete',
            style: TextStyle(
              color: Color(0xFF10B981),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          if (remoteUrl != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              remoteUrl!,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontFamily: 'Courier',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontFamily: 'Inter',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final _DroneUploadState state;
  final _DroneUploadController controller;

  const _ActionButtons({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    return switch (state.phase) {
      DroneUploadPhase.idle => SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.pickAndUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text(
              'Select & Upload Footage',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter'),
            ),
          ),
        ),
      DroneUploadPhase.uploading => Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.pause,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pause',
                    style:
                        TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.cancel_rounded),
                label: const Text('Cancel',
                    style:
                        TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      DroneUploadPhase.paused => SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.resume,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume Upload',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter')),
          ),
        ),
      DroneUploadPhase.done || DroneUploadPhase.error => SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.reset,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Upload Another',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter')),
          ),
        ),
    };
  }
}
