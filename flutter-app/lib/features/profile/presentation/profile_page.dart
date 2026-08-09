import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/ticket.dart';
import '../application/profile_controller.dart';

class HomeProfilePage extends ConsumerWidget {
  const HomeProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final scoreAsync = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        color: const Color(0xFF4F46E5).withOpacity(0.08),
                      ),
                    ),
                  ),
                  // Avatar + name
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
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withOpacity(0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              session.isGuest
                                  ? 'G'
                                  : (session.displayName
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      'U'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
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
                              session.displayName ??
                                  (session.isGuest ? 'Guest User' : 'User'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: 'Inter',
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (session.isGuest)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFF59E0B).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B)
                                        .withOpacity(0.4),
                                  ),
                                ),
                                child: const Text(
                                  'GUEST',
                                  style: TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                    letterSpacing: 1,
                                  ),
                                ),
                              )
                            else
                              const Text(
                                'Civic Contributor',
                                style: TextStyle(
                                  color: Color(0xFF818CF8),
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
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
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: Color(0xFF64748B)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => const _SettingsBottomSheet(),
                  );
                },
              ),
            ],
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                scoreAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                      ),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                  data: (score) => Column(
                    children: [
                      // ── Stat cards ─────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _GlowCard(
                              icon: Icons.star_rounded,
                              value: score.total.toString(),
                              label: 'Civic Score',
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GlowCard(
                              icon: Icons.local_fire_department_rounded,
                              value: '${score.streakDays}d',
                              label: 'Streak',
                              color: const Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _GlowCard(
                              icon: Icons.upload_rounded,
                              value: score.reportsSubmitted.toString(),
                              label: 'Reports',
                              color: const Color(0xFF0EA5E9),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GlowCard(
                              icon: Icons.check_circle_rounded,
                              value: score.resolutionsCompleted.toString(),
                              label: 'Resolved',
                              color: const Color(0xFF22C55E),
                            ),
                          ),
                        ],
                      ),

                      // ── Chart ──────────────────────────────────────────
                      if (score.breakdown.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: Theme.of(context).colorScheme.surface),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Score Breakdown',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 160,
                                child: BarChart(
                                  BarChartData(
                                    alignment:
                                        BarChartAlignment.spaceAround,
                                    maxY: score.breakdown
                                            .map((e) =>
                                                e.maxPoints.toDouble())
                                            .fold(0.0,
                                                (a, b) => a > b ? a : b) +
                                        5,
                                    barTouchData:
                                        BarTouchData(enabled: false),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            if (value.toInt() <
                                                score.breakdown.length) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        top: 8),
                                                child: Text(
                                                  score.breakdown[
                                                          value.toInt()]
                                                      .name,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF64748B),
                                                    fontFamily: 'Inter',
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                              showTitles: false)),
                                      topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                              showTitles: false)),
                                      rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                              showTitles: false)),
                                    ),
                                    gridData:
                                        const FlGridData(show: false),
                                    borderData:
                                        FlBorderData(show: false),
                                    barGroups: List.generate(
                                      score.breakdown.length,
                                      (i) => BarChartGroupData(
                                        x: i,
                                        barRods: [
                                          BarChartRodData(
                                            toY: score.breakdown[i].points
                                                .toDouble(),
                                            gradient:
                                                const LinearGradient(
                                              colors: [
                                                Color(0xFF4F46E5),
                                                Color(0xFF818CF8)
                                              ],
                                              begin:
                                                  Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                            width: 22,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(6)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _Phase2QuickActions(session: session),

                const SizedBox(height: 24),

                // ── Account Details Card ──
                _AccountDetailsCard(session: session),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

}

// ── Phase 2 Quick Actions ──────────────────────────────────────────────────────

class _Phase2QuickActions extends StatelessWidget {
  final AuthSession session;

  const _Phase2QuickActions({required this.session});

  @override
  Widget build(BuildContext context) {
    final tiles = <_QuickActionTile>[];

    // Citizen-facing Phase 2b features
    if (FeatureFlags.bridgeCheck) {
      tiles.add(_QuickActionTile(
        icon: Icons.settings_input_antenna_rounded,
        label: 'Bridge Check',
        sublabel: 'Acoustic diagnostic',
        color: const Color(0xFF4F46E5),
        onTap: () => context.push('/bridge-check'),
      ));
    }
    if (FeatureFlags.droneUpload) {
      tiles.add(_QuickActionTile(
        icon: Icons.flight_rounded,
        label: 'Drone Upload',
        sublabel: 'Chunked video upload',
        color: const Color(0xFF0EA5E9),
        onTap: () => context.push('/drone-upload'),
      ));
    }
    tiles.add(_QuickActionTile(
      icon: Icons.directions_walk_rounded,
      label: 'Sweep Mode',
      sublabel: 'Corridor auto-capture',
      color: const Color(0xFF10B981),
      onTap: () => context.push('/capture/sweep'),
    ));

    // Role-based Phase 2a features
    switch (session.role) {
      case UserRole.officer:
        tiles.add(_QuickActionTile(
          icon: Icons.dashboard_rounded,
          label: 'Officer Dashboard',
          sublabel: 'Triage & assign tickets',
          color: const Color(0xFFF59E0B),
          onTap: () => context.push('/officer/dashboard'),
        ));
        tiles.add(_QuickActionTile(
          icon: Icons.assignment_rounded,
          label: 'Officer Queue',
          sublabel: 'Pending reports',
          color: const Color(0xFF818CF8),
          onTap: () => context.push('/officer/queue'),
        ));
      case UserRole.contractor:
        tiles.add(_QuickActionTile(
          icon: Icons.construction_rounded,
          label: 'Contractor Hub',
          sublabel: 'Claims & passport',
          color: const Color(0xFFD97706),
          onTap: () => context.push('/contractor/dashboard'),
        ));
        tiles.add(_QuickActionTile(
          icon: Icons.badge_rounded,
          label: 'My Passport',
          sublabel: 'Civic score QR',
          color: const Color(0xFFEF4444),
          onTap: () {
            final id = session.userId.isEmpty || session.userId == 'mock_contractor'
                ? 'ctr_pune_infra'
                : session.userId;
            context.push('/contractors/$id');
          },
        ));
      case UserRole.citizen:
      default:
        tiles.add(_QuickActionTile(
          icon: Icons.badge_rounded,
          label: 'Contractor Passports',
          sublabel: 'Verify public ratings & QR',
          color: const Color(0xFFD97706),
          onTap: () => context.push('/contractor-search'),
        ));
        tiles.add(_QuickActionTile(
          icon: Icons.leaderboard_rounded,
          label: 'Leaderboard',
          sublabel: 'Top civic contributors',
          color: const Color(0xFFF97316),
          onTap: () => context.push('/contractors'),
        ));
    }

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'QUICK ACTIONS',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontFamily: 'Inter',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glow Stat Card ────────────────────────────────────────────────────────────

class _GlowCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _GlowCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Inter',
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    this.trailing,
    this.onTap,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: isLast ? Radius.zero : const Radius.circular(16),
            bottom:
                isLast ? const Radius.circular(16) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: labelColor ?? Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
                if (trailing == null && onTap != null)
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF475569), size: 20),
              ],
            ),
          ),
        ),
        if (!isLast)
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 64),
            color: Theme.of(context).colorScheme.surface,
          ),
      ],
    );
  }
}

// ── Settings Bottom Sheet ──────────────────────────────────────────────────

class _SettingsBottomSheet extends ConsumerWidget {
  const _SettingsBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.surface),
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.brightness_6_rounded,
                    iconColor: const Color(0xFF818CF8),
                    label: 'Theme',
                    trailing: DropdownButton<AppThemeMode>(
                      value: ref.watch(appThemeModeProvider),
                      underline: const SizedBox.shrink(),
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontFamily: 'Inter',
                        fontSize: 13,
                      ),
                      items: AppThemeMode.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          ref
                              .read(appThemeModeProvider.notifier)
                              .setTheme(v);
                        }
                      },
                    ),
                    isLast: false,
                  ),
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFDC2626),
                    label: 'Sign Out',
                    labelColor: const Color(0xFFDC2626),
                    onTap: () {
                      ref
                          .read(authControllerProvider.notifier)
                          .signOut();
                    },
                    isLast: true,
                  ),
                ],
              ),
            ),

            // ── Demo role switcher ─────────────────────────────────────
            if (AppConfig.isDemoBuild) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded,
                            color: Color(0xFF818CF8), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'DEMO — ROLE SWITCHER',
                          style: TextStyle(
                            color: Color(0xFF818CF8),
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final s = ref.watch(authSessionProvider);
                        return Row(
                          children: UserRole.values
                              .where((r) => r != UserRole.admin)
                              .map((role) {
                            final isActive = s.role == role;
                            final color = _roleColor(role);
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () {
                                    ref
                                        .read(authControllerProvider
                                            .notifier)
                                        .switchDemoRole(role);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 200),
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? color.withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isActive
                                            ? color.withOpacity(0.5)
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        role.name[0].toUpperCase() +
                                            role.name.substring(1),
                                        style: TextStyle(
                                          color: isActive
                                              ? color
                                              : const Color(0xFF475569),
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: isActive
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  Color _roleColor(UserRole role) {
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
}

class _AccountDetailsCard extends StatelessWidget {
  final AuthSession session;

  const _AccountDetailsCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.surface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          _AccountInfoRow(
            icon: Icons.person_rounded,
            label: 'Full Name',
            value: session.displayName ?? 'Citizen Reporter',
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          _AccountInfoRow(
            icon: Icons.email_rounded,
            label: 'Email Address',
            value: session.email ?? 'Not provided',
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          _AccountInfoRow(
            icon: Icons.phone_rounded,
            label: 'Phone Number',
            value: session.phoneNumber != null && session.phoneNumber!.isNotEmpty
                ? '+91 ${session.phoneNumber}'
                : 'Not linked',
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          _AccountInfoRow(
            icon: Icons.verified_user_rounded,
            label: 'Status',
            value: session.isGuest
                ? 'Guest Access'
                : 'Verified Citizen (Active)',
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
        const SizedBox(width: 12),
        Column(
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
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
