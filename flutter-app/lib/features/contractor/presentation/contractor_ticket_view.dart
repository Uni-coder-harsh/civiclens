import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/ticket.dart';
import '../../report/presentation/report_detail_page.dart';
import '../data/contractor_claim_repository.dart';

// ── Contractor Ticket View ────────────────────────────────────────────────────

/// Route: `/contractor/ticket/:reportId`
///
/// Renders the shared [ReportDetailPage] with the contractor action sheet overlay.
/// Enforces citizen anonymity — never exposes reporter identity.
class ContractorTicketView extends ConsumerWidget {
  final String reportId;

  const ContractorTicketView({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReportDetailPage(
      reportId: reportId,
      actionSheetBuilder: (ctx, ref) =>
          _ContractorActionSheet(reportId: reportId),
    );
  }
}

// ── Contractor Action Sheet ───────────────────────────────────────────────────

class _ContractorActionSheet extends ConsumerStatefulWidget {
  final String reportId;

  const _ContractorActionSheet({required this.reportId});

  @override
  ConsumerState<_ContractorActionSheet> createState() =>
      _ContractorActionSheetState();
}

class _ContractorActionSheetState
    extends ConsumerState<_ContractorActionSheet> {
  bool _isLoading = false;
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
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
                color: Theme.of(context).dividerColor,
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
                    color: const Color(0xFFD97706).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CONTRACTOR ACTIONS',
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                // Anonymity indicator
                Row(
                  children: [
                    Icon(Icons.shield_rounded,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Reported by: Citizen',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: LinearProgressIndicator(
                color: const Color(0xFFD97706),
                backgroundColor: Theme.of(context).dividerColor,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.handshake_rounded,
                        label: 'Claim Ticket',
                        color: const Color(0xFF0D9488),
                        onTap: _isLoading ? null : _claimTicket,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.add_a_photo_rounded,
                        label: 'Upload After-Photo',
                        color: Theme.of(context).colorScheme.primary,
                        onTap: _isLoading ? null : _uploadAfterPhoto,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Reply text field
                TextField(
                  controller: _replyController,
                  maxLines: 2,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add right of reply…',
                    hintStyle:
                        const TextStyle(color: Color(0xFF475569), fontSize: 13),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Color(0xFFD97706)),
                      onPressed: _isLoading ? null : _submitReply,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
            content: Text('Done!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } on ForbiddenException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text('Access Denied',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter')),
            content: Text(e.toString(),
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8), fontFamily: 'Inter')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _claimTicket() => _guardedAction(() async {
        final repo = ref.read(contractorClaimRepositoryProvider);
        await repo.claimTicket(widget.reportId);
      });

  Future<void> _uploadAfterPhoto() => _guardedAction(() async {
        // Upload after-photo — runs through watermark+EXIF pipeline
        // In production: launches camera → CaptureResult → WatermarkPayload
        final repo = ref.read(contractorClaimRepositoryProvider);
        await repo.submitResolutionMedia(
          widget.reportId,
          ResolutionMedia(
            reportId: widget.reportId,
            afterPhotoUrls: ['placeholder_after.jpg'],
            contractorNote: 'After-photo submitted',
            resolvedAtUtc: DateTime.now().toUtc(),
          ),
        );
      });

  Future<void> _submitReply() async {
    final body = _replyController.text.trim();
    if (body.isEmpty) return;
    await _guardedAction(() async {
      final repo = ref.read(contractorClaimRepositoryProvider);
      await repo.submitContractorReply(
        widget.reportId,
        ContractorReply(
          replyId: const Uuid().v4(),
          contractorId: 'demo-contractor',
          reportId: widget.reportId,
          body: body,
          isPublic: true,
          atUtc: DateTime.now().toUtc(),
        ),
      );
      _replyController.clear();
    });
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
