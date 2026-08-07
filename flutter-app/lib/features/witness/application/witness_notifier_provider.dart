import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/defect.dart';
import '../../../shared/ticket.dart';
import '../data/witness_repository.dart';

/// State exposed by [WitnessNotifier].
class WitnessState {
  final List<NearbyDefect> nearbyUnverified;
  final bool isChecking;

  const WitnessState({
    this.nearbyUnverified = const [],
    this.isChecking = false,
  });

  WitnessState copyWith({
    List<NearbyDefect>? nearbyUnverified,
    bool? isChecking,
  }) =>
      WitnessState(
        nearbyUnverified: nearbyUnverified ?? this.nearbyUnverified,
        isChecking: isChecking ?? this.isChecking,
      );
}

/// Background provider that polls for nearby unverified reports every 5 minutes
/// when the active session role is [UserRole.citizen].
class WitnessNotifier extends AsyncNotifier<WitnessState> {
  Timer? _timer;
  static const _interval = Duration(minutes: 5);
  static const double _radiusMeters = 50;

  @override
  Future<WitnessState> build() async {
    _startPolling();

    ref.onDispose(() {
      _timer?.cancel();
    });

    // Initial check on build
    return _check();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) async {
      final session = ref.read(authSessionProvider);
      if (session.isCitizen) {
        state = AsyncData(state.valueOrNull?.copyWith(isChecking: true) ??
            const WitnessState(isChecking: true));
        final next = await _check();
        state = AsyncData(next);
      }
    });
  }

  Future<WitnessState> _check() async {
    final session = ref.read(authSessionProvider);
    if (!session.isCitizen) return const WitnessState();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final repo = ref.read(witnessRepositoryProvider);
      final nearby = await repo.fetchWitnessableNearby(
        position.latitude,
        position.longitude,
        radiusMeters: _radiusMeters,
      );
      return WitnessState(nearbyUnverified: nearby, isChecking: false);
    } catch (_) {
      return const WitnessState();
    }
  }

  /// Dismisses the current nudge (clears the first unverified item from the list).
  void dismiss() {
    final current = state.valueOrNull;
    if (current == null || current.nearbyUnverified.isEmpty) return;
    state = AsyncData(
      current.copyWith(
        nearbyUnverified: current.nearbyUnverified.sublist(1),
      ),
    );
  }
}

final witnessNotifierProvider =
    AsyncNotifierProvider<WitnessNotifier, WitnessState>(
  WitnessNotifier.new,
);
