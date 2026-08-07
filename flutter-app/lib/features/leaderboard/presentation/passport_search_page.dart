import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contractor.dart';
import '../application/leaderboard_controller.dart';

/// Route: `/contractor-search`
///
/// Dedicated search & lookup page for contractor passports.
/// Live search, grade filtering, and instant navigation to the passport.
class PassportSearchPage extends ConsumerStatefulWidget {
  const PassportSearchPage({super.key});

  @override
  ConsumerState<PassportSearchPage> createState() => _PassportSearchPageState();
}

class _PassportSearchPageState extends ConsumerState<PassportSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(leaderboardControllerProvider);
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Contractor Passports',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Passport QR',
            onPressed: () {
              // Direct demonstration QR scan simulation
              _showQrScanDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: isLight
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF334155),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _query = val.trim().toLowerCase();
                    });
                  },
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Inter',
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by contractor name or ID…',
                    hintStyle: TextStyle(
                      color: isLight
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isLight
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verify public accountability records, warranties & defect ratings',
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Results List ───────────────────────────────────────────────────
          Expanded(
            child: asyncData.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error loading contractors: $e',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ),
              data: (contractors) {
                final filtered = contractors.where((c) {
                  return c.companyName.toLowerCase().contains(_query) ||
                      c.contractorId.toLowerCase().contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: isLight
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No contractors found for "$_query"',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _ContractorPassportCard(
                      summary: item,
                      onTap: () {
                        context.push('/contractors/${item.contractorId}');
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showQrScanDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner_rounded,
                  size: 48, color: Color(0xFF4F46E5)),
              const SizedBox(height: 16),
              const Text(
                'Scan Contractor Passport QR',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aim your camera at the QR code displayed on the contractor\'s badge or official project board.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/contractors/ctr_pune_infra');
                },
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text('Open Sample Verified Passport'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Contractor Passport Card ──────────────────────────────────────────────────

class _ContractorPassportCard extends StatelessWidget {
  final ContractorSummary summary;
  final VoidCallback onTap;

  const _ContractorPassportCard({
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isLight ? 0.04 : 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar / Rating badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 16),
                    Text(
                      summary.grade.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          summary.companyName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (summary.kycVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF3B82F6),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${summary.completedProjects} Projects',
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                          fontFamily: 'Inter',
                          fontSize: 12,
                        ),
                      ),
                      const Text(' • ', style: TextStyle(color: Color(0xFF64748B))),
                      Text(
                        '${summary.activeDefects} Active Defects',
                        style: TextStyle(
                          color: summary.activeDefects > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isLight
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
