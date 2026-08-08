import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/forbidden_state.dart';
import '../../../shared/report_payload.dart';
import '../../../shared/ticket.dart';
import '../application/officer_queue_provider.dart';
import 'queue_page.dart' show OfficerTicketCard;

/// Route: `/officer/dashboard`
///
/// Full triage command view for officers — extends the basic queue with
/// zone filtering and analytics panels.
class TriageDashboardPage extends ConsumerStatefulWidget {
  const TriageDashboardPage({super.key});

  @override
  ConsumerState<TriageDashboardPage> createState() => _TriageDashboardPageState();
}

class _TriageDashboardPageState extends ConsumerState<TriageDashboardPage> {
  String _selectedZone = 'All Zones';
  final List<String> _zones = ['All Zones', 'Deccan Gymkhana', 'Kothrud', 'Hinjewadi'];

  @override
  void initState() {
    super.initState();
    // Reset filter when entering dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(officerQueueProvider.notifier).applyFilter(clearStatus: true, zone: null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(officerQueueProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Triage Command',
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
          _buildZoneHeader(),
          queueAsync.when(
            data: (tickets) => _buildAnalyticsRow(tickets),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: queueAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              ),
              error: (e, _) {
                if (e is ForbiddenException) {
                  return const ForbiddenState(
                    requiredRole: 'officer',
                    action: 'view triage dashboard',
                  );
                }
                return Center(
                  child: Text('Error: $e',
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8))),
                );
              },
              data: (tickets) {
                if (tickets.isEmpty) {
                  return const Center(child: Text('No tickets found for this zone.'));
                }
                return RefreshIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  onRefresh: () =>
                      ref.read(officerQueueProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: tickets.length,
                    itemBuilder: (context, i) =>
                        OfficerTicketCard(ticket: tickets[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneHeader() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, color: Color(0xFF818CF8)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedZone,
                isExpanded: true,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                items: _zones.map((zone) {
                  return DropdownMenuItem(
                    value: zone,
                    child: Text(zone),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedZone = val;
                    });
                    ref.read(officerQueueProvider.notifier).applyFilter(
                          zone: val == 'All Zones' ? null : val,
                        );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(List<TicketSummary> tickets) {
    final aiVerifiedCount = tickets.where((t) => t.status == DefectStatus.aiVerified).length;
    final assignedCount = tickets.where((t) => t.status == DefectStatus.assigned).length;
    final escalatedCount = tickets.where((t) => t.slaClock != null && t.slaClock!.daysRemaining <= 0).length;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatChip(
            label: 'AI Verified',
            count: aiVerifiedCount,
            color: const Color(0xFFF59E0B),
            icon: Icons.auto_awesome,
          ),
          _StatChip(
            label: 'Assigned',
            count: assignedCount,
            color: const Color(0xFF3B82F6),
            icon: Icons.engineering,
          ),
          _StatChip(
            label: 'Escalated',
            count: escalatedCount,
            color: const Color(0xFFEF4444),
            icon: Icons.warning_amber_rounded,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
