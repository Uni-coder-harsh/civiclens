import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/forbidden_state.dart';
import '../../../shared/contractor.dart';
import '../../../shared/ticket.dart';
import '../../auth/application/auth_controller.dart';
import '../../leaderboard/application/leaderboard_controller.dart';
import '../application/claims_provider.dart';
import 'claims_page.dart' show ContractorClaimCard;

/// Route: `/contractor/dashboard`
///
/// Management dashboard for contractors, showing active SLA countdowns
/// and warranty recurrences. Reuses tiles from claims_page.dart.
class ContractorDashboardPage extends ConsumerWidget {
  const ContractorDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final contractorId = session.userId == 'mock_contractor' || session.userId.isEmpty 
        ? 'ctr_pune_infra' 
        : session.userId;
    
    final claimsAsync = ref.watch(claimsProvider);
    final passportAsync = ref.watch(contractorPassportProvider(contractorId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Contractor Dashboard',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(claimsProvider.notifier).refresh();
              // Invalidate passport provider to refresh it
              ref.invalidate(contractorPassportProvider(contractorId));
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          _buildSectionTitle('Active SLAs & Claims'),
          claimsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
            ),
            error: (e, _) {
              if (e is ForbiddenException) {
                return const SliverFillRemaining(
                  child: ForbiddenState(
                    requiredRole: 'contractor',
                    action: 'view contractor dashboard',
                  ),
                );
              }
              return SliverFillRemaining(
                child: Center(
                  child: Text('Error: $e', style: const TextStyle(color: Color(0xFF94A3B8))),
                ),
              );
            },
            data: (claims) {
              if (claims.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text(
                      'No active claims.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ContractorClaimCard(ticket: claims[index]),
                    );
                  },
                  childCount: claims.length,
                ),
              );
            },
          ),
          
          _buildSectionTitle('Active Warranties'),
          passportAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('Error: $e', style: const TextStyle(color: Color(0xFF94A3B8))),
                ),
              ),
            ),
            data: (passport) {
              if (passport.warranties.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text(
                      'No active warranties.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final warranty = passport.warranties[index];
                    return _WarrantyCard(warranty: warranty);
                  },
                  childCount: passport.warranties.length,
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  final WarrantyState warranty;

  const _WarrantyCard({required this.warranty});

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMM d, yyyy');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warranty.recurrences > 0 
              ? const Color(0xFFDC2626).withOpacity(0.4) 
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Report ID: ${warranty.defectId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              if (warranty.recurrences > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${warranty.recurrences} Recurrence',
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Expires: ${formatter.format(warranty.warrantyExpiresAtUtc.toLocal())}',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          if (warranty.scorePenaltyApplied > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Penalty Applied: -${warranty.scorePenaltyApplied.toStringAsFixed(1)} points',
                style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
