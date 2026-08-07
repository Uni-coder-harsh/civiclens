import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/draft_queue_dao.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/report_payload.dart';
import '../data/draft_queue_repository.dart';

/// Summarises the overall sync queue state exposed to the UI.
class SyncSummaryState {
  final int pendingCount;
  final int uploadingCount;
  final int failedCount;
  final bool isSyncing;
  final String? lastError;

  const SyncSummaryState({
    this.pendingCount = 0,
    this.uploadingCount = 0,
    this.failedCount = 0,
    this.isSyncing = false,
    this.lastError,
  });

  SyncSummaryState copyWith({
    int? pendingCount,
    int? uploadingCount,
    int? failedCount,
    bool? isSyncing,
    String? lastError,
  }) =>
      SyncSummaryState(
        pendingCount: pendingCount ?? this.pendingCount,
        uploadingCount: uploadingCount ?? this.uploadingCount,
        failedCount: failedCount ?? this.failedCount,
        isSyncing: isSyncing ?? this.isSyncing,
        lastError: lastError ?? this.lastError,
      );
}

/// AsyncNotifier controller managing the offline-first draft sync queue.
///
/// * Listens for connectivity changes and triggers sync on reconnect.
/// * Orders `critical` severity drafts to the front of the upload queue.
/// * Applies exponential back-off: `delay = min(30 min, 1 min × 2^attempt) + jitter`.
class SyncController extends AsyncNotifier<SyncSummaryState> {
  // Per-draft retry attempts — keyed by draft id
  final Map<String, int> _retryAttempts = {};

  // Back-off timers — keyed by draft id
  final Map<String, Timer> _backoffTimers = {};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  static const Duration _maxBackoff = Duration(minutes: 30);
  static const Duration _baseDelay = Duration(minutes: 1);

  @override
  Future<SyncSummaryState> build() async {
    // Start listening for connectivity changes
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    ref.onDispose(() {
      _connectivitySub?.cancel();
      for (final t in _backoffTimers.values) {
        t.cancel();
      }
    });

    return const SyncSummaryState();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Forces an immediate retry of all pending and failed drafts.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    await _runSync();
  }

  /// Resets a specific draft from `failed` → `pending` and initiates upload.
  Future<void> retryDraft(String draftId) async {
    final dao = _buildDao();
    // Reset state to pending so it is picked up by the next sync
    await dao.markUploading(draftId);
    _retryAttempts.remove(draftId);
    _backoffTimers[draftId]?.cancel();
    _backoffTimers.remove(draftId);
    await _uploadDraft(draftId);
  }

  // ── Connectivity ──────────────────────────────────────────────────────────

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (r) => r != ConnectivityResult.none,
    );
    if (hasConnection && !_isSyncing) {
      _runSync();
    }
  }

  // ── Core Sync Logic ───────────────────────────────────────────────────────

  Future<void> _runSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _updateState(isSyncing: true);

    final repo = ref.read(draftQueueRepositoryProvider);
    final drafts = await repo.getPendingDrafts();

    if (drafts.isEmpty) {
      _isSyncing = false;
      _updateState(isSyncing: false, pendingCount: 0);
      return;
    }

    // Critical items first, then FIFO
    final sorted = _sortBySeverity(drafts);

    // Batch upload via InfrastructureApi.syncPendingDrafts
    try {
      final api = ref.read(apiClientProvider);
      final responses = await api.syncPendingDrafts(sorted);
      final dao = _buildDao();

      for (var i = 0; i < responses.length && i < sorted.length; i++) {
        final draftId = sorted[i].id;
        final response = responses[i];
        await dao.markSynced(draftId, response.reportId);
        _retryAttempts.remove(draftId);
      }
    } catch (e) {
      // Fall back to individual uploads with per-draft back-off
      for (final draft in sorted) {
        await _uploadDraft(draft.id);
      }
    }

    _isSyncing = false;
    _updateState(isSyncing: false);
  }

  Future<void> _uploadDraft(String draftId) async {
    final dao = _buildDao();
    final repo = ref.read(draftQueueRepositoryProvider);
    final api = ref.read(apiClientProvider);

    final pending = await repo.getPendingDrafts();
    final draft = pending.cast<ReportPayload?>().firstWhere(
          (d) => d?.id == draftId,
          orElse: () => null,
        );
    if (draft == null) return;

    await dao.markUploading(draftId);
    _updateState(uploadingCount: 1);

    try {
      final response = await api.uploadInfrastructureReport(draft);
      await dao.markSynced(draftId, response.reportId);
      _retryAttempts.remove(draftId);
      _updateState(uploadingCount: 0);
    } catch (e) {
      final attempt = (_retryAttempts[draftId] ?? 0) + 1;
      _retryAttempts[draftId] = attempt;
      await dao.incrementRetry(draftId);
      await dao.markFailed(draftId, e.toString());
      _updateState(failedCount: 1, uploadingCount: 0, lastError: e.toString());

      // Schedule exponential backoff retry
      final delay = _calculateBackoff(attempt);
      _backoffTimers[draftId]?.cancel();
      _backoffTimers[draftId] = Timer(delay, () {
        retryDraft(draftId);
      });
    }
  }

  Duration _calculateBackoff(int attempt) {
    final jitter = Duration(
      milliseconds: math.Random().nextInt(30000), // 0–30 s jitter
    );
    final exponential = Duration(
      milliseconds:
          _baseDelay.inMilliseconds * math.pow(2, attempt - 1).toInt(),
    );
    final capped = exponential > _maxBackoff ? _maxBackoff : exponential;
    return capped + jitter;
  }

  List<ReportPayload> _sortBySeverity(List<ReportPayload> drafts) {
    final sorted = List<ReportPayload>.from(drafts);
    sorted.sort((a, b) {
      if (a.severity == ReportSeverity.critical &&
          b.severity != ReportSeverity.critical) return -1;
      if (b.severity == ReportSeverity.critical &&
          a.severity != ReportSeverity.critical) return 1;
      return 0;
    });
    return sorted;
  }

  void _updateState({
    bool? isSyncing,
    int? pendingCount,
    int? uploadingCount,
    int? failedCount,
    String? lastError,
  }) {
    final current = state.valueOrNull ?? const SyncSummaryState();
    state = AsyncValue.data(current.copyWith(
      isSyncing: isSyncing,
      pendingCount: pendingCount,
      uploadingCount: uploadingCount,
      failedCount: failedCount,
      lastError: lastError,
    ));
  }

  DraftQueueDao _buildDao() {
    return DraftQueueDao(ref.read(appDatabaseProvider));
  }
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncSummaryState>(
  SyncController.new,
);
