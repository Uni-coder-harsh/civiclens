import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_providers.dart';
import '../../../features/capture/data/capture_repository.dart';
import '../../../shared/defect.dart';
import '../../../shared/report_payload.dart';
import '../application/sync_controller.dart';
import '../data/draft_queue_repository.dart';
import '../../auth/application/auth_controller.dart';

// ── Internal state for the form ───────────────────────────────────────────────

class _ReportFormState {
  final ReportCategory? category;
  final ReportSeverity severity;
  final String description;
  final bool isLoadingDuplicates;
  final List<DuplicateMatch> duplicates;
  final bool isSubmitting;
  final String? errorMessage;
  final bool showGuidePanel;

  const _ReportFormState({
    this.category,
    this.severity = ReportSeverity.medium,
    this.description = '',
    this.isLoadingDuplicates = false,
    this.duplicates = const [],
    this.isSubmitting = false,
    this.errorMessage,
    this.showGuidePanel = false,
  });

  _ReportFormState copyWith({
    ReportCategory? category,
    ReportSeverity? severity,
    String? description,
    bool? isLoadingDuplicates,
    List<DuplicateMatch>? duplicates,
    bool? isSubmitting,
    String? errorMessage,
    bool? showGuidePanel,
  }) =>
      _ReportFormState(
        category: category ?? this.category,
        severity: severity ?? this.severity,
        description: description ?? this.description,
        isLoadingDuplicates: isLoadingDuplicates ?? this.isLoadingDuplicates,
        duplicates: duplicates ?? this.duplicates,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage: errorMessage,
        showGuidePanel: showGuidePanel ?? this.showGuidePanel,
      );
}

class _ReportFormNotifier extends Notifier<_ReportFormState> {
  @override
  _ReportFormState build() => const _ReportFormState();

  void setCategory(ReportCategory c) => state = state.copyWith(category: c);
  void setSeverity(ReportSeverity s) => state = state.copyWith(severity: s);
  void setDescription(String d) => state = state.copyWith(description: d);
  void toggleGuide() =>
      state = state.copyWith(showGuidePanel: !state.showGuidePanel);

  Future<void> checkDuplicates(double lat, double lng) async {
    state = state.copyWith(isLoadingDuplicates: true);
    try {
      final api = ref.read(apiClientProvider);
      final matches = await api.checkDuplicates(lat, lng, 10.0);
      state = state.copyWith(duplicates: matches, isLoadingDuplicates: false);
    } catch (_) {
      state = state.copyWith(isLoadingDuplicates: false, duplicates: []);
    }
  }

  Future<String?> submitDraft({
    required GeoCapture capture,
    required String imagePath,
    required String userId,
  }) async {
    if (state.category == null) {
      state = state.copyWith(errorMessage: 'Please select a category');
      return null;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    final id = const Uuid().v4();
    final payload = ReportPayload(
      id: id,
      userId: userId,
      category: state.category!,
      severity: state.severity,
      description: state.description,
      capture: capture,
      imagePath: imagePath,
      qualityGate: ImageQualityGate.ok,
      isGuest: false,
    );

    try {
      final repo = ref.read(draftQueueRepositoryProvider);
      final uploaded = await repo.saveDraft(payload);
      // Trigger background sync regardless
      await ref.read(syncControllerProvider.notifier).syncAll();
      state = state.copyWith(
        isSubmitting: false,
        // If not immediately uploaded, let the user know it's queued
        errorMessage: uploaded ? null : null, // pending is fine, not an error
      );
      return id;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Could not save report: $e',
      );
      return null;
    }
  }
}

final _reportFormProvider =
    NotifierProvider<_ReportFormNotifier, _ReportFormState>(
  _ReportFormNotifier.new,
);

// ── Report Form Page ──────────────────────────────────────────────────────────

/// Route: `/report/form`
///
/// Expects [GeoCapture] and image path passed via `state.extra` as
/// `Map<String, dynamic>` with keys `capture` and `imagePath`.
class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({super.key});

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final TextEditingController _descController = TextEditingController();
  bool _duplicatesChecked = false;

  late GeoCapture _capture;
  String _imagePath = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_duplicatesChecked) {
      // Read CaptureResult from route extra if available
      final extra = GoRouterState.of(context).extra;
      if (extra is CaptureResult) {
        // Passed directly from PreviewReviewPage
        _capture = extra.geoCapture;
        _imagePath = extra.watermarkedPath;
      } else if (extra is Map<String, dynamic>) {
        final captureJson = extra['capture'];
        if (captureJson != null) {
          _capture = GeoCapture.fromJson(captureJson as Map<String, dynamic>);
        } else {
          _capture = _fallbackCapture();
        }
        _imagePath = extra['imagePath'] as String? ?? '';
      } else {
        // Demo / fallback — Pune coords for mock data consistency
        _capture = _fallbackCapture();
      }
      _duplicatesChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(_reportFormProvider.notifier)
            .checkDuplicates(_capture.latitude, _capture.longitude);
      });
    }
  }

  GeoCapture _fallbackCapture() => GeoCapture(
        latitude: 18.5204,
        longitude: 73.8567,
        altitudeMeters: 558,
        accuracyMeters: 5,
        bearingDegrees: 0,
        speedMps: 0,
        capturedAtUtc: DateTime.now().toUtc(),
      );

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(_reportFormProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('File Report'),
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: formState.isSubmitting ? null : _submit,
            child: const Text('Submit',
                style: TextStyle(
                    color: Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Duplicate detection card
            if (formState.isLoadingDuplicates) _buildDuplicateLoader(),
            if (!formState.isLoadingDuplicates &&
                formState.duplicates.isNotEmpty)
              _DuplicateWarningCard(
                match: formState.duplicates.first,
                onAttach: () => _handleAttach(formState.duplicates.first),
                onReportAnyway: () {},
              ),
            const SizedBox(height: 20),

            // Critical fast-path banner
            if (formState.severity == ReportSeverity.critical)
              _CriticalBanner(),

            const SizedBox(height: 8),

            // Category dropdown
            const _SectionLabel('Category'),
            const SizedBox(height: 8),
            _CategoryDropdown(
              value: formState.category,
              onChanged: (c) =>
                  ref.read(_reportFormProvider.notifier).setCategory(c!),
            ),
            const SizedBox(height: 20),

            // Severity selector
            const _SectionLabel('Severity'),
            const SizedBox(height: 8),
            _SeveritySelector(
              current: formState.severity,
              onChanged: (s) =>
                  ref.read(_reportFormProvider.notifier).setSeverity(s),
            ),
            const SizedBox(height: 20),

            // Description
            const _SectionLabel('Description'),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLength: 500,
              maxLines: 5,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter'),
              decoration: InputDecoration(
                hintText: 'Describe the defect clearly…',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                counterStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF4F46E5), width: 2),
                ),
              ),
              onChanged: (v) =>
                  ref.read(_reportFormProvider.notifier).setDescription(v),
            ),
            const SizedBox(height: 16),

            // Collapsible guide panel
            if (formState.category != null)
              _CollapsibleGuidePanel(
                category: formState.category!,
                expanded: formState.showGuidePanel,
                onToggle: () =>
                    ref.read(_reportFormProvider.notifier).toggleGuide(),
              ),

            if (formState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFDC2626).withOpacity(0.4)),
                ),
                child: Text(
                  formState.errorMessage!,
                  style: const TextStyle(
                      color: Color(0xFFDC2626), fontFamily: 'Inter'),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Submit button
            ElevatedButton(
              onPressed: formState.isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: formState.isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface),
                    )
                  : const Text('Submit Report',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicateLoader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Row(
        children: [
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF4F46E5)),
          ),
          SizedBox(width: 12),
          Text('Checking for nearby duplicates…',
              style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Inter')),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final session = ref.read(authSessionProvider);
    final draftId = await ref.read(_reportFormProvider.notifier).submitDraft(
          capture: _capture,
          imagePath: _imagePath.isEmpty ? 'mock://placeholder' : _imagePath,
          userId: session.userId,
        );
    if (draftId != null && mounted) {
      context.go('/home/activity');
    }
  }

  Future<void> _handleAttach(DuplicateMatch match) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.attachToTicket('new', match.existingReportId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Attached as evidence to existing report')),
        );
        context.pop();
      }
    } catch (_) {}
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _CriticalBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Critical severity — this report will be immediately escalated to the front of the sync queue for priority processing.',
              style: TextStyle(
                color: Color(0xFFFCA5A5),
                fontFamily: 'Inter',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final ReportCategory? value;
  final ValueChanged<ReportCategory?> onChanged;

  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ReportCategory>(
          value: value,
          hint: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Select category',
                style:
                    TextStyle(color: Color(0xFF475569), fontFamily: 'Inter')),
          ),
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          items: ReportCategory.values
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(
                    _categoryLabel(c),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter', fontSize: 15),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
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

class _SeveritySelector extends StatelessWidget {
  final ReportSeverity current;
  final ValueChanged<ReportSeverity> onChanged;

  const _SeveritySelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ReportSeverity.values
          .map((s) => Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: current == s
                          ? _severityColor(s)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: current == s
                            ? _severityColor(s)
                            : const Color(0xFF334155),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(_severityIcon(s),
                            size: 18,
                            color: current == s
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B)),
                        const SizedBox(height: 4),
                        Text(
                          _severityLabel(s),
                          style: TextStyle(
                            color: current == s
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
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

  IconData _severityIcon(ReportSeverity s) {
    switch (s) {
      case ReportSeverity.low:
        return Icons.arrow_downward_rounded;
      case ReportSeverity.medium:
        return Icons.remove_rounded;
      case ReportSeverity.high:
        return Icons.arrow_upward_rounded;
      case ReportSeverity.critical:
        return Icons.priority_high_rounded;
    }
  }

  String _severityLabel(ReportSeverity s) {
    switch (s) {
      case ReportSeverity.low:
        return 'Low';
      case ReportSeverity.medium:
        return 'Med';
      case ReportSeverity.high:
        return 'High';
      case ReportSeverity.critical:
        return 'Critical';
    }
  }
}

class _DuplicateWarningCard extends StatelessWidget {
  final DuplicateMatch match;
  final VoidCallback onAttach;
  final VoidCallback onReportAnyway;

  const _DuplicateWarningCard({
    required this.match,
    required this.onAttach,
    required this.onReportAnyway,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Similar report found ${match.distanceMeters.toStringAsFixed(0)} m away',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image_rounded,
                      color: Color(0xFF64748B), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.status.name.replaceAllMapped(
                          RegExp(r'([A-Z])'),
                          (m) => ' ${m.group(1)}',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Report #${match.existingReportId.substring(0, 8)}',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onAttach,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Attach as evidence',
                        style: TextStyle(
                            color: Color(0xFF818CF8),
                            fontFamily: 'Inter',
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReportAnyway,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Report anyway',
                        style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                            fontSize: 13)),
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

class _CollapsibleGuidePanel extends StatelessWidget {
  final ReportCategory category;
  final bool expanded;
  final VoidCallback onToggle;

  const _CollapsibleGuidePanel({
    required this.category,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    color: Color(0xFF4F46E5), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Reporting guide',
                      style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontFamily: 'Inter',
                          fontSize: 13)),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _guideText(category),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2847),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined,
                          color: Color(0xFF60A5FA), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Privacy tip: Crop out faces and license plates before submitting.',
                          style: TextStyle(
                            color: Color(0xFF93C5FD),
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _guideText(ReportCategory c) {
    switch (c) {
      case ReportCategory.pothole:
        return 'Photograph the pothole from directly above, clearly showing its width and depth. Include a reference object (e.g. shoe) for scale.';
      case ReportCategory.roadCrack:
        return 'Capture the full extent of the crack. Show length and width. Multiple shots help if the crack spans a long distance.';
      case ReportCategory.bridgeDeck:
        return 'Photograph the deck surface defect at a low angle and from above. Include visible rebar exposure or spalling.';
      case ReportCategory.bridgePier:
        return 'Capture the full pier, highlighting cracks, efflorescence, or concrete spalling. Include context of the water line if present.';
      case ReportCategory.bridgeCrack:
        return 'Focus on the crack origin point and direction. Include a ruler or scale reference if possible.';
      case ReportCategory.guardrail:
        return 'Show the damaged section clearly, including bent or missing rails. Capture from both head-on and side angles.';
      case ReportCategory.manhole:
        return 'Photograph the sunken or raised manhole from directly above and from street level. Show gap with road surface.';
      case ReportCategory.other:
        return 'Provide clear, well-lit photos from multiple angles. Describe the defect type in the description field.';
    }
  }
}
