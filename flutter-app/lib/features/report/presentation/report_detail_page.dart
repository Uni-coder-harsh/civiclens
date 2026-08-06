import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_providers.dart';
import '../../../shared/defect.dart';
import '../../../shared/escalation.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';
import '../../share/data/share_card_builder.dart';
import '../../share/presentation/share_sheet.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _reportDetailProvider = FutureProvider.family<_DetailData, String>(
  (ref, reportId) async {
    final api = ref.read(apiClientProvider);
    final defect = await api.fetchDefect(reportId);
    final timeline = await api.fetchReportTimeline(reportId);
    ResolutionMedia? resolution;
    try {
      resolution = await api.fetchResolution(reportId);
    } catch (_) {}
    return _DetailData(
      defect: defect,
      timeline: timeline,
      resolution: resolution,
    );
  },
);

class _DetailData {
  final NearbyDefect defect;
  final List<ReportEvent> timeline;
  final ResolutionMedia? resolution;

  const _DetailData({
    required this.defect,
    required this.timeline,
    this.resolution,
  });
}

// ── Shared Report Detail Page ─────────────────────────────────────────────────

/// Route: `/report/detail/:reportId`
///
/// Shared across all roles. Role-specific action sheets overlay on top via
/// the optional [actionSheetBuilder] slot.
class ReportDetailPage extends ConsumerWidget {
  final String reportId;

  /// Optional overlay builder for officer/contractor action sheets.
  final Widget Function(BuildContext, WidgetRef)? actionSheetBuilder;

  const ReportDetailPage({
    super.key,
    required this.reportId,
    this.actionSheetBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<_DetailData?>(
      _reportDetailProvider(reportId).select((v) => v.valueOrNull),
      (prev, next) async {
        if (next != null &&
            next.defect.status == DefectStatus.resolved &&
            (prev == null || prev.defect.status != DefectStatus.resolved)) {
          if (next.resolution != null) {
            final bytes = await buildShareCard(next.defect, next.resolution!);
            if (context.mounted) {
              ShareSheet.show(context, bytes);
            }
          }
        }
      },
    );

    final detailAsync = ref.watch(_reportDetailProvider(reportId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Report Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () async {
              final data =
                  ref.read(_reportDetailProvider(reportId)).valueOrNull;
              if (data != null && data.resolution != null) {
                final bytes =
                    await buildShareCard(data.defect, data.resolution!);
                if (context.mounted) {
                  ShareSheet.show(context, bytes);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report not yet resolved!')),
                );
              }
            },
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFF94A3B8), size: 48),
              const SizedBox(height: 16),
              Text('Failed to load: $e',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontFamily: 'Inter')),
            ],
          ),
        ),
        data: (data) => Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Report ID header
                  Text(
                    'Report #${reportId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontFamily: 'Inter',
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status + severity chips
                  _StatusRow(defect: data.defect),
                  const SizedBox(height: 20),

                  // AI Verdict Chip (mocked)
                  _AiVerdictCard(reportId: reportId),
                  const SizedBox(height: 16),

                  // Watermark Trust Badge
                  _WatermarkBadge(
                      watermarkVerified: data.defect.watermarkVerified),
                  const SizedBox(height: 16),

                  // SLA Clock
                  _SlaClockWidget(
                    sla: SlaClock(
                      stage: 'Verification',
                      deadlineUtc: DateTime.now().add(const Duration(days: 14)),
                      daysRemaining: 14,
                      norm: '14 days',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Audit Timeline
                  _AuditTimeline(events: data.timeline),
                  const SizedBox(height: 20),

                  // Before/After Resolution section
                  if (data.defect.status == DefectStatus.resolved &&
                      data.resolution != null)
                    _ResolutionComparison(resolution: data.resolution!),
                ],
              ),
            ),

            // Optional role-specific action sheet overlay
            if (actionSheetBuilder != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: actionSheetBuilder!(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final NearbyDefect defect;

  const _StatusRow({required this.defect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _StatusChip(
          label: _statusLabel(defect.status),
          color: _statusColor(defect.status),
        ),
        _StatusChip(
          label: defect.category.name,
          color: const Color(0xFF4F46E5),
        ),
      ],
    );
  }

  Color _statusColor(DefectStatus s) {
    switch (s) {
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
        return const Color(0xFF8E8E93);
      case DefectStatus.reopened:
        return const Color(0xFFFF3B30);
      case DefectStatus.closed:
        return const Color(0xFF8E8E93);
    }
  }

  String _statusLabel(DefectStatus s) {
    return s.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .trim();
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AiVerdictCard extends StatelessWidget {
  final String reportId;

  const _AiVerdictCard({required this.reportId});

  @override
  Widget build(BuildContext context) {
    // Seeded demo value based on reportId
    final confidence = 79 + (reportId.codeUnitAt(0) % 20);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4F46E5).withOpacity(0.15),
            const Color(0xFF0D9488).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Color(0xFF818CF8), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Verdict',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$confidence% Confidence',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Pothole',
                        style: TextStyle(
                          color: Color(0xFF818CF8),
                          fontFamily: 'Inter',
                          fontSize: 14,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatermarkBadge extends StatelessWidget {
  final bool watermarkVerified;

  const _WatermarkBadge({required this.watermarkVerified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: watermarkVerified
              ? const Color(0xFF22C55E).withOpacity(0.4)
              : const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          Icon(
            watermarkVerified
                ? Icons.verified_rounded
                : Icons.help_outline_rounded,
            color: watermarkVerified
                ? const Color(0xFF22C55E)
                : const Color(0xFF64748B),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  watermarkVerified
                      ? 'GPS & Time Verified'
                      : 'Watermark Pending',
                  style: TextStyle(
                    color: watermarkVerified
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF94A3B8),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '28.6139°N 77.2090°E · Alt 216 m · Bearing 0° · CivicLens v1.0',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontFamily: 'Inter',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlaClockWidget extends StatelessWidget {
  final SlaClock sla;

  const _SlaClockWidget({required this.sla});

  @override
  Widget build(BuildContext context) {
    final isUrgent = sla.daysRemaining <= 3;
    final color = isUrgent ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SLA: ${sla.stage}',
                      style: TextStyle(
                        color: color,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${sla.daysRemaining}d remaining',
                      style: TextStyle(
                        color: color,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Norm: ${sla.norm} · Deadline: ${_formatDate(sla.deadlineUtc)}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _AuditTimeline extends StatelessWidget {
  final List<ReportEvent> events;

  const _AuditTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AUDIT TIMELINE',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Text(
            'No events recorded.',
            style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Inter'),
          )
        else
          ...events.asMap().entries.map((entry) {
            final i = entry.key;
            final event = entry.value;
            final isLast = i == events.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline line + dot
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _actionColor(event.action),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    _actionColor(event.action).withOpacity(0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: const Color(0xFF334155),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _actionLabel(event.action),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                _formatTime(event.atUtc),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${event.actorLabel} (${event.actorRole.name})',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontFamily: 'Inter',
                              fontSize: 12,
                            ),
                          ),
                          if (event.note != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.note!,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Color _actionColor(TicketAction a) {
    switch (a) {
      case TicketAction.created:
        return const Color(0xFF4F46E5);
      case TicketAction.aiVerdict:
        return const Color(0xFF8B5CF6);
      case TicketAction.verify:
        return const Color(0xFF0D9488);
      case TicketAction.assign:
        return const Color(0xFF007AFF);
      case TicketAction.reject:
        return const Color(0xFFDC2626);
      case TicketAction.approve:
        return const Color(0xFF22C55E);
      case TicketAction.escalate:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _actionLabel(TicketAction a) {
    return a.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .trim()
        .toUpperCase();
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ResolutionComparison extends StatelessWidget {
  final ResolutionMedia resolution;

  const _ResolutionComparison({required this.resolution});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RESOLUTION',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: Color(0xFF64748B), size: 32),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Before',
                      style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontFamily: 'Inter',
                          fontSize: 12)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFF22C55E), size: 20),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF22C55E).withOpacity(0.4)),
                    ),
                    child: const Center(
                      child: Icon(Icons.check_circle_rounded,
                          color: Color(0xFF22C55E), size: 32),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('After',
                      style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontFamily: 'Inter',
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        if (resolution.contractorNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            resolution.contractorNote,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontFamily: 'Inter',
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}
