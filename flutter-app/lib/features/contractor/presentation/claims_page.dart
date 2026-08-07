import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/forbidden_state.dart';
import '../../../shared/escalation.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';
import '../application/claims_provider.dart';

/// Route: `/contractor/claims`
///
/// Displays the contractor's active claims with color-coded SLA countdown
/// indicators. Tap a card navigates to `/contractor/ticket/{id}`.
class ContractorClaimsPage extends ConsumerWidget {
  const ContractorClaimsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(claimsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('My Claims',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(claimsProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: claimsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
        error: (e, _) {
          if (e is ForbiddenException) {
            return const ForbiddenState(
              requiredRole: 'contractor',
              action: 'view contractor claims',
            );
          }
          return Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Color(0xFF94A3B8))),
          );
        },
        data: (claims) {
          if (claims.isEmpty) {
            return _EmptyClaims();
          }
          return RefreshIndicator(
            color: const Color(0xFF4F46E5),
            onRefresh: () => ref.read(claimsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: claims.length,
              itemBuilder: (context, i) => _ClaimCard(ticket: claims[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Claim Card ────────────────────────────────────────────────────────────────

class _ClaimCard extends StatelessWidget {
  final TicketSummary ticket;

  const _ClaimCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final sla = ticket.slaClock;
    final slaColor = _slaColor(sla);

    return GestureDetector(
      onTap: () => context.push('/contractor/ticket/${ticket.reportId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: slaColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // SLA countdown bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: slaColor.withOpacity(0.3),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _slaProgress(sla),
                child: Container(
                  decoration: BoxDecoration(
                    color: slaColor,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.engineering_rounded,
                        color: Color(0xFF818CF8), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _categoryLabel(ticket.category),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (sla != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: slaColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: slaColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  '${sla.daysRemaining}d left',
                                  style: TextStyle(
                                    color: slaColor,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 3),
                            Text(
                              ticket.zone,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontFamily: 'Inter',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // ANONYMITY — always show "Reported by: Citizen"
                        const Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 12, color: Color(0xFF64748B)),
                            SizedBox(width: 3),
                            Text(
                              'Reported by: Citizen',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF64748B), size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _slaColor(SlaClock? sla) {
    if (sla == null) return const Color(0xFF64748B);
    if (sla.daysRemaining <= 2) return const Color(0xFFDC2626); // red
    if (sla.daysRemaining <= 7) return const Color(0xFFF59E0B); // orange
    return const Color(0xFF22C55E); // green
  }

  double _slaProgress(SlaClock? sla) {
    if (sla == null) return 0.5;
    // Parse norm like "30 days"
    final normDays = int.tryParse(sla.norm.split(' ').first) ?? 30;
    final elapsed = normDays - sla.daysRemaining;
    return (elapsed / normDays).clamp(0.0, 1.0);
  }

  String _categoryLabel(ReportCategory c) {
    switch (c) {
      case ReportCategory.pothole:
        return 'Pothole';
      case ReportCategory.roadCrack:
        return 'Road Crack';
      case ReportCategory.bridgeDeck:
        return 'Bridge Deck';
      case ReportCategory.bridgePier:
        return 'Bridge Pier';
      case ReportCategory.bridgeCrack:
        return 'Bridge Crack';
      case ReportCategory.guardrail:
        return 'Guardrail';
      case ReportCategory.manhole:
        return 'Manhole';
      case ReportCategory.other:
        return 'Other';
    }
  }
}

class _EmptyClaims extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, color: Color(0xFF4F46E5), size: 56),
          SizedBox(height: 16),
          Text('No active claims',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('Browse the map to find and claim tickets.',
              style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Inter')),
        ],
      ),
    );
  }
}
