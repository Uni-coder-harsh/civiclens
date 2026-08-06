import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/contractor.dart';
import '../data/leaderboard_repository.dart';

class LeaderboardNotifier extends AsyncNotifier<List<ContractorSummary>> {
  @override
  Future<List<ContractorSummary>> build() {
    return _load();
  }

  Future<List<ContractorSummary>> _load() {
    return ref.read(leaderboardRepositoryProvider).fetchLeaderboard();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load());
  }
}

final leaderboardControllerProvider =
    AsyncNotifierProvider<LeaderboardNotifier, List<ContractorSummary>>(
        LeaderboardNotifier.new);

final contractorPassportProvider =
    FutureProvider.family<ContractorPassport, String>((ref, id) {
  return ref.read(leaderboardRepositoryProvider).fetchContractorPassport(id);
});
