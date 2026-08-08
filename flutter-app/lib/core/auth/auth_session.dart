import '../../shared/ticket.dart';

/// Represents the current authentication state of the user session.
class AuthSession {
  final String userId;
  final String? accessToken;
  final String? refreshToken;
  final bool isGuest;
  final UserRole role;
  final bool isIdentityVerified;
  final String? phoneNumber;
  final String? displayName;
  final String? email;

  const AuthSession({
    required this.userId,
    this.accessToken,
    this.refreshToken,
    this.isGuest = true,
    this.role = UserRole.citizen,
    this.isIdentityVerified = false,
    this.phoneNumber,
    this.displayName,
    this.email,
  });

  /// Factory constructor for an anonymous guest session.
  factory AuthSession.guest() => const AuthSession(
        userId: 'guest_user',
        isGuest: true,
        role: UserRole.citizen,
      );

  /// Returns true if user has authenticated with a real identity (not guest).
  bool get isAuthenticated => !isGuest && accessToken != null;

  bool get isOfficer => role == UserRole.officer || role == UserRole.admin;
  bool get isContractor => role == UserRole.contractor;
  bool get isCitizen => role == UserRole.citizen;
  bool get isAdmin => role == UserRole.admin;

  AuthSession copyWith({
    String? userId,
    String? accessToken,
    String? refreshToken,
    bool? isGuest,
    UserRole? role,
    bool? isIdentityVerified,
    String? phoneNumber,
    String? displayName,
    String? email,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isGuest: isGuest ?? this.isGuest,
      role: role ?? this.role,
      isIdentityVerified: isIdentityVerified ?? this.isIdentityVerified,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['userId'] as String,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      isGuest: json['isGuest'] as bool? ?? true,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.citizen,
      ),
      isIdentityVerified: json['isIdentityVerified'] as bool? ?? false,
      phoneNumber: json['phoneNumber'] as String?,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'isGuest': isGuest,
        'role': role.name,
        'isIdentityVerified': isIdentityVerified,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'email': email,
      };

  @override
  String toString() =>
      'AuthSession(userId: $userId, role: $role, isGuest: $isGuest, isAuthenticated: $isAuthenticated)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthSession &&
        other.userId == userId &&
        other.role == role &&
        other.isGuest == isGuest &&
        other.isIdentityVerified == isIdentityVerified;
  }

  @override
  int get hashCode =>
      userId.hashCode ^
      role.hashCode ^
      isGuest.hashCode ^
      isIdentityVerified.hashCode;
}
