import 'package:drift/drift.dart';
import 'app_database.dart';

/// DAO for the [ReportDrafts] table — exposes reactive queries and mutations
/// required by Phase 1d (Offline-first Draft Queue).
class DraftQueueDao {
  final AppDatabase _db;

  DraftQueueDao(this._db);

  // ── Reactive Queries ────────────────────────────────────────────────────────

  /// Streams all non-synced drafts, ordered: critical severity first,
  /// then ascending by [createdAtUtc].
  Stream<List<ReportDraft>> watchPending() {
    return (_db.select(_db.reportDrafts)
          ..where((t) => t.syncState.isNotIn(['synced']))
          ..orderBy([
            // critical first (alphabetically 'critical' sorts before others only
            // by luck; we use a CASE expression via custom SQL ordering)
            (t) => OrderingTerm(
                  expression: t.severity.caseMatch<int>(
                    when: {const Constant('critical'): const Constant(0)},
                    orElse: const Constant(1),
                  ),
                ),
            (t) => OrderingTerm(expression: t.createdAtUtc),
          ]))
        .watch();
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Persists a new draft row with default [SyncState.pending].
  Future<int> insertDraft(ReportDraftsCompanion draft) {
    final companion = draft.copyWith(syncState: const Value('pending'));
    return _db.into(_db.reportDrafts).insertOnConflictUpdate(companion);
  }

  /// Updates [syncState] to `uploading`.
  Future<int> markUploading(String id) {
    return (_db.update(_db.reportDrafts)..where((t) => t.id.equals(id))).write(
      const ReportDraftsCompanion(syncState: Value('uploading')),
    );
  }

  /// Updates [syncState] to `synced` and records [syncedAtUtc].
  Future<int> markSynced(String id, String serverReportId) {
    return (_db.update(_db.reportDrafts)..where((t) => t.id.equals(id))).write(
      ReportDraftsCompanion(
        syncState: const Value('synced'),
        syncedAtUtc: Value(DateTime.now().toUtc()),
        // We store the server-assigned ID in infrastructureId to avoid schema
        // changes while keeping idempotency.
        infrastructureId: Value(serverReportId),
      ),
    );
  }

  /// Updates [syncState] to `failed` and logs the [errorReason].
  Future<int> markFailed(String id, String errorReason) {
    return (_db.update(_db.reportDrafts)..where((t) => t.id.equals(id))).write(
      ReportDraftsCompanion(
        syncState: const Value('failed'),
        lastError: Value(errorReason),
      ),
    );
  }

  /// Increments the retry counter for a specific draft.
  Future<void> incrementRetry(String id) async {
    final draft = await (_db.select(_db.reportDrafts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (draft == null) return;
    await (_db.update(_db.reportDrafts)..where((t) => t.id.equals(id))).write(
      ReportDraftsCompanion(retryCount: Value(draft.retryCount + 1)),
    );
  }

  /// Returns current pending/failed drafts (one-shot).
  Future<List<ReportDraft>> getPendingDrafts() {
    return (_db.select(_db.reportDrafts)
          ..where((t) => t.syncState.isIn(['pending', 'failed']))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.severity.caseMatch<int>(
                    when: {const Constant('critical'): const Constant(0)},
                    orElse: const Constant(1),
                  ),
                ),
            (t) => OrderingTerm(expression: t.createdAtUtc),
          ]))
        .get();
  }

  /// Deletes a single draft by [id].
  Future<int> deleteDraft(String id) {
    return (_db.delete(_db.reportDrafts)..where((t) => t.id.equals(id))).go();
  }
}
