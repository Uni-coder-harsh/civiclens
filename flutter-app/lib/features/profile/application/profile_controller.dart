import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/ticket.dart';
import '../data/profile_repository.dart';

class ProfileNotifier extends AsyncNotifier<CivicScore> {
  @override
  Future<CivicScore> build() async {
    final session = ref.watch(authSessionProvider);
    if (session.isGuest) {
      return const CivicScore(
        total: 0,
        reportsSubmitted: 0,
        reportsVerified: 0,
        resolutionsCompleted: 0,
        streakDays: 0,
        breakdown: [],
      );
    }
    return _load(session.userId);
  }

  Future<CivicScore> _load(String userId) {
    return ref.read(profileRepositoryProvider).fetchCivicScore(userId);
  }

  Future<void> refresh() async {
    final session = ref.read(authSessionProvider);
    if (!session.isGuest) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _load(session.userId));
    }
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileNotifier, CivicScore>(ProfileNotifier.new);
