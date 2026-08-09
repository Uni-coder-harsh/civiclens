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
                          color: const Color(0xFF4F46E5).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
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
                    border: Border.all(color: const Color(0xFF3730A3).withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.15),
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
                                '${score.points} pts',
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
                          color: Colors.white.withOpacity(0.08),
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
                          borderColor: const Color(0xFFEC4899).withOpacity(0.3),
                          onTap: () => context.push('/capture'),
                        ),
                        _HubCard(
                          title: 'Explore Map',
                          subtitle: 'Live Defect Status',
                          icon: Icons.map_rounded,
                          iconColor: const Color(0xFF10B981),
                          gradientColors: const [Color(0xFF143A2F), Color(0xFF0F2620)],
                          borderColor: const Color(0xFF10B981).withOpacity(0.3),
                          onTap: () => context.push('/map'),
                        ),
                        _HubCard(
                          title: 'Contractors',
                          subtitle: 'View Passports',
                          icon: Icons.construction_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          gradientColors: const [Color(0xFF3F301D), Color(0xFF2B1F11)],
                          borderColor: const Color(0xFFF59E0B).withOpacity(0.3),
                          onTap: () => context.push('/contractor-search'),
                        ),
                        _HubCard(
                          title: 'Leaderboard',
                          subtitle: 'Top Contractors',
                          icon: Icons.leaderboard_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          gradientColors: const [Color(0xFF1E2D4B), Color(0xFF111C33)],
                          borderColor: const Color(0xFF3B82F6).withOpacity(0.3),
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
                    color: const Color(0xFF1E293B).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155).withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'COMMUNITY PROGRESS',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Text(
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

                      return _ActivityTile(
                        category: cleanCategory,
                        location: 'Lat: ${defect.latitude.toStringAsFixed(5)}, Lng: ${defect.longitude.toStringAsFixed(5)}',
                        status: defect.status.name,
                        statusColor: statusColor,
                        icon: defect.category == ReportCategory.bridge
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: iconColor, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
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
        color: const Color(0xFF1E293B).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF334155).withOpacity(0.5),
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
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
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
