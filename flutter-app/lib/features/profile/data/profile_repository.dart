import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/ticket.dart';

class ProfileRepository {
  final Ref _ref;

  ProfileRepository(this._ref);

  Future<CivicScore> fetchCivicScore(String userId) {
    return _ref.read(apiClientProvider).fetchCivicScore(userId);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref);
});
