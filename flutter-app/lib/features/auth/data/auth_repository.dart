import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_session.dart';
import '../../../shared/ticket.dart';

/// Abstract contract for authentication operations.
abstract class AuthRepository {
  Future<AuthSession> signInAsGuest();
  Future<AuthSession> requestOtp(String phone);
  Future<AuthSession> verifyOtp(String phone, String otp);
  Future<AuthSession> switchDemoRole(UserRole role);
  Future<void> signOut();
  Future<AuthSession?> getCurrentSession();
}

/// Mock implementation of [AuthRepository] for demo and offline builds.
class MockAuthRepository implements AuthRepository {
  static const _sessionKey = 'civiclens_auth_session';

  @override
  Future<AuthSession> signInAsGuest() async {
    final session = AuthSession.guest();
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession> requestOtp(String phone) async {
    // Simulate OTP send delay
    await Future.delayed(const Duration(milliseconds: 800));
    // Log mock OTP for demo purposes
    // ignore: avoid_print
    print('[MockAuth] Mock OTP for $phone is: 123456');
    // Return a temporary session indicating OTP was sent
    final session = AuthSession(
      userId: 'pending_$phone',
      isGuest: true,
      role: UserRole.citizen,
      phoneNumber: phone,
    );
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (otp != '123456') {
      throw Exception('Invalid OTP. Use 123456 for demo.');
    }

    final UserRole role;
    final String displayName;

    if (phone.endsWith('9999') || phone == '+919876543210') {
      role = UserRole.officer;
      displayName = 'Officer Sharma - Ward 4 Engineer';
    } else if (phone.endsWith('8888') || phone == '+919876543211') {
      role = UserRole.contractor;
      displayName = 'Apex Infra Projects Ltd';
    } else {
      role = UserRole.citizen;
      displayName = 'Verified Citizen';
    }

    final session = AuthSession(
      userId: 'user_${phone.replaceAll(RegExp(r'[^0-9]'), '')}',
      accessToken: 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock_refresh_token',
      isGuest: false,
      role: role,
      isIdentityVerified: true,
      phoneNumber: phone,
      displayName: displayName,
    );
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession> switchDemoRole(UserRole targetRole) async {
    final current = await getCurrentSession() ?? AuthSession.guest();
    final updated = current.copyWith(
      role: targetRole,
      isGuest: false,
      accessToken: current.accessToken ?? 'demo_token',
      displayName: _demoNameForRole(targetRole),
    );
    await _persist(updated);
    return updated;
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  String _demoNameForRole(UserRole role) {
    switch (role) {
      case UserRole.officer:
        return 'Officer Sharma - Ward 4 Engineer';
      case UserRole.contractor:
        return 'Apex Infra Projects Ltd';
      case UserRole.admin:
        return 'System Administrator';
      case UserRole.citizen:
        return 'Verified Citizen';
    }
  }
}
