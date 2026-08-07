import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/ticket.dart';

/// Shared error widget displayed when [ForbiddenException] is thrown or
/// a role-access check fails.
///
/// Shows the "Switch Role (Demo)" button when [AppConfig.isDemoBuild] is true.
class ForbiddenState extends ConsumerWidget {
  final String? requiredRole;
  final String? action;

  const ForbiddenState({super.key, this.requiredRole, this.action});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFFDC2626),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Access Restricted',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              requiredRole != null
                  ? 'This action requires $requiredRole access.'
                  : action != null
                      ? '"$action" is not permitted for your current role.'
                      : 'You do not have permission to perform this action.',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontFamily: 'Inter',
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (AppConfig.isDemoBuild) ...[
              const SizedBox(height: 32),
              const _DemoRoleSwitcher(),
            ],
          ],
        ),
      ),
    );
  }
}

class _DemoRoleSwitcher extends ConsumerWidget {
  const _DemoRoleSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
          ),
          child: const Text(
            'DEMO MODE — Switch Role',
            style: TextStyle(
              color: Color(0xFF818CF8),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: UserRole.values
              .where((r) => r != UserRole.admin)
              .map(
                (role) => GestureDetector(
                  onTap: () => ref
                      .read(authControllerProvider.notifier)
                      .switchDemoRole(role),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: session.role == role
                          ? _roleColor(role)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: session.role == role
                            ? _roleColor(role)
                            : const Color(0xFF334155),
                        width: 1.5,
                      ),
                      boxShadow: session.role == role
                          ? [
                              BoxShadow(
                                color: _roleColor(role).withOpacity(0.35),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      role.name[0].toUpperCase() + role.name.substring(1),
                      style: TextStyle(
                        color: session.role == role
                            ? Colors.white
                            : Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8),
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.citizen:
        return const Color(0xFF0D9488);
      case UserRole.officer:
        return const Color(0xFF4F46E5);
      case UserRole.contractor:
        return const Color(0xFFD97706);
      case UserRole.admin:
        return const Color(0xFFDC2626);
    }
  }
}
