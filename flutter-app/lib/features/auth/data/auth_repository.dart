import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/auth/auth_session.dart';
import '../../../shared/ticket.dart';

/// Abstract contract for authentication operations.
/// Abstract contract for authentication operations.
abstract class AuthRepository {
  Future<AuthSession> signInAsGuest();
  Future<AuthSession> requestOtp(String phone);
  Future<AuthSession> verifyOtp(String phone, String otp);
  Future<String> register(String email, String password, String fullName, UserRole role);
  Future<AuthSession> verifyEmailOtp(String email, String otp);
  Future<AuthSession> signInWithEmail(String email, String password);
  Future<String> requestPasswordReset(String email);
  Future<void> resetPassword(String email, String otp, String newPassword);
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
  Future<String> register(String email, String password, String fullName, UserRole role) async {
    await Future.delayed(const Duration(milliseconds: 800));
    // ignore: avoid_print
    print('[MockAuth] Registered user: $email, role: ${role.name}. Mock verification code is: 123456');
    return 'Verification code sent to your email. (Simulated OTP is 123456)';
  }

  @override
  Future<AuthSession> verifyEmailOtp(String email, String otp) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (otp != '123456') {
      throw Exception('Invalid verification code. Use 123456 for demo.');
    }

    final session = AuthSession(
      userId: 'mock_user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
      accessToken: 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock_refresh_token',
      isGuest: false,
      role: email.contains('contractor') ? UserRole.contractor : (email.contains('officer') ? UserRole.officer : UserRole.citizen),
      isIdentityVerified: true,
      displayName: 'Verified Demo User',
      email: email,
    );
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final session = AuthSession(
      userId: 'mock_user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
      accessToken: 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock_refresh_token',
      isGuest: false,
      role: email.contains('contractor') ? UserRole.contractor : (email.contains('officer') ? UserRole.officer : UserRole.citizen),
      isIdentityVerified: true,
      displayName: 'Verified Demo User',
      email: email,
    );
    await _persist(session);
    return session;
  }

  @override
  Future<String> requestPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // ignore: avoid_print
    print('[MockAuth] Password reset requested for $email. Mock OTP code is: 123456');
    return 'Password reset code sent. (Simulated OTP is 123456)';
  }

  @override
  Future<void> resetPassword(String email, String otp, String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (otp != '123456') {
      throw Exception('Invalid OTP reset code.');
    }
  }

  @override
  Future<AuthSession> requestOtp(String phone) async {
    await Future.delayed(const Duration(milliseconds: 800));
    // ignore: avoid_print
    print('[MockAuth] Mock OTP for $phone is: 123456');
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

/// Remote implementation of [AuthRepository] communicating with the backend.
class RemoteAuthRepository implements AuthRepository {
  final Dio dio;
  static const _sessionKey = 'civiclens_auth_session';

  RemoteAuthRepository({required this.dio});

  @override
  Future<AuthSession> signInAsGuest() async {
    try {
      final response = await dio.post('/v1/auth/guest');
      final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
      await _persist(session);
      return session;
    } catch (_) {
      final session = AuthSession.guest();
      await _persist(session);
      return session;
    }
  }

  @override
  Future<String> register(String email, String password, String fullName, UserRole role) async {
    final response = await dio.post(
      '/v1/auth/register',
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role.name,
      },
    );
    return (response.data as Map<String, dynamic>)['message'] as String? ?? 'Verification code sent successfully.';
  }

  @override
  Future<AuthSession> verifyEmailOtp(String email, String otp) async {
    final response = await dio.post(
      '/v1/auth/email/verify',
      data: {
        'email': email,
        'otp': otp,
      },
    );
    final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession> signInWithEmail(String email, String password) async {
    final response = await dio.post(
      '/v1/auth/email/login',
      data: {
        'email': email,
        'password': password,
      },
    );
    final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
    await _persist(session);
    return session;
  }

  @override
  Future<String> requestPasswordReset(String email) async {
    final response = await dio.post(
      '/v1/auth/password/forgot',
      data: {
        'email': email,
      },
    );
    return (response.data as Map<String, dynamic>)['message'] as String? ?? 'Reset code sent successfully.';
  }

  @override
  Future<void> resetPassword(String email, String otp, String newPassword) async {
    await dio.post(
      '/v1/auth/password/reset',
      data: {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      },
    );
  }

  @override
  Future<AuthSession> requestOtp(String phone) async {
    await dio.post(
      '/v1/auth/otp/send',
      data: {'phone': phone},
    );
    final session = AuthSession(
      userId: 'pending_${phone.replaceAll(RegExp(r'[^0-9]'), '')}',
      isGuest: true,
      role: UserRole.citizen,
      phoneNumber: phone,
    );
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession> verifyOtp(String phone, String otp) async {
    final response = await dio.post(
      '/v1/auth/otp/verify',
      data: {'phone': phone, 'otp': otp},
    );
    final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession> switchDemoRole(UserRole targetRole) async {
    final response = await dio.post(
      '/v1/auth/switch-role',
      data: {'role': targetRole.name},
    );
    final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
    await _persist(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    try {
      await dio.post('/v1/auth/logout');
    } catch (_) {}
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
}
