import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/report_payload.dart';
import '../application/sync_controller.dart';
import '../data/draft_queue_repository.dart';

// ── Activity Page ─────────────────────────────────────────────────────────────

/// Route: `/home/activity`
///
/// Displays all drafts with live [SyncState] badges and bulk/per-draft actions.
class DraftQueuePage extends ConsumerStatefulWidget {
  const DraftQueuePage({super.key});

  @override
  ConsumerState<DraftQueuePage> createState() => _DraftQueuePageState();
}

class _DraftQueuePageState extends ConsumerState<DraftQueuePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncControllerProvider.notifier).syncAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(draftItemsStreamProvider);
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Activity',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                  ),
                ),
              ),
            ),
            actions: [
              syncState.whenOrNull(
                    data: (s) => s.isSyncing
                        ? const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Color(0xFF818CF8)),
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextButton.icon(
                              onPressed: () => ref
                                  .read(syncControllerProvider.notifier)
                                  .syncAll(),
                              icon: const Icon(
                                Icons.cloud_sync_rounded,
                                color: Color(0xFF818CF8),
                                size: 18,
                              ),
                              label: const Text(
                                'Sync',
                                style: TextStyle(
                                  color: Color(0xFF818CF8),
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                  ) ??
                  const SizedBox.shrink(),
            ],
          ),
          draftAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load drafts',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        e.toString(),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontFamily: 'Inter',
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const SliverFillRemaining(child: _EmptyState());
              }

              // Group by sync state for section headers
              final uploading = items
                  .where((d) => d.syncState == SyncState.uploading)
                  .toList();
              final failed =
                  items.where((d) => d.syncState == SyncState.failed).toList();
              final pending =
                  items.where((d) => d.syncState == SyncState.pending).toList();
              final synced =
                  items.where((d) => d.syncState == SyncState.synced).toList();

              final sections = <Widget>[];
              if (uploading.isNotEmpty) {
                sections.add(_SectionHeader(
                  label: 'Uploading',
                  icon: Icons.cloud_upload_rounded,
                  color: const Color(0xFF3B82F6),
                  count: uploading.length,
                ));
                sections.addAll(uploading.map((d) => _DraftCard(item: d)));
              }
              if (failed.isNotEmpty) {
                sections.add(_SectionHeader(
                  label: 'Failed',
                  icon: Icons.warning_rounded,
                  color: const Color(0xFFDC2626),
                  count: failed.length,
                ));
                sections.addAll(failed.map((d) => _DraftCard(item: d)));
              }
              if (pending.isNotEmpty) {
                sections.add(_SectionHeader(
                  label: 'Pending Sync',
                  icon: Icons.schedule_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
                  count: pending.length,
                ));
                sections.addAll(pending.map((d) => _DraftCard(item: d)));
              }
              if (synced.isNotEmpty) {
                sections.add(_SectionHeader(
                  label: 'Active & Synced Reports',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF22C55E),
                  count: synced.length,
                ));
                sections.addAll(synced.map((d) => _DraftCard(item: d)));
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => sections[index],
                    childCount: sections.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _NewReportFab(),
    );
  }
}

class _NewReportFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => context.push('/capture'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: Icon(Icons.add_a_photo_rounded,
            color: Theme.of(context).colorScheme.onSurface, size: 20),
        label: Text(
          'Report Issue',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Draft Card ────────────────────────────────────────────────────────────────

class _DraftCard extends ConsumerWidget {
  final DraftItem item;

  const _DraftCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = item.payload;

    return Dismissible(
      key: Key(draft.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(height: 4),
            Text('Delete',
                style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text('Delete draft?',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700)),
                content: const Text('This cannot be undone.',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontFamily: 'Inter')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFF64748B), fontFamily: 'Inter')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete',
                        style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        ref.read(draftQueueRepositoryProvider).deleteDraft(draft.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _borderColor(item.syncState).withOpacity(0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  _CategoryBadge(category: draft.category),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _categoryLabel(draft.category),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (draft.severity == ReportSeverity.critical)
                              _CriticalBadge(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 11, color: Color(0xFF64748B)),
                            const SizedBox(width: 3),
                            Text(
                              '${draft.capture.latitude.toStringAsFixed(4)}°, '
                              '${draft.capture.longitude.toStringAsFixed(4)}°',
                              style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontFamily: 'Inter',
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        if (draft.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            draft.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontFamily: 'Inter',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SeverityDot(severity: draft.severity),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _borderColor(item.syncState).withOpacity(0.06),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                    top: BorderSide(
                        color: _borderColor(item.syncState).withOpacity(0.15))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  _SyncChip(syncState: item.syncState),
                  const Spacer(),
                  // Retry button for failed or pending drafts
                  if (item.syncState == SyncState.failed ||
                      item.syncState == SyncState.pending)
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(syncControllerProvider.notifier)
                            .retryDraft(draft.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF4F46E5).withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 12, color: Color(0xFF818CF8)),
                            SizedBox(width: 4),
                            Text('Retry',
                                style: TextStyle(
                                    color: Color(0xFF818CF8),
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      DateFormat('MMM d · h:mm a')
                          .format(item.createdAtUtc.toLocal()),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontFamily: 'Inter',
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Delete button — always visible
                  GestureDetector(
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text('Delete report?',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700)),
                              content: const Text(
                                  'This will permanently remove the report.',
                                  style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontFamily: 'Inter')),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('Cancel',
                                      style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontFamily: 'Inter')),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('Delete',
                                      style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (confirmed) {
                        ref
                            .read(draftQueueRepositoryProvider)
                            .deleteDraft(draft.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFDC2626).withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 14, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _borderColor(SyncState s) {
    switch (s) {
      case SyncState.uploading:
        return const Color(0xFF3B82F6);
      case SyncState.failed:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF334155);
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

class _CriticalBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border:
            Border.all(color: const Color(0xFFDC2626).withOpacity(0.4)),
      ),
      child: const Text(
        'CRITICAL',
        style: TextStyle(
          color: Color(0xFFDC2626),
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Sync Chip ─────────────────────────────────────────────────────────────────

class _SyncChip extends StatelessWidget {
  final SyncState syncState;
  const _SyncChip({required this.syncState});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (syncState == SyncState.uploading)
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFF3B82F6)),
            ),
          )
        else
          Icon(_icon, size: 12, color: _color),
        const SizedBox(width: 5),
        Text(
          _label,
          style: TextStyle(
            color: _color,
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color get _color {
    switch (syncState) {
      case SyncState.pending:
        return const Color(0xFF64748B);
      case SyncState.uploading:
        return const Color(0xFF3B82F6);
      case SyncState.synced:
        return const Color(0xFF22C55E);
      case SyncState.failed:
        return const Color(0xFFDC2626);
    }
  }

  IconData get _icon {
    switch (syncState) {
      case SyncState.pending:
        return Icons.schedule_rounded;
      case SyncState.uploading:
        return Icons.cloud_upload_rounded;
      case SyncState.synced:
        return Icons.check_circle_rounded;
      case SyncState.failed:
        return Icons.error_rounded;
    }
  }

  String get _label {
    switch (syncState) {
      case SyncState.pending:
        return 'Pending sync';
      case SyncState.uploading:
        return 'Uploading…';
      case SyncState.synced:
        return 'Synced';
      case SyncState.failed:
        return 'Upload failed';
    }
  }
}

// ── Category Badge ────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final ReportCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.25)),
      ),
      child: Icon(_icon, color: _color, size: 22),
    );
  }

  Color get _color {
    switch (category) {
      case ReportCategory.bridgeDeck:
      case ReportCategory.bridgePier:
      case ReportCategory.bridgeCrack:
        return const Color(0xFFF59E0B);
      case ReportCategory.pothole:
        return const Color(0xFFEF4444);
      case ReportCategory.roadCrack:
        return const Color(0xFFF97316);
      case ReportCategory.manhole:
        return const Color(0xFF8B5CF6);
      case ReportCategory.guardrail:
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF6366F1);
    }
  }

  IconData get _icon {
    switch (category) {
      case ReportCategory.pothole:
        return Icons.circle_outlined;
      case ReportCategory.roadCrack:
        return Icons.show_chart_rounded;
      case ReportCategory.bridgeDeck:
      case ReportCategory.bridgePier:
      case ReportCategory.bridgeCrack:
        return Icons.account_balance_rounded;
      case ReportCategory.guardrail:
        return Icons.fence_rounded;
      case ReportCategory.manhole:
        return Icons.radio_button_checked_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

// ── Severity Dot ──────────────────────────────────────────────────────────────

class _SeverityDot extends StatelessWidget {
  final ReportSeverity severity;
  const _SeverityDot({required this.severity});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: _color.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1)
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _label,
          style: TextStyle(
            color: _color.withOpacity(0.8),
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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

  String get _label {
    switch (severity) {
      case ReportSeverity.low:
        return 'Low';
      case ReportSeverity.medium:
        return 'Med';
      case ReportSeverity.high:
        return 'High';
      case ReportSeverity.critical:
        return 'CRIT';
    }
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF312E81), Color(0xFF0F172A)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF4F46E5).withOpacity(0.3),
                  width: 1.5),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF818CF8),
              size: 42,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All clear!',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No reports pending sync.\nEverything is up to date.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          OutlinedButton.icon(
            onPressed: () => context.push('/capture'),
            icon: const Icon(Icons.add_a_photo_rounded, size: 18),
            label: const Text('Report an Issue',
                style: TextStyle(
                    fontFamily: 'Inter', fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF818CF8),
              side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
