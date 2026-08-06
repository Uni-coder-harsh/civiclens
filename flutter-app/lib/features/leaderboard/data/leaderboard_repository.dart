import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/contractor.dart';

class LeaderboardRepository {
  final Ref _ref;

  LeaderboardRepository(this._ref);

  Future<List<ContractorSummary>> fetchLeaderboard({int limit = 50}) {
    return _ref.read(apiClientProvider).fetchLeaderboard(limit: limit);
  }

  Future<ContractorPassport> fetchContractorPassport(String contractorId) {
    return _ref.read(apiClientProvider).fetchContractorPassport(contractorId);
  }
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(ref);
});
