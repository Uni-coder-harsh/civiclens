import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/ticket.dart';
import '../../report/presentation/report_detail_page.dart';
import '../data/officer_repository.dart';

// ── Officer Ticket Page ───────────────────────────────────────────────────────

/// Route: `/officer/report/:reportId`
///
/// Renders the shared [ReportDetailPage] with the officer action sheet overlay.
class OfficerTicketPage extends ConsumerWidget {
  final String reportId;

  const OfficerTicketPage({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReportDetailPage(
      reportId: reportId,
      actionSheetBuilder: (ctx, ref) =>
          OfficerTicketActionSheet(reportId: reportId),
    );
  }
}

// ── Officer Ticket Action Sheet ────────────────────────────────────────────────

/// Bottom sheet overlay rendered on the officer's report detail view.
///
/// Actions: Verify On-Site, Verify from Photos, Assign Contractor,
///          Reject (reason required), Approve Resolution.
class OfficerTicketActionSheet extends ConsumerStatefulWidget {
  final String reportId;

  const OfficerTicketActionSheet({super.key, required this.reportId});

  @override
  ConsumerState<OfficerTicketActionSheet> createState() =>
      _OfficerTicketActionSheetState();
}

class _OfficerTicketActionSheetState
    extends ConsumerState<OfficerTicketActionSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OFFICER ACTIONS',
                    style: TextStyle(
                      color: Color(0xFF818CF8),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(
                color: Color(0xFF4F46E5),
                backgroundColor: Color(0xFF334155),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.location_on_rounded,
                        label: 'Verify On-Site',
                        color: const Color(0xFF0D9488),
                        onTap: _isLoading ? null : _verifyOnSite,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Verify from Photos',
                        color: const Color(0xFF4F46E5),
                        onTap: _isLoading ? null : _verifyFromPhotos,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.engineering_rounded,
                        label: 'Assign Contractor',
                        color: const Color(0xFFD97706),
                        onTap: _isLoading ? null : _assignContractor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.check_circle_rounded,
                        label: 'Approve Resolution',
                        color: const Color(0xFF22C55E),
                        onTap: _isLoading ? null : _approveResolution,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.cancel_rounded,
                  label: 'Reject Report',
                  color: const Color(0xFFDC2626),
                  onTap: _isLoading ? null : _rejectReport,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardedAction(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action completed successfully'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } on ForbiddenException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Access Denied',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
            content: Text(e.toString(),
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontFamily: 'Inter')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK',
                    style: TextStyle(color: Color(0xFF4F46E5))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOnSite() => _guardedAction(() async {
        final repo = ref.read(officerRepositoryProvider);
        await repo.verifyReport(widget.reportId,
            fromSite: true, note: 'On-site verification completed');
      });

  Future<void> _verifyFromPhotos() => _guardedAction(() async {
        final repo = ref.read(officerRepositoryProvider);
        await repo.verifyReport(widget.reportId,
            fromSite: false, note: 'Photo review completed');
      });

  Future<void> _assignContractor() async {
    final contractorId = await showDialog<String>(
      context: context,
      builder: (ctx) => _AssignContractorDialog(),
    );
    if (contractorId == null || contractorId.isEmpty) return;
    await _guardedAction(() async {
      final repo = ref.read(officerRepositoryProvider);
      await repo.assignContractor(
        widget.reportId,
        contractorId: contractorId,
        slaDays: 30,
      );
    });
  }

  Future<void> _rejectReport() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _RejectDialog(),
    );
    if (reason == null || reason.isEmpty) return;
    await _guardedAction(() async {
      final repo = ref.read(officerRepositoryProvider);
      await repo.rejectReport(widget.reportId, reason: reason);
    });
  }

  Future<void> _approveResolution() => _guardedAction(() async {
        final repo = ref.read(officerRepositoryProvider);
        await repo.approveResolution(widget.reportId);
      });
}

// ── Sub-dialogs ───────────────────────────────────────────────────────────────

class _AssignContractorDialog extends StatefulWidget {
  @override
  State<_AssignContractorDialog> createState() =>
      _AssignContractorDialogState();
}

class _AssignContractorDialogState extends State<_AssignContractorDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Assign Contractor',
          style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _controller,
        style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
        decoration: InputDecoration(
          hintText: 'Enter contractor ID…',
          hintStyle: const TextStyle(color: Color(0xFF475569)),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5)),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Reject Report',
          style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
        decoration: InputDecoration(
          hintText: 'Enter rejection reason (required)…',
          hintStyle: const TextStyle(color: Color(0xFF475569)),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626)),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool fullWidth;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment:
                fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
