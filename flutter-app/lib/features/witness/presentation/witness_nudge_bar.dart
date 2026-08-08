import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/witness_notifier_provider.dart';

/// Slide-up bottom banner displayed on the home shell when an unverified
/// nearby report is detected within 50m of the device.
///
/// Auto-dismisses after 30 seconds.
class WitnessNudgeBar extends ConsumerStatefulWidget {
  const WitnessNudgeBar({super.key});

  @override
  ConsumerState<WitnessNudgeBar> createState() => _WitnessNudgeBarState();
}

class _WitnessNudgeBarState extends ConsumerState<WitnessNudgeBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _startAutoDismiss() {
    _autoDismiss?.cancel();
    _autoDismiss = Timer(const Duration(seconds: 30), _dismiss);
  }

  void _dismiss() {
    _slideController.reverse().then((_) {
      if (mounted) {
        ref.read(witnessNotifierProvider.notifier).dismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final witnessAsync = ref.watch(witnessNotifierProvider);

    return witnessAsync.when(
      data: (state) {
        if (state.nearbyUnverified.isEmpty) {
          _slideController.reverse();
          return const SizedBox.shrink();
        }

        final defect = state.nearbyUnverified.first;

        // Trigger slide-in and auto-dismiss on new item
        if (!_slideController.isAnimating && _slideController.value == 0) {
          _slideController.forward();
          _startAutoDismiss();
        }

        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E3A5F), Theme.of(context).colorScheme.surface],
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.visibility_rounded,
                        color: Color(0xFF60A5FA), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '~50m away — can you confirm this report?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _autoDismiss?.cancel();
                      context.push('/witness/${defect.reportId}');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(Icons.close_rounded,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B), size: 18),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
