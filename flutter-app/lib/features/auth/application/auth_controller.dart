import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/ticket.dart';
import '../data/auth_repository.dart';

/// Provider exposing the [AuthRepository] implementation.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AppConfig.useMockApi
      ? MockAuthRepository()
      : RemoteAuthRepository(dio: ref.watch(dioProvider));
});

/// AsyncNotifier that manages the full authentication lifecycle.
class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final repo = ref.read(authRepositoryProvider);
    final existing = await repo.getCurrentSession();
    if (existing != null) return existing;
    // Auto sign in as guest on first launch
    return repo.signInAsGuest();
  }

  Future<void> signInAsGuest() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInAsGuest(),
    );
  }

  Future<void> requestOtp(String phone) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).requestOtp(phone),
    );
  }

  Future<void> verifyOtp(String phone, String otp) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).verifyOtp(phone, otp),
    );
  }

  Future<String> register(String email, String password, String fullName, UserRole role) async {
    state = const AsyncLoading();
    try {
      final msg = await ref.read(authRepositoryProvider).register(email, password, fullName, role);
      state = const AsyncData(null);
      return msg;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> verifyEmailOtp(String email, String otp) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).verifyEmailOtp(email, otp),
    );
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithEmail(email, password),
    );
  }

  Future<String> requestPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      final msg = await ref.read(authRepositoryProvider).requestPasswordReset(email);
      state = const AsyncData(null);
      return msg;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).resetPassword(email, otp, newPassword);
      return state.value;
    });
  }

  Future<void> switchDemoRole(UserRole targetRole) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).switchDemoRole(targetRole),
    );
  }
  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updated = await ref.read(authRepositoryProvider).updateProfile(
        userId: current.userId,
        displayName: displayName,
        email: email,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
      );
      return updated;
    });
  }

  Future<String> uploadAvatar(String filePath) async {
    final current = state.value;
    if (current == null) throw Exception("User not signed in.");
    return await ref.read(authRepositoryProvider).uploadAvatar(current.userId, filePath);
  }
}

/// The primary auth controller provider.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(() {
  return AuthController();
});

/// Convenient synchronous provider for the current [AuthSession].
/// Falls back to [AuthSession.guest()] while loading or on error.
final authSessionProvider = Provider<AuthSession>((ref) {
  final asyncSession = ref.watch(authControllerProvider);
  return asyncSession.when(
    data: (session) => session ?? AuthSession.guest(),
    loading: () => AuthSession.guest(),
    error: (_, __) => AuthSession.guest(),
  );
});
