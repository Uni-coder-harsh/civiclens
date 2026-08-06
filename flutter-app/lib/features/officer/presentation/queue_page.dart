import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/forbidden_state.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';
import '../application/officer_queue_provider.dart';

/// Route: `/officer/queue`
///
/// Triage queue screen for officers — filterable by [DefectStatus] and zone.
class OfficerQueuePage extends ConsumerWidget {
  const OfficerQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(officerQueueProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Officer Queue',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(officerQueueProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(),
          Expanded(
            child: queueAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              ),
              error: (e, _) {
                if (e is ForbiddenException) {
                  return const ForbiddenState(
                    requiredRole: 'officer',
                    action: 'view officer queue',
                  );
                }
                return Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Color(0xFF94A3B8))),
                );
              },
              data: (tickets) {
                if (tickets.isEmpty) {
                  return _EmptyQueue();
                }
                return RefreshIndicator(
                  color: const Color(0xFF4F46E5),
                  onRefresh: () =>
                      ref.read(officerQueueProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: tickets.length,
                    itemBuilder: (context, i) =>
                        _TicketCard(ticket: tickets[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chips ──────────────────────────────────────────────────────────────

class _FilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = [
      (label: 'All', status: null),
      (label: 'Submitted', status: DefectStatus.submitted),
      (label: 'AI Verified', status: DefectStatus.aiVerified),
      (label: 'Await Acceptance', status: DefectStatus.awaitAcceptance),
    ];

    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters
              .map(
                (f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(label: f.label, status: f.status),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _FilterChip extends ConsumerWidget {
  final String label;
  final DefectStatus? status;

  const _FilterChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine if this chip is active by comparing with the current filter
    // We use a simple state holder approach via the notifier
    return GestureDetector(
      onTap: () {
        if (status == null) {
          ref
              .read(officerQueueProvider.notifier)
              .applyFilter(clearStatus: true);
        } else {
          ref.read(officerQueueProvider.notifier).applyFilter(status: status);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF818CF8),
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Ticket Card ───────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final TicketSummary ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/officer/report/${ticket.reportId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ticket.severity == ReportSeverity.critical
                ? const Color(0xFFDC2626).withOpacity(0.4)
                : const Color(0xFF334155),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail / Category icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _severityColor(ticket.severity).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _severityColor(ticket.severity).withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  _categoryIcon(ticket.category),
                  color: _severityColor(ticket.severity),
                  size: 26,
                ),
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
                        _SeverityBadge(severity: ticket.severity),
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
                        const Spacer(),
                        Text(
                          '${ticket.daysInStatus}d in status',
                          style: TextStyle(
                            color: ticket.daysInStatus > 7
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusPill(status: ticket.status),
                        const SizedBox(width: 8),
                        if (ticket.watermarkVerified) const _VerifiedBadge(),
                        if ((ticket.aiConfidence) > 0) ...[
                          const Spacer(),
                          Text(
                            '${(ticket.aiConfidence * 100).round()}% AI',
                            style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
      ),
    );
  }

  Color _severityColor(ReportSeverity s) {
    switch (s) {
      case ReportSeverity.low:
        return const Color(0xFF22C55E);
      case ReportSeverity.medium:
        return const Color(0xFFF59E0B);
      case ReportSeverity.high:
        return const Color(0xFFF97316);
      case ReportSeverity.critical:
        return const Color(0xFFDC2626);
    }
  }

  IconData _categoryIcon(ReportCategory c) {
    switch (c) {
      case ReportCategory.pothole:
        return Icons.circle_outlined;
      case ReportCategory.roadCrack:
        return Icons.timeline_rounded;
      case ReportCategory.bridgeDeck:
      case ReportCategory.bridgePier:
      case ReportCategory.bridgeCrack:
        return Icons.account_balance_rounded;
      case ReportCategory.guardrail:
        return Icons.fence_rounded;
      case ReportCategory.manhole:
        return Icons.radio_button_checked_rounded;
      case ReportCategory.other:
        return Icons.help_outline_rounded;
    }
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

class _SeverityBadge extends StatelessWidget {
  final ReportSeverity severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String get _label {
    switch (severity) {
      case ReportSeverity.low:
        return 'LOW';
      case ReportSeverity.medium:
        return 'MED';
      case ReportSeverity.high:
        return 'HIGH';
      case ReportSeverity.critical:
        return 'CRITICAL';
    }
  }

  Color get _color {
    switch (severity) {
      case ReportSeverity.low:
        return const Color(0xFF22C55E);
      case ReportSeverity.medium:
        return const Color(0xFFF59E0B);
      case ReportSeverity.high:
        return const Color(0xFFF97316);
      case ReportSeverity.critical:
        return const Color(0xFFDC2626);
    }
  }
}

class _StatusPill extends StatelessWidget {
  final DefectStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String get _label => status.name
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
      .trim();

  Color get _color {
    switch (status) {
      case DefectStatus.submitted:
      case DefectStatus.underReview:
        return const Color(0xFFFFBF00);
      case DefectStatus.aiVerified:
        return const Color(0xFFFF7F00);
      case DefectStatus.assigned:
      case DefectStatus.inProgress:
        return const Color(0xFF007AFF);
      case DefectStatus.awaitAcceptance:
        return const Color(0xFF00C7BE);
      case DefectStatus.resolved:
        return const Color(0xFF34C759);
      case DefectStatus.rejected:
      case DefectStatus.closed:
        return const Color(0xFF8E8E93);
      case DefectStatus.reopened:
        return const Color(0xFFFF3B30);
    }
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 12),
        SizedBox(width: 3),
        Text(
          'Verified',
          style: TextStyle(
            color: Color(0xFF22C55E),
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all_rounded, color: Color(0xFF22C55E), size: 56),
          SizedBox(height: 16),
          Text('Queue is clear!',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('No tickets require your attention.',
              style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Inter')),
        ],
      ),
    );
  }
}
