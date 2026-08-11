import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/draft_queue_dao.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/infrastructure_api.dart';
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

/// Repository that uploads reports directly to the backend.
/// On network failure, falls back to local SQLite so the report can be retried.
class DraftQueueRepository {
  final DraftQueueDao _dao;
  final InfrastructureApi _api;

  DraftQueueRepository(this._dao, this._api);

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Reactive stream of all non-synced drafts as [ReportPayload].
  Stream<List<ReportPayload>> watchPendingDrafts() {
    return _dao.watchPending().map(
          (rows) => rows.map(_rowToPayload).toList(),
        );
  }

  /// Reactive stream of all drafts as [DraftItem] (includes syncState & synced history).
  Stream<List<DraftItem>> watchDraftItems() {
    return _dao.watchAll().map(
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

  /// Tries to upload the report directly to the backend (Neon/Supabase).
  /// On network failure, persists locally so the sync controller can retry later.
  /// Does NOT throw after a successful local save — the report is safe either way.
  Future<bool> saveDraft(ReportPayload payload) async {
    try {
      await _api.uploadInfrastructureReport(payload);
      try {
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
          syncState: 'synced',
          createdAtUtc: DateTime.now().toUtc(),
          syncedAtUtc: Value(DateTime.now().toUtc()),
          sensorData: Value(payload.sensorData),
        );
        await _dao.insertSyncedDraft(companion);
      } catch (_) {}
      return true; // uploaded directly to server
    } on Exception catch (e) {
      // Server unreachable / error — save locally for retry
      try {
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
          sensorData: Value(payload.sensorData),
        );
        await _dao.insertDraft(companion);
        // Saved locally — not an error from the user's perspective
        return false; // indicate pending/local
      } catch (localErr) {
        // Both server AND local storage failed — this is a real error
        throw Exception('Upload failed: $e | Local save also failed: $localErr');
      }
    }
  }

  /// Retries all pending/failed local drafts by uploading them to the backend.
  /// Removes successfully uploaded drafts from local storage.
  Future<void> syncPendingDrafts() async {
    final pendingRows = await _dao.getPendingDrafts();
    for (final row in pendingRows) {
      final payload = _rowToPayload(row);
      try {
        await _api.uploadInfrastructureReport(payload);
        await _dao.markSynced(row.id, row.id);
      } catch (e) {
        await _dao.markFailed(row.id, e.toString());
      }
    }
  }

  /// Removes a draft entry and its associated local media files from disk.
  Future<void> deleteDraft(String id) async {
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

  /// Fetches reports submitted by [userId] from Neon DB server and upserts them locally so they appear in Activity Page
  Future<int> fetchAndCacheUserReports(String userId) async {
    try {
      final remoteReports = await _api.fetchMyReports(userId);
      for (final r in remoteReports) {
        final companion = ReportDraftsCompanion.insert(
          id: r.reportId,
          userId: userId,
          category: r.aiLabel ?? 'infrastructure',
          severity: 'medium',
          description: 'Submitted Report (${r.status.name})',
          latitude: 0.0,
          longitude: 0.0,
          altitudeMeters: 0.0,
          accuracyMeters: 0.0,
          bearingDegrees: 0.0,
          speedMps: 0.0,
          capturedAtUtc: r.createdAtUtc,
          imagePath: '',
          qualityGate: 'passed',
          isGuest: false,
          syncState: 'synced',
          createdAtUtc: r.createdAtUtc,
          syncedAtUtc: Value(r.createdAtUtc),
        );
        await _dao.insertSyncedDraft(companion);
      }
      return remoteReports.length;
    } catch (_) {
      return 0;
    }
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
      sensorData: row.sensorData,
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
  final api = ref.watch(apiClientProvider);
  return DraftQueueRepository(DraftQueueDao(db), api);
});

/// Top-level stream provider — safe to watch in build() without recreation bugs.
final draftItemsStreamProvider = StreamProvider<List<DraftItem>>((ref) {
  return ref.watch(draftQueueRepositoryProvider).watchDraftItems();
});
