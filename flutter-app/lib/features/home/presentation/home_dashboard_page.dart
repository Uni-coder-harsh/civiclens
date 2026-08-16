import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/auth/auth_session.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../map/data/map_repository.dart';
import '../../../shared/defect.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';

/// Dynamic FutureProvider that queries the backend database for nearby defects
/// based on the user's live GPS coordinates.
final dashboardDefectsProvider = FutureProvider.autoDispose<List<NearbyDefect>>((ref) async {
  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 4),
    );
    final repo = ref.read(mapRepositoryProvider);
    return await repo.fetchNearbyDefects(position.latitude, position.longitude, 5000);
  } catch (_) {
    // Fallback to static coordinates (New Delhi) if location services or permissions fail
    final repo = ref.read(mapRepositoryProvider);
    return await repo.fetchNearbyDefects(28.6139, 77.2090, 5000);
  }
});

class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    if (session.role == UserRole.activist) {
      return const _ActivistHomeDashboard();
    }

    final scoreAsync = ref.watch(profileControllerProvider);
    final defectsAsync = ref.watch(dashboardDefectsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardDefectsProvider.future),
          color: const Color(0xFF4F46E5),
          backgroundColor: const Color(0xFF1E293B),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ── Welcome Banner Sliver ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.displayName ?? 'Citizen Reporter',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      // Glassmorphic User Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          session.role.name.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF818CF8),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Civic Score Card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF3730A3).withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CIVIC SCORE',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC7D2FE),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              scoreAsync.when(
                                data: (score) => Text(
                                  '${score.total} pts',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                loading: () => const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                error: (_, __) => const Text(
                                  '75 pts',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Level 3 · Elite Contributor',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: Color(0xFF818CF8),
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Grid Actions Hub ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QUICK ACTIONS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.25,
                        children: [
                          _HubCard(
                            title: 'Capture Crack',
                            subtitle: 'Camera Verification',
                            icon: Icons.camera_alt_rounded,
                            iconColor: const Color(0xFFEC4899),
                            gradientColors: const [Color(0xFF3F1D38), Color(0xFF271322)],
                            borderColor: const Color(0xFFEC4899).withValues(alpha: 0.3),
                            onTap: () => context.push('/capture'),
                          ),
                          _HubCard(
                            title: 'Explore Map',
                            subtitle: 'Live Defect Status',
                            icon: Icons.map_rounded,
                            iconColor: const Color(0xFF10B981),
                            gradientColors: const [Color(0xFF143A2F), Color(0xFF0F2620)],
                            borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                            onTap: () => context.push('/map'),
                          ),
                          _HubCard(
                            title: 'Contractors',
                            subtitle: 'View Passports',
                            icon: Icons.construction_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            gradientColors: const [Color(0xFF3F301D), Color(0xFF2B1F11)],
                            borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            onTap: () => context.push('/contractor-search'),
                          ),
                          _HubCard(
                            title: 'Leaderboard',
                            subtitle: 'Top Contractors',
                            icon: Icons.leaderboard_rounded,
                            iconColor: const Color(0xFF3B82F6),
                            gradientColors: const [Color(0xFF1E2D4B), Color(0xFF111C33)],
                            borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Navigate to Leaderboard via Profile settings or Contractor profiles.'),
                                  backgroundColor: Color(0xFF1E293B),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Live Stats Tracker ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'COMMUNITY PROGRESS',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              '72% Resolved',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(
                            value: 0.72,
                            minHeight: 8,
                            backgroundColor: Color(0xFF334155),
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            _StatItem(label: 'Total Fixed', value: '142'),
                            _StatItem(label: 'In Progress', value: '38'),
                            _StatItem(label: 'Open Claims', value: '16'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Recent Activity / Potholes Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: const Text(
                    'RECENT CIVIC REPORTS (LIVE)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),

              // ── Dynamic Recent Activity List ──
              defectsAsync.when(
                data: (defects) {
                  if (defects.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Center(
                          child: Text(
                            'No reports found in this area.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final defect = defects[index];
                        Color statusColor;
                        switch (defect.status) {
                          case DefectStatus.resolved:
                          case DefectStatus.closed:
                            statusColor = const Color(0xFF10B981);
                            break;
                          case DefectStatus.inProgress:
                          case DefectStatus.assigned:
                            statusColor = const Color(0xFFF59E0B);
                            break;
                          case DefectStatus.rejected:
                            statusColor = const Color(0xFFEF4444);
                            break;
                          default:
                            statusColor = const Color(0xFF3B82F6);
                        }
                        
                        String cleanCategory = defect.category.name;
                        // Prettify category string
                        if (cleanCategory.length > 1) {
                          cleanCategory = cleanCategory[0].toUpperCase() + cleanCategory.substring(1);
                        }

                        final isBridgeType = defect.category.name.toLowerCase().contains('bridge');

                        return _ActivityTile(
                          category: cleanCategory,
                          location: (defect.address != null && defect.address!.isNotEmpty)
                              ? defect.address!
                              : 'Lat: ${defect.latitude.toStringAsFixed(5)}, Lng: ${defect.longitude.toStringAsFixed(5)}',
                          status: defect.status.name,
                          statusColor: statusColor,
                          icon: isBridgeType
                              ? Icons.construction_rounded
                              : Icons.warning_amber_rounded,
                          time: defect.watermarkVerified ? 'Verified' : 'Unverified',
                        );
                      },
                      childCount: defects.length > 5 ? 5 : defects.length, // Show up to 5 items on dashboard
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Center(
                      child: Text(
                        'Failed to load live reports: $err',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFFEF4444),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final Color borderColor;
  final VoidCallback onTap;

  const _HubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: iconColor, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String category;
  final String location;
  final String status;
  final Color statusColor;
  final IconData icon;
  final String time;

  const _ActivityTile({
    required this.category,
    required this.location,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF334155).withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Social Media Activist Dashboard Landing View ───────────────────────────────

class _ActivistHomeDashboard extends ConsumerStatefulWidget {
  const _ActivistHomeDashboard();

  @override
  ConsumerState<_ActivistHomeDashboard> createState() => _ActivistHomeDashboardState();
}

class _ActivistHomeDashboardState extends ConsumerState<_ActivistHomeDashboard> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final defectsAsync = ref.watch(dashboardDefectsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardDefectsProvider.future),
          color: const Color(0xFF8B5CF6),
          backgroundColor: const Color(0xFF1E293B),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Welcome Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Activist Workspace,',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.displayName ?? 'Citizen Journalist',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                        ),
                        child: const Text(
                          'ACTIVIST',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA78BFA),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Activist Influence & Reach Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CAMPAIGN REACH & INFLUENCE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _ActivistMetricCard(
                            label: 'Total Post Reach',
                            value: '384.2K',
                            trend: '+14% this wk',
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFF10B981),
                          ),
                          _ActivistMetricCard(
                            label: 'Repairs Sparked',
                            value: '18 Defects',
                            trend: '82% success',
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                          ),
                          _ActivistMetricCard(
                            label: 'Rajkot Rank',
                            value: '#3 Active',
                            trend: 'Top 5% reach',
                            icon: Icons.military_tech_rounded,
                            iconColor: const Color(0xFFF59E0B),
                          ),
                          _ActivistMetricCard(
                            label: 'Active Shares',
                            value: '84.3K',
                            trend: 'Direct retweets',
                            icon: Icons.share_rounded,
                            iconColor: const Color(0xFFEC4899),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MOBILIZATION DESK',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActivistDeskButton(
                              title: 'AI Campaign Hub',
                              subtitle: 'Generate captions/tags',
                              icon: Icons.campaign_rounded,
                              color: const Color(0xFF8B5CF6),
                              onTap: () => context.push('/activist/dashboard'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActivistDeskButton(
                              title: 'Defects Map',
                              subtitle: 'Explore hazard coordinates',
                              icon: Icons.map_rounded,
                              color: const Color(0xFF10B981),
                              onTap: () => context.push('/map'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Active Campaigns Records
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACTIVE CAMPAIGNS & METRICS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ActiveCampaignRecord(
                        title: 'Kalavad Road Pothole Collapse',
                        location: '📍 Kalavad Road, Rajkot',
                        views: '15.4K views',
                        progress: 0.65,
                        status: '📢 Campaign Active',
                        statusColor: const Color(0xFFF59E0B),
                      ),
                      _ActiveCampaignRecord(
                        title: 'Swargate Bridge Crack',
                        location: '📍 Swargate, Pune',
                        views: '45.2K views',
                        progress: 1.0,
                        status: '✅ Resolved (Repairs Started)',
                        statusColor: const Color(0xFF10B981),
                      ),
                      _ActiveCampaignRecord(
                        title: 'University Road Drainage Crater',
                        location: '📍 Rajkot University Gate',
                        views: '9.1K views',
                        progress: 0.35,
                        status: '📢 Campaign Active',
                        statusColor: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ),
              ),

              // Region Alerts requiring mobilization
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OPEN HAZARDS REQUIRING CAMPAIGNS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/map'),
                        child: const Text('View All', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),

              // Defects Feed
              defectsAsync.when(
                data: (defects) {
                  final regionDefects = defects.take(3).toList();
                  if (regionDefects.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('No un-campaigned defects found nearby.', style: TextStyle(color: Color(0xFF64748B))),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final d = regionDefects[index];
                        final categoryName = d.category.name.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').toUpperCase();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          child: GestureDetector(
                            onTap: () => context.push('/activist/dashboard'),
                            child: _ActivityTile(
                              category: categoryName,
                              location: d.address ?? 'Pune, India',
                              status: d.aiSeverity?.toUpperCase() ?? 'MEDIUM',
                              statusColor: const Color(0xFF8B5CF6),
                              time: 'Un-campaigned · Launch AI post',
                              icon: Icons.campaign_rounded,
                            ),
                          ),
                        );
                      },
                      childCount: regionDefects.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    ),
                  ),
                ),
                error: (_, __) => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Failed to load local reports.', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper metric card widget
class _ActivistMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final IconData icon;
  final Color iconColor;

  const _ActivistMetricCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: iconColor, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            trend,
            style: TextStyle(fontSize: 9, color: iconColor.withOpacity(0.9), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// Helper desk action button
class _ActivistDeskButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActivistDeskButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper active campaign record card
class _ActiveCampaignRecord extends StatelessWidget {
  final String title;
  final String location;
  final String views;
  final double progress;
  final String status;
  final Color statusColor;

  const _ActiveCampaignRecord({
    required this.title,
    required this.location,
    required this.views,
    required this.progress,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                views,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(location, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF334155),
              color: statusColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF475569), size: 12),
            ],
          ),
        ],
      ),
    );
  }
}
