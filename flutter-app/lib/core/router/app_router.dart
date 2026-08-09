import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/presentation/entry_page.dart';
import '../../features/auth/presentation/email_auth_pages.dart';
import '../../features/auth/presentation/otp_phone_page.dart';
import '../../features/auth/presentation/otp_verify_page.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/home/presentation/home_dashboard_page.dart';
import '../../features/capture/presentation/camera_page.dart';
import '../../features/capture/presentation/preview_review_page.dart';
import '../../features/capture/data/capture_repository.dart';
import '../../shared/stub_pages.dart'
    hide
        CameraPage,
        ReportFormPage,
        ReportDetailPage,
        OfficerQueuePage,
        OfficerTicketPage,
        ContractorClaimsPage,
        ContractorTicketPage,
        WitnessPage,
        LeaderboardPage,
        ContractorPassportPage;
import '../../features/map/presentation/map_page.dart';
import '../../features/report/presentation/report_form.dart';
import '../../features/report/presentation/report_detail_page.dart';
import '../../features/report/presentation/draft_queue_page.dart';
import '../../features/officer/presentation/queue_page.dart';
import '../../features/officer/presentation/ticket_action_sheet.dart';
import '../../features/contractor/presentation/claims_page.dart';
import '../../features/contractor/presentation/contractor_ticket_view.dart';
import '../../features/witness/presentation/witness_confirm_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/leaderboard/presentation/leaderboard_page.dart';
import '../../features/leaderboard/presentation/passport_page.dart';
import '../../features/officer/presentation/triage_dashboard_page.dart';
import '../../features/contractor/presentation/contractor_dashboard_page.dart';
import '../../features/leaderboard/presentation/passport_search_page.dart';
// Phase 2b
import '../../features/bridge_check/presentation/bridge_check_instructions_page.dart';
import '../../features/bridge_check/presentation/bridge_check_recording_page.dart';
import '../../features/bridge_check/presentation/bridge_check_verdict_page.dart';
import '../../features/drone_upload/presentation/drone_upload_page.dart' as drone;
import '../../features/capture/presentation/sweep_mode_page.dart';
import '../../shared/ticket.dart';

/// Provider exposing the configured [GoRouter] instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-evaluate router when auth session changes
  final authListenable = _AuthListenable(ref);

  return GoRouter(
    refreshListenable: authListenable,
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final path = state.matchedLocation;

      // Allow splash to always load
      if (path == '/splash') return null;

      // RBAC guards for officer private portal routes
      if (path.startsWith('/officer/')) {
        if (!session.isOfficer) {
          return '/home/dashboard';
        }
      }

      // RBAC guards for contractor private portal routes (/contractor/dashboard, /contractor/claims, etc.)
      // Note: /contractors, /contractor-search, /contractors/:id are public accountability records
      if (path.startsWith('/contractor/')) {
        if (!session.isContractor) {
          return '/home/dashboard';
        }
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Auth flow
      GoRoute(
        path: '/entry',
        builder: (context, state) => const EntryPage(),
        routes: [
          GoRoute(
            path: 'login',
            builder: (context, state) => const EmailLoginPage(),
          ),
          GoRoute(
            path: 'register',
            builder: (context, state) => const EmailRegisterPage(),
          ),
          GoRoute(
            path: 'verify',
            builder: (context, state) {
              final email = state.extra as String? ?? '';
              return EmailVerifyOtpPage(email: email);
            },
          ),
          GoRoute(
            path: 'forgot-password',
            builder: (context, state) => const ForgotPasswordPage(),
          ),
          GoRoute(
            path: 'reset-password',
            builder: (context, state) {
              final email = state.extra as String? ?? '';
              return ResetPasswordPage(email: email);
            },
          ),
          GoRoute(
            path: 'phone',
            builder: (context, state) => const OtpPhonePage(),
          ),
          GoRoute(
            path: 'verify-phone',
            builder: (context, state) {
              final phone = state.extra as String? ?? '';
              return OtpVerifyPage(phone: phone);
            },
          ),
        ],
      ),

      // Home shell with tab branches
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/dashboard',
                builder: (context, state) => const HomeDashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/map',
                builder: (context, state) => const MapPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/activity',
                builder: (context, state) => const DraftQueuePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/profile',
                builder: (context, state) => const HomeProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // Capture
      GoRoute(
        path: '/capture',
        builder: (context, state) => const CameraPage(),
        routes: [
          GoRoute(
            path: 'preview',
            builder: (context, state) {
              final result = state.extra as CaptureResult;
              return PreviewReviewPage(captureResult: result);
            },
          ),
        ],
      ),

      // Reports
      GoRoute(
        path: '/report/form',
        builder: (context, state) => const ReportFormScreen(),
      ),
      GoRoute(
        path: '/report/:draftId',
        builder: (context, state) {
          final draftId = state.pathParameters['draftId']!;
          return DraftStatusPage(draftId: draftId);
        },
      ),
      GoRoute(
        path: '/report/detail/:reportId',
        builder: (context, state) {
          final reportId = state.pathParameters['reportId']!;
          return ReportDetailPage(reportId: reportId);
        },
      ),

      // Officer routes (RBAC guarded via redirect)
      GoRoute(
        path: '/officer/dashboard',
        builder: (context, state) => const TriageDashboardPage(),
      ),
      GoRoute(
        path: '/officer/queue',
        builder: (context, state) => const OfficerQueuePage(),
      ),
      GoRoute(
        path: '/officer/report/:reportId',
        builder: (context, state) {
          final reportId = state.pathParameters['reportId']!;
          return OfficerTicketPage(reportId: reportId);
        },
      ),

      // Contractor routes (RBAC guarded via redirect)
      GoRoute(
        path: '/contractor/dashboard',
        builder: (context, state) => const ContractorDashboardPage(),
      ),
      GoRoute(
        path: '/contractor/claims',
        builder: (context, state) => const ContractorClaimsPage(),
      ),
      GoRoute(
        path: '/contractor/ticket/:reportId',
        builder: (context, state) {
          final reportId = state.pathParameters['reportId']!;
          return ContractorTicketView(reportId: reportId);
        },
      ),

      // Share & Witness
      GoRoute(
        path: '/share',
        builder: (context, state) => const ShareCardPage(),
      ),
      GoRoute(
        path: '/witness/:reportId',
        builder: (context, state) {
          final reportId = state.pathParameters['reportId']!;
          return WitnessConfirmPage(reportId: reportId);
        },
      ),

      // Leaderboard / Contractor passport
      GoRoute(
        path: '/contractors',
        builder: (context, state) => const LeaderboardPage(),
      ),
      GoRoute(
        path: '/contractor-search',
        builder: (context, state) => const PassportSearchPage(),
      ),
      GoRoute(
        path: '/c/:contractorId',
        builder: (context, state) {
          final contractorId = state.pathParameters['contractorId']!;
          return ContractorPassportPage(contractorId: contractorId);
        },
      ),
      GoRoute(
        path: '/contractors/:contractorId',
        builder: (context, state) {
          final contractorId = state.pathParameters['contractorId']!;
          return ContractorPassportPage(contractorId: contractorId);
        },
      ),

      // Utilities — Phase 2b routes
      GoRoute(
        path: '/bridge-check',
        builder: (context, state) => const BridgeCheckInstructionsPage(),
        routes: [
          GoRoute(
            path: 'recording',
            builder: (context, state) => const BridgeCheckRecordingPage(),
          ),
          GoRoute(
            path: 'verdict',
            builder: (context, state) => const BridgeCheckVerdictPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/drone-upload',
        builder: (context, state) => const drone.DroneUploadPage(),
      ),
      GoRoute(
        path: '/capture/sweep',
        builder: (context, state) => const SweepModePage(),
      ),
    ],
  );
});

/// Listenable that triggers router refresh when [authSessionProvider] changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authSessionProvider, (_, __) => notifyListeners());
  }
}

/// Demo Role Switcher FAB overlay — wraps child widget.
/// Only visible when [AppConfig.isDemoBuild] is true.
class DemoRoleSwitcherOverlay extends ConsumerWidget {
  final Widget child;
  const DemoRoleSwitcherOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConfig.isDemoBuild) return child;

    final session = ref.watch(authSessionProvider);

    return Stack(
      children: [
        child,
        Positioned(
          bottom: 90,
          right: 16,
          child: _DemoRoleSwitcherFab(currentRole: session.role),
        ),
      ],
    );
  }
}

class _DemoRoleSwitcherFab extends ConsumerWidget {
  final UserRole currentRole;
  const _DemoRoleSwitcherFab({required this.currentRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _RoleChip(
          label: 'Citizen',
          role: UserRole.citizen,
          isActive: currentRole == UserRole.citizen,
          onTap: () => _switchRole(ref, UserRole.citizen),
        ),
        const SizedBox(height: 6),
        _RoleChip(
          label: 'Officer',
          role: UserRole.officer,
          isActive: currentRole == UserRole.officer,
          onTap: () => _switchRole(ref, UserRole.officer),
        ),
        const SizedBox(height: 6),
        _RoleChip(
          label: 'Contractor',
          role: UserRole.contractor,
          isActive: currentRole == UserRole.contractor,
          onTap: () => _switchRole(ref, UserRole.contractor),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'DEMO',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4F46E5),
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  void _switchRole(WidgetRef ref, UserRole targetRole) {
    ref.read(authControllerProvider.notifier).switchDemoRole(targetRole);
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final UserRole role;
  final bool isActive;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.role,
    required this.isActive,
    required this.onTap,
  });

  Color get _roleColor {
    switch (role) {
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:
              isActive ? _roleColor : const Color(0xFF1E293B).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? _roleColor : const Color(0xFF334155),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: _roleColor.withOpacity(0.4), blurRadius: 8)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
