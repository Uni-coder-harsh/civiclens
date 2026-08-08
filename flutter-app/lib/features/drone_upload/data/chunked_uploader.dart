import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// Progress update emitted during upload.
class ChunkProgress {
  final int chunkIndex;
  final int totalChunks;
  final int bytesSent;
  final int totalBytes;
  final String? lastChunkSha256;

  const ChunkProgress({
    required this.chunkIndex,
    required this.totalChunks,
    required this.bytesSent,
    required this.totalBytes,
    this.lastChunkSha256,
  });

  double get fraction => totalBytes > 0 ? bytesSent / totalBytes : 0.0;
}

/// Result of a completed upload.
class UploadResult {
  final bool success;
  final String? remoteUrl;
  final String? errorMessage;
  final int totalChunks;

  const UploadResult({
    required this.success,
    this.remoteUrl,
    this.errorMessage,
    required this.totalChunks,
  });
}

/// Uploads a large file in 5 MB chunks via Dio multipart.
///
/// • Each chunk includes a SHA-256 checksum for integrity verification.
/// • Upload can be paused/resumed using the [pause] and [resume] methods.
/// • Connectivity loss sets the upload into a paused state; callers should
///   listen to `connectivity_plus` and call [resume] on reconnect.
/// • If the server supports idempotent chunk offsets (via a resume key),
///   chunks already received are skipped on resume.
class ChunkedUploader {
  static const int _chunkSizeBytes = 5 * 1024 * 1024; // 5 MB

  final Dio _dio;
  final String uploadUrl;

  bool _paused = false;
  bool _cancelled = false;
  int _resumeFromChunk = 0;

  final _progressController = StreamController<ChunkProgress>.broadcast();

  /// Stream of progress updates — safe to listen in the UI.
  Stream<ChunkProgress> get progress => _progressController.stream;

  ChunkedUploader({
    required Dio dio,
    required this.uploadUrl,
  }) : _dio = dio;

  /// Pause the upload after the current chunk completes.
  void pause() => _paused = true;

  /// Resume a paused upload from where it left off.
  void resume() => _paused = false;

  /// Cancel the upload entirely.
  void cancel() {
    _cancelled = true;
    _paused = false;
  }

  void dispose() {
    _progressController.close();
  }

  /// Upload [filePath] in chunks to [uploadUrl].
  ///
  /// Returns an [UploadResult] when complete or on failure.
  Future<UploadResult> upload(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return UploadResult(
        success: false,
        errorMessage: 'File not found: $filePath',
        totalChunks: 0,
      );
    }

    final totalBytes = await file.length();
    final totalChunks = (totalBytes / _chunkSizeBytes).ceil();
    final fileName = p.basename(filePath);

    _cancelled = false;

    // Generate a resume key from the file path + size (stable across restarts).
    final resumeKey = base64Url
        .encode(sha256.convert(utf8.encode('$filePath:$totalBytes')).bytes)
        .substring(0, 16);

    var bytesSent = _resumeFromChunk * _chunkSizeBytes;

    final raf = await file.open();

    try {
      for (var i = _resumeFromChunk; i < totalChunks; i++) {
        if (_cancelled) {
          return UploadResult(
            success: false,
            errorMessage: 'Upload cancelled',
            totalChunks: totalChunks,
          );
        }

        // Pause loop — yield until resumed.
        while (_paused) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (_cancelled) break;
        }

        // Read chunk.
        final offset = i * _chunkSizeBytes;
        final remaining = totalBytes - offset;
        final readSize = remaining < _chunkSizeBytes ? remaining : _chunkSizeBytes;

        await raf.setPosition(offset);
        final chunkBytes = await raf.read(readSize.toInt());

        // Compute SHA-256 for this chunk.
        final chunkSha = _sha256Hex(chunkBytes);

        // Build multipart form data.
        final formData = FormData.fromMap({
          'resume_key': resumeKey,
          'chunk_index': i,
          'total_chunks': totalChunks,
          'chunk_sha256': chunkSha,
          'file': MultipartFile.fromBytes(
            chunkBytes,
            filename: '${fileName}_chunk_$i',
          ),
        });

        try {
          await _dio.post(uploadUrl, data: formData);
        } on DioException catch (e) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError) {
            // Network loss — auto-pause and record progress.
            _paused = true;
            _resumeFromChunk = i;
            return UploadResult(
              success: false,
              errorMessage: 'Connection lost at chunk $i — tap Resume to continue',
              totalChunks: totalChunks,
            );
          }
          rethrow;
        }

        bytesSent += readSize.toInt();
        _resumeFromChunk = i + 1;

        if (!_progressController.isClosed) {
          _progressController.add(ChunkProgress(
            chunkIndex: i,
            totalChunks: totalChunks,
            bytesSent: bytesSent,
            totalBytes: totalBytes.toInt(),
            lastChunkSha256: chunkSha,
          ));
        }
      }
    } finally {
      await raf.close();
    }

    return UploadResult(
      success: true,
      remoteUrl: '$uploadUrl/result/$resumeKey',
      totalChunks: totalChunks,
    );
  }

  String _sha256Hex(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }
}
