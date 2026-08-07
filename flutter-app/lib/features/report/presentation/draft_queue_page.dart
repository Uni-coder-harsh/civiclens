import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/report_payload.dart';
import '../application/sync_controller.dart';
import '../data/draft_queue_repository.dart';

// ── Draft Queue Page ──────────────────────────────────────────────────────────

/// Route: `/home/activity`
///
/// Displays all drafts with live [SyncState] badges and bulk/per-draft actions.
class DraftQueuePage extends ConsumerWidget {
  const DraftQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftStream = ref.watch(
      StreamProvider<List<ReportPayload>>((ref) {
        return ref.watch(draftQueueRepositoryProvider).watchPendingDrafts();
      }),
    );

    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Activity',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          syncState.whenOrNull(
                data: (s) => s.isSyncing
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () =>
                            ref.read(syncControllerProvider.notifier).syncAll(),
                        icon: const Icon(Icons.sync_rounded,
                            color: Color(0xFF4F46E5), size: 18),
                        label: const Text(
                          'Sync All',
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: draftStream.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Color(0xFF94A3B8))),
        ),
        data: (drafts) {
          if (drafts.isEmpty) {
            return _EmptyQueue();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: drafts.length,
            itemBuilder: (context, i) {
              final draft = drafts[i];
              return _DraftTile(draft: draft);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/capture'),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text('New Report',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Draft Tile ────────────────────────────────────────────────────────────────

class _DraftTile extends ConsumerWidget {
  final ReportPayload draft;

  const _DraftTile({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(draft.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Color(0xFFDC2626)),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: const Text('Delete draft?',
                    style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
                content: const Text('This action cannot be undone.',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontFamily: 'Inter')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete',
                        style: TextStyle(color: Color(0xFFDC2626))),
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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _CategoryIcon(category: draft.category),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _categoryLabel(draft.category),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _SeverityPip(severity: draft.severity),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${draft.capture.latitude.toStringAsFixed(4)}°, ${draft.capture.longitude.toStringAsFixed(4)}°',
                style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontFamily: 'Inter',
                    fontSize: 12),
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  _SyncBadge(syncState: SyncState.pending),
                ],
              ),
            ],
          ),
          trailing: draft.severity == ReportSeverity.critical
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.4)),
                  ),
                  child: const Text(
                    'CRITICAL',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
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

// ── Sync Badge ────────────────────────────────────────────────────────────────

class _SyncBadge extends StatelessWidget {
  final SyncState syncState;

  const _SyncBadge({required this.syncState});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _bgColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bgColor.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncState == SyncState.uploading)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF3B82F6),
                  ),
                )
              else
                Icon(_icon, size: 10, color: _bgColor),
              const SizedBox(width: 4),
              Text(
                _label,
                style: TextStyle(
                  color: _bgColor,
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color get _bgColor {
    switch (syncState) {
      case SyncState.pending:
        return const Color(0xFF94A3B8);
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
        return 'Failed';
    }
  }
}

// ── Category Icon ─────────────────────────────────────────────────────────────

class _CategoryIcon extends StatelessWidget {
  final ReportCategory category;

  const _CategoryIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_icon, color: const Color(0xFF818CF8), size: 22),
    );
  }

  IconData get _icon {
    switch (category) {
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
}

// ── Severity Pip ──────────────────────────────────────────────────────────────

class _SeverityPip extends StatelessWidget {
  final ReportSeverity severity;

  const _SeverityPip({required this.severity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: _color.withOpacity(0.5), blurRadius: 4)],
      ),
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
}

// ── Empty Queue ───────────────────────────────────────────────────────────────

class _EmptyQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF4F46E5), size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'All caught up!',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No pending drafts to sync.',
            style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }
}
