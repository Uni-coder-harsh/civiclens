import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';
import '../data/officer_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class OfficerQueueFilter {
  final DefectStatus? status;
  final String? zone;

  const OfficerQueueFilter({this.status, this.zone});

  OfficerQueueFilter copyWith(
          {DefectStatus? status, String? zone, bool clearStatus = false}) =>
      OfficerQueueFilter(
        status: clearStatus ? null : (status ?? this.status),
        zone: zone ?? this.zone,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class OfficerQueueNotifier extends AsyncNotifier<List<TicketSummary>> {
  OfficerQueueFilter _filter = const OfficerQueueFilter();

  @override
  Future<List<TicketSummary>> build() async {
    return _load();
  }

  Future<List<TicketSummary>> _load() {
    final repo = ref.read(officerRepositoryProvider);
    return repo.fetchQueue(status: _filter.status, zone: _filter.zone);
  }

  /// Applies a new status/zone filter and reloads the queue.
  Future<void> applyFilter(
      {DefectStatus? status, String? zone, bool clearStatus = false}) async {
    _filter =
        _filter.copyWith(status: status, zone: zone, clearStatus: clearStatus);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Refreshes without changing the current filter.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final officerQueueProvider =
    AsyncNotifierProvider<OfficerQueueNotifier, List<TicketSummary>>(
  OfficerQueueNotifier.new,
);
