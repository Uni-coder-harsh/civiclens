import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route: `/bridge-check`
///
/// Safety instructions page — MUST be shown before any recording starts.
/// The user must explicitly accept the safety prompt before proceeding.
class BridgeCheckInstructionsPage extends StatelessWidget {
  const BridgeCheckInstructionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Bridge Acoustic Check',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Safety alert ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFDC2626).withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFEF4444),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Safety First',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Place your phone FLAT on the bridge deck surface — then STEP BACK from traffic immediately.\n\n'
                    'Do NOT stand near the edge or in active lanes while recording. '
                    'Your safety is more important than any data point.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 15,
                      fontFamily: 'Inter',
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── How it works ─────────────────────────────────────────────
            Text(
              'How It Works',
              style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),

            _StepTile(
              step: '1',
              icon: Icons.phone_android_rounded,
              title: 'Place phone flat on deck',
              description:
                  'The app confirms the phone is horizontal using the accelerometer before recording can begin.',
            ),
            _StepTile(
              step: '2',
              icon: Icons.directions_bus_rounded,
              title: 'Step back — auto-trigger fires',
              description:
                  'When a heavy vehicle crosses, the app detects the z-axis spike and automatically starts a 30-second window.',
            ),
            _StepTile(
              step: '3',
              icon: Icons.analytics_rounded,
              title: 'On-device FFT verdict',
              description:
                  'Dominant structural frequency and vibration energy are computed on your device. Results upload alongside the raw audio.',
            ),
            _StepTile(
              step: '4',
              icon: Icons.assignment_turned_in_rounded,
              title: 'Review the verdict',
              description:
                  'See the distress index, suggested engineering action, and heavy vehicle count from the session.',
            ),

            const SizedBox(height: 40),

            // ── CTA ──────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.push('/bridge-check/recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.mic_rounded),
                label: const Text(
                  'I understand — Start Check',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String description;

  const _StepTile({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: const Color(0xFF818CF8)),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color ??
                        const Color(0xFF94A3B8),
                    fontSize: 13,
                    fontFamily: 'Inter',
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
