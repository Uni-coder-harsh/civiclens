import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/draft_queue_dao.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/report_payload.dart';

/// A draft item enriched with its current [SyncState] from the DB row.
class DraftItem {
  final ReportPayload payload;
  final SyncState syncState;
  final int retryCount;
  final String? lastError;
  final DateTime createdAtUtc;

  const DraftItem({
    required this.payload,
    required this.syncState,
    this.retryCount = 0,
    this.lastError,
    required this.createdAtUtc,
  });
}

/// Repository wrapping [DraftQueueDao] and local file storage.
/// Converts between Drift [ReportDraft] rows and [ReportPayload] domain objects.
class DraftQueueRepository {
  final DraftQueueDao _dao;

  DraftQueueRepository(this._dao);

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Reactive stream of all non-synced drafts as [ReportPayload].
  Stream<List<ReportPayload>> watchPendingDrafts() {
    return _dao.watchPending().map(
          (rows) => rows.map(_rowToPayload).toList(),
        );
  }

  /// Reactive stream of all non-synced drafts as [DraftItem] (includes syncState).
  Stream<List<DraftItem>> watchDraftItems() {
    return _dao.watchPending().map(
          (rows) => rows.map(_rowToDraftItem).toList(),
        );
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns current pending/failed drafts ordered with critical items first.
  Future<List<ReportPayload>> getPendingDrafts() async {
    final rows = await _dao.getPendingDrafts();
    return rows.map(_rowToPayload).toList();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Idempotent upsert — saves [payload] metadata and image references to Drift.
  Future<void> saveDraft(ReportPayload payload) async {
    final companion = ReportDraftsCompanion.insert(
      id: payload.id,
      userId: payload.userId,
      category: payload.category.name,
      severity: payload.severity.name,
      description: payload.description,
      latitude: payload.capture.latitude,
      longitude: payload.capture.longitude,
      altitudeMeters: payload.capture.altitudeMeters,
      accuracyMeters: payload.capture.accuracyMeters,
      bearingDegrees: payload.capture.bearingDegrees,
      speedMps: payload.capture.speedMps,
      capturedAtUtc: payload.capture.capturedAtUtc,
      imagePath: payload.imagePath,
      thumbnailPath: Value(payload.thumbnailPath),
      contractorId: Value(payload.contractorId),
      infrastructureId: Value(payload.infrastructureId),
      qualityGate: payload.qualityGate.name,
      isGuest: payload.isGuest,
      syncState: 'pending',
      createdAtUtc: DateTime.now().toUtc(),
    );
    await _dao.insertDraft(companion);
  }

  /// Removes a draft entry and its associated local media files from disk.
  Future<void> deleteDraft(String id) async {
    // Fetch row before deletion to clean up files
    final rows = await _dao.getPendingDrafts();
    final row = rows.cast<ReportDraft?>().firstWhere(
          (r) => r?.id == id,
          orElse: () => null,
        );

    if (row != null) {
      _safeDelete(row.imagePath);
      if (row.thumbnailPath != null) _safeDelete(row.thumbnailPath!);
    }

    await _dao.deleteDraft(id);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  ReportPayload _rowToPayload(ReportDraft row) {
    return ReportPayload(
      id: row.id,
      userId: row.userId,
      category: ReportCategory.values.byName(row.category),
      severity: ReportSeverity.values.byName(row.severity),
      description: row.description,
      capture: GeoCapture(
        latitude: row.latitude,
        longitude: row.longitude,
        altitudeMeters: row.altitudeMeters,
        accuracyMeters: row.accuracyMeters,
        bearingDegrees: row.bearingDegrees,
        speedMps: row.speedMps,
        capturedAtUtc: row.capturedAtUtc,
      ),
      imagePath: row.imagePath,
      thumbnailPath: row.thumbnailPath,
      contractorId: row.contractorId,
      infrastructureId: row.infrastructureId,
      qualityGate: ImageQualityGate.values.byName(row.qualityGate),
      isGuest: row.isGuest,
    );
  }

  DraftItem _rowToDraftItem(ReportDraft row) {
    final SyncState syncState;
    switch (row.syncState) {
      case 'uploading':
        syncState = SyncState.uploading;
        break;
      case 'synced':
        syncState = SyncState.synced;
        break;
      case 'failed':
        syncState = SyncState.failed;
        break;
      default:
        syncState = SyncState.pending;
    }
    return DraftItem(
      payload: _rowToPayload(row),
      syncState: syncState,
      retryCount: row.retryCount,
      lastError: row.lastError,
      createdAtUtc: row.createdAtUtc,
    );
  }

  void _safeDelete(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Best-effort file cleanup; don't fail the operation
    }
  }
}

// ── Riverpod Providers ────────────────────────────────────────────────────────

final draftQueueRepositoryProvider = Provider<DraftQueueRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DraftQueueRepository(DraftQueueDao(db));
});

/// Top-level stream provider — safe to watch in build() without recreation bugs.
final draftItemsStreamProvider = StreamProvider<List<DraftItem>>((ref) {
  return ref.watch(draftQueueRepositoryProvider).watchDraftItems();
});
