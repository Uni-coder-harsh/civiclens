import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/witness/presentation/witness_nudge_bar.dart';

/// Bottom-tab shell for the Home section (/home/map, /home/activity, /home/profile).
class HomeShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          navigationShell,
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: WitnessNudgeBar(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: const Color(0xFF4F46E5).withOpacity(0.2),
          selectedIndex: navigationShell.currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => navigationShell.goBranch(index,
              initialLocation: index == navigationShell.currentIndex),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.map_rounded, color: Color(0xFF4F46E5)),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, color: Color(0xFF64748B)),
              selectedIcon:
                  Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5)),
              label: 'Activity',
            ),
            NavigationDestination(
              icon:
                  Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
              selectedIcon:
                  Icon(Icons.person_rounded, color: Color(0xFF4F46E5)),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeMapPage extends StatelessWidget {
  const HomeMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_rounded, color: Color(0xFF4F46E5), size: 64),
            SizedBox(height: 16),
            Text('Map View',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Coming in Phase 1d',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

class HomeActivityPage extends StatelessWidget {
  const HomeActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded,
                color: Color(0xFF4F46E5), size: 64),
            SizedBox(height: 16),
            Text('Activity Feed',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Coming in Phase 1d',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}
