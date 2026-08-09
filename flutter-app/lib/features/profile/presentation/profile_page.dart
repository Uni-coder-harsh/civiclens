import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/ticket.dart';

class HomeProfilePage extends ConsumerWidget {
  const HomeProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          // ── Header / Avatar Section ──
          SliverAppBar(
            backgroundColor: const Color(0xFF0F172A),
            surfaceTintColor: Colors.transparent,
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                      ),
                    ),
                  ),
                  // Decorative glow circle
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  // Avatar + Name
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              session.isGuest
                                  ? 'G'
                                  : (session.displayName?.isNotEmpty == true
                                      ? session.displayName!.substring(0, 1).toUpperCase()
                                      : 'U'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              session.displayName ?? (session.isGuest ? 'Guest User' : 'User'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: 'Inter',
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _roleColor(session.role).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _roleColor(session.role).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                session.role.name.toUpperCase(),
                                style: TextStyle(
                                  color: _roleColor(session.role),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Profile Body ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Account Details Card ──
                _AccountDetailsCard(session: session),

                const SizedBox(height: 24),

                // ── Sign Out Button ──
                GestureDetector(
                  onTap: () {
                    ref.read(authControllerProvider.notifier).signOut();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Sign Out of Account',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.citizen:
        return const Color(0xFF0D9488);
      case UserRole.officer:
        return const Color(0xFF818CF8);
      case UserRole.contractor:
        return const Color(0xFFF59E0B);
      case UserRole.admin:
        return const Color(0xFFEF4444);
    }
  }
}

class _AccountDetailsCard extends StatelessWidget {
  final AuthSession session;

  const _AccountDetailsCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCOUNT DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              fontFamily: 'Inter',
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _AccountInfoRow(
            icon: Icons.person_rounded,
            label: 'Full Name',
            value: session.displayName ?? 'Citizen Reporter',
          ),
          const Divider(color: Color(0xFF334155), height: 32),
          _AccountInfoRow(
            icon: Icons.email_rounded,
            label: 'Email Address',
            value: session.email ?? 'Not provided',
          ),
          const Divider(color: Color(0xFF334155), height: 32),
          _AccountInfoRow(
            icon: Icons.phone_rounded,
            label: 'Phone Number',
            value: session.phoneNumber != null && session.phoneNumber!.isNotEmpty
                ? '+91 ${session.phoneNumber}'
                : 'Not linked',
          ),
          const Divider(color: Color(0xFF334155), height: 32),
          _AccountInfoRow(
            icon: Icons.verified_user_rounded,
            label: 'Verification Status',
            value: session.isGuest
                ? 'Guest Access Only'
                : 'Verified Contributor (Active)',
            valueColor: session.isGuest ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
