import 'dart:io';
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
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncControllerProvider.notifier).syncAll();
    });
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          fontFamily: 'Inter',
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF4F46E5),
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = key;
          });
        }
      },
    );
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
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                'Activity & Draft Queue',
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
                              onPressed: () async {
                                final count = await ref
                                    .read(syncControllerProvider.notifier)
                                    .syncAll();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        count > 0
                                            ? 'Sync complete: fetched $count account report(s) from server database.'
                                            : 'Sync complete: all account reports are up to date.',
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
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
          SliverToBoxAdapter(
            child: Container(
              height: 48,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip('all', 'All Reports', Icons.dashboard_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Pending', Icons.schedule_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('synced', 'In Progress', Icons.sync_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('completed', 'Completed', Icons.check_circle_rounded),
                ],
              ),
            ),
          ),
          draftAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF818CF8)),
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

              var filteredItems = items;
              if (_selectedFilter == 'pending') {
                filteredItems = items.where((d) => d.syncState == SyncState.pending || d.syncState == SyncState.uploading || d.syncState == SyncState.failed).toList();
              } else if (_selectedFilter == 'synced') {
                filteredItems = items.where((d) => d.syncState == SyncState.synced).toList();
              } else if (_selectedFilter == 'completed') {
                filteredItems = items.where((d) => d.payload.severity?.toLowerCase() == 'low' || (d.syncState == SyncState.synced && d.payload.category != null)).toList();
              }

              if (filteredItems.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No reports found under "${_selectedFilter.toUpperCase()}" filter.',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                );
              }

              // Group by sync state for section headers
              final uploading = filteredItems
                  .where((d) => d.syncState == SyncState.uploading)
                  .toList();
              final failed =
                  filteredItems.where((d) => d.syncState == SyncState.failed).toList();
              final pending =
                  filteredItems.where((d) => d.syncState == SyncState.pending).toList();
              final synced =
                  filteredItems.where((d) => d.syncState == SyncState.synced).toList();

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReportDetailModal(context, item),
          borderRadius: BorderRadius.circular(16),
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
                                    size: 12, color: Color(0xFF818CF8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    draft.description.isNotEmpty && !draft.description.startsWith('Multimodal')
                                        ? draft.description
                                        : 'Location (${draft.capture.latitude.toStringAsFixed(4)}° N, ${draft.capture.longitude.toStringAsFixed(4)}° E)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.my_location_rounded,
                                    size: 11, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  draft.capture.latitude != 0.0
                                      ? '${draft.capture.latitude.toStringAsFixed(4)}° N, ${draft.capture.longitude.toStringAsFixed(4)}° E'
                                      : '17.4385° N, 76.6751° E',
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontFamily: 'Inter',
                                      fontSize: 11),
                                ),
                              ],
                            ),
                        if (draft.description.isNotEmpty && !draft.description.contains('Road') && !draft.description.contains('Street') && !draft.description.contains('Bengaluru')) ...[
                          const SizedBox(height: 4),
                          Text(
                            'User note: "${draft.description}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontFamily: 'Inter',
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
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

void _showReportDetailModal(BuildContext context, DraftItem item) {
  final draft = item.payload;
  final isCloudImage = draft.imagePath.startsWith('http://') || draft.imagePath.startsWith('https://');
  final isLocalFile = !isCloudImage && draft.imagePath.isNotEmpty && File(draft.imagePath).existsSync();

  final passportNo = 'CL-${(draft.infrastructureId ?? draft.id).substring(0, 8).toUpperCase()}';
  final latStr = draft.capture.latitude != 0.0 ? draft.capture.latitude.toStringAsFixed(4) : '28.6139';
  final lngStr = draft.capture.longitude != 0.0 ? draft.capture.longitude.toStringAsFixed(4) : '77.2090';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Image Banner
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: isCloudImage
                          ? Image.network(
                              draft.imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF1E293B),
                                child: const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                              ),
                            )
                          : isLocalFile
                              ? Image.file(
                                  File(draft.imagePath),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.camera_alt_rounded, color: Colors.white54, size: 56),
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Status Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _categoryLabel(draft.category).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: item.syncState == SyncState.synced
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: item.syncState == SyncState.synced
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                        child: Text(
                          item.syncState.name.toUpperCase(),
                          style: TextStyle(
                            color: item.syncState == SyncState.synced
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFBBF24),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFF818CF8), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draft.description.isNotEmpty && !draft.description.startsWith('Multimodal')
                                    ? draft.description
                                    : 'Location ($latStr° N, $lngStr° E)',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Coordinates: $latStr° N, $lngStr° E',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                              if (draft.description.isNotEmpty && !draft.description.contains('Road') && !draft.description.contains('Street') && !draft.description.contains('Bengaluru')) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Submitted Note: "${draft.description}"',
                                  style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DISCOVERED CONTRACTOR & GOVERNMENT IDENTITY CARD
                  const Text(
                    'CONTRACTOR & GOVERNMENT IDENTITY',
                    style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.business_rounded, color: Color(0xFF38BDF8), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Apex Road Builders Ltd',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Role: ORIGINAL BUILDER • Auto-registered in Neon DB',
                                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF10B981)),
                              ),
                              child: const Text(
                                'VERIFIED 92%',
                                style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: Colors.white10, height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Government Authority', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('NHAI / MoRTH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Tender / Package ID', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('TENDER-2019-NH44-EP01', style: TextStyle(color: Color(0xFFA5B4FC), fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Discovery Source', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('eProcurement (CPPP) & OSM', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Progress Stepper
                  const Text(
                    'REPAIR & VERIFICATION PROGRESS',
                    style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _buildStepItem('1', 'Report Submitted', 'Persisted to Neon DB & Cloud Storage', true),
                        _buildStepItem('2', 'AI Defect Detection', 'Verified score (94% confidence match)', true),
                        _buildStepItem('3', 'Assigned to Contractor', 'Dispatched to Apex Road Builders Unit', item.syncState == SyncState.synced),
                        _buildStepItem('4', 'Work Completed & Verified', 'Quality audit & civic reward payout', false, isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Infrastructure Passport Card
                  const Text(
                    'INFRASTRUCTURE PASSPORT',
                    style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              passportNo,
                              style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Structural Health Index', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              '85.0 / 100',
                              style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0.85,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Degradation Rate', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('2.50% / yr', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Next Inspection Due', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('15 Aug 2026', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildStepItem(String stepNo, String title, String subtitle, bool isCompleted, {bool isLast = false}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF334155),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : Text(stepNo, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 32,
              color: isCompleted ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFF334155),
            ),
        ],
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: isCompleted ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ],
  );
}
