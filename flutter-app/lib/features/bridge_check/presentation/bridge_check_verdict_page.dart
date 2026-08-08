import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/vibration_payload.dart';
import '../application/bridge_check_controller.dart';

/// Route: `/bridge-check/verdict`
///
/// Displays [AcousticDiagnosticResult] with:
/// - Distress index gauge
/// - Dominant frequency chip
/// - Suggested action (engineering recommendation)
/// - Heavy vehicle count
/// - FFT summary from on-device analysis
class BridgeCheckVerdictPage extends ConsumerWidget {
  const BridgeCheckVerdictPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bridgeCheckControllerProvider);

    if (state.phase == BridgeCheckPhase.error) {
      return _ErrorView(
        message: state.errorMessage ?? 'Unknown error occurred.',
        onRetry: () {
          ref.read(bridgeCheckControllerProvider.notifier).reset();
          context.go('/bridge-check');
        },
      );
    }

    final result = state.result;
    final fft = state.fftSummary;

    if (result == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1C),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1C),
        title: const Text(
          'Diagnostic Result',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(bridgeCheckControllerProvider.notifier).reset();
              context.go('/bridge-check');
            },
            child: const Text(
              'New Check',
              style: TextStyle(color: Color(0xFF818CF8), fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Distress index gauge ─────────────────────────────────────
            _DistressGauge(distressIndex: result.distressIndex),
            const SizedBox(height: 24),

            // ── Suggested action chip ────────────────────────────────────
            if (result.suggestedAction != null)
              _SuggestedActionCard(action: result.suggestedAction!),
            const SizedBox(height: 24),

            // ── Metric row ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Dominant Freq.',
                    value:
                        '${result.dominantFrequencyHz.toStringAsFixed(1)} Hz',
                    icon: Icons.waves_rounded,
                    color: const Color(0xFF818CF8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Energy (RMS)',
                    value: result.energy.toStringAsFixed(2),
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Heavy Vehicles',
                    value: '${result.heavyVehicleCount}',
                    icon: Icons.local_shipping_rounded,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Analysed At',
                    value: DateFormat('HH:mm').format(result.analyzedAtUtc.toLocal()),
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),

            // ── On-device FFT summary ────────────────────────────────────
            if (fft != null) ...[
              const SizedBox(height: 24),
              _FftSummaryCard(fft: fft),
            ],

            const SizedBox(height: 24),

            // ── Metadata ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session Info',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Traffic-triggered',
                    value: state.trafficTriggered ? 'Yes' : 'Manual',
                  ),
                  _InfoRow(
                    label: 'Phone flat on deck',
                    value: state.phoneFlatOnDeck ? 'Confirmed' : 'Not confirmed',
                  ),
                  _InfoRow(
                    label: 'Report ID',
                    value: result.id.substring(0, 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Distress Gauge ────────────────────────────────────────────────────────────

class _DistressGauge extends StatelessWidget {
  final double distressIndex; // 0.0 – 1.0

  const _DistressGauge({required this.distressIndex});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _classify(distressIndex);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: distressIndex.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Safe',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              Text(
                'Distress: ${(distressIndex * 100).toStringAsFixed(0)}%',
                style:
                    TextStyle(color: color, fontSize: 12, fontFamily: 'Inter'),
              ),
              const Text('Critical',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  static (String, Color) _classify(double idx) {
    if (idx < 0.3) {
      return ('Structural Health: GOOD', const Color(0xFF10B981));
    } else if (idx < 0.6) {
      return ('Structural Health: MODERATE', const Color(0xFFF59E0B));
    } else if (idx < 0.85) {
      return ('Structural Health: POOR', const Color(0xFFEF4444));
    } else {
      return ('CRITICAL — Immediate Inspection Required', const Color(0xFFDC2626));
    }
  }
}

// ── Suggested Action ──────────────────────────────────────────────────────────

class _SuggestedActionCard extends StatelessWidget {
  final String action;

  const _SuggestedActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.engineering_rounded, color: Color(0xFF818CF8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suggested Action',
                  style: TextStyle(
                    color: Color(0xFF818CF8),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.4,
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

// ── Metric Card ───────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

// ── FFT Summary Card ──────────────────────────────────────────────────────────

class _FftSummaryCard extends StatelessWidget {
  final FftSummary fft;

  const _FftSummaryCard({required this.fft});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: Color(0xFF818CF8), size: 18),
              SizedBox(width: 8),
              Text(
                'On-device FFT Summary',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Dominant Hz',
            value: '${fft.dominantFrequencyHz.toStringAsFixed(2)} Hz',
          ),
          _InfoRow(
            label: 'Magnitude',
            value: fft.dominantMagnitude.toStringAsFixed(3),
          ),
          _InfoRow(
            label: 'RMS Energy',
            value: fft.energy.toStringAsFixed(3),
          ),
          _InfoRow(
            label: 'Spike Count',
            value: '${fft.heavyVehicleCount}',
          ),
        ],
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1C),
        title: const Text('Error',
            style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFEF4444), size: 56),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
