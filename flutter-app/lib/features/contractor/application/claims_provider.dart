import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/ticket.dart';
import '../data/contractor_claim_repository.dart';

/// AsyncNotifier managing the contractor's active claims list.
class ClaimsNotifier extends AsyncNotifier<List<TicketSummary>> {
  @override
  Future<List<TicketSummary>> build() async {
    return _load();
  }

  Future<List<TicketSummary>> _load() {
    final repo = ref.read(contractorClaimRepositoryProvider);
    return repo.fetchMyClaims();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final claimsProvider =
    AsyncNotifierProvider<ClaimsNotifier, List<TicketSummary>>(
  ClaimsNotifier.new,
);
