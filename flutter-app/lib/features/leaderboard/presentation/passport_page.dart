import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/contractor.dart';
import '../application/leaderboard_controller.dart';

class ContractorPassportPage extends ConsumerWidget {
  final String contractorId;

  const ContractorPassportPage({super.key, required this.contractorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(contractorPassportProvider(contractorId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Contractor Passport'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: () => _showShareSheet(context),
            tooltip: 'Share Passport',
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (passport) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, passport),
                const SizedBox(height: 24),
                _buildRadarChart(context, passport.scoreBreakdown),
                const SizedBox(height: 24),
                if (passport.warranties.isNotEmpty) ...[
                  const Text('Active Warranties',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...passport.warranties
                      .map((w) => _buildWarrantyCard(context, w)),
                  const SizedBox(height: 24),
                ],
                const Text('Completed Projects',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...passport.projects.map((p) => _buildProjectCard(context, p)),
                const SizedBox(height: 24),
                const Text('Attributed Defects',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...passport.defects.map((d) => _buildDefectCard(context, d)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final url = 'https://civiclens.app/c/$contractorId';
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share Passport',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan this QR code to view the public accountability passport for this contractor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 24),
              SelectableText(
                url,
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ContractorPassport passport) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            passport.summary.companyName,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (passport.summary.kycVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified,
                                color: Colors.blue, size: 20),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('ID: ${passport.summary.contractorId}',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber),
                    Text(
                      passport.summary.grade.toStringAsFixed(1),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                  'Active Defects', '${passport.summary.activeDefects}'),
              _buildStatItem(
                  'Projects', '${passport.summary.completedProjects}'),
              _buildStatItem('Streak', '${passport.summary.streakMonths} mo'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildRadarChart(BuildContext context, ScoreBreakdown breakdown) {
    final Map<String, double> data = {
      'Quality': breakdown.quality,
      'Timeliness': breakdown.timeliness,
      'Safety': breakdown.safety,
      'Compliance': breakdown.compliance,
    };

    final labels = data.keys.toList();
    final values = data.values.toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Performance Radar',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 3,
                ticksTextStyle:
                    const TextStyle(color: Colors.transparent, fontSize: 10),
                getTitle: (index, angle) {
                  return RadarChartTitle(
                    text: labels[index],
                    angle: angle,
                  );
                },
                dataSets: [
                  RadarDataSet(
                    fillColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    borderColor: Theme.of(context).colorScheme.primary,
                    entryRadius: 2,
                    dataEntries:
                        values.map((v) => RadarEntry(value: v)).toList(),
                    borderWidth: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarrantyCard(BuildContext context, WarrantyState warranty) {
    final daysLeft =
        warranty.warrantyExpiresAtUtc.difference(DateTime.now()).inDays;
    final isExpired = daysLeft < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
          color: isExpired ? Colors.grey : Colors.orange,
        ),
        title: Text(
            'Defect #${warranty.defectId.length > 8 ? warranty.defectId.substring(0, 8) : warranty.defectId}'),
        subtitle: Text(isExpired
            ? 'Expired'
            : 'Expires in $daysLeft days - Penalty: ${warranty.scorePenaltyApplied}'),
        trailing: Text('${warranty.recurrences} Recurrences'),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, ContractorProject project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(project.name,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                Text(project.rating.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Colors.amber, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(project.scope,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Zone: ${project.zone}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDefectCard(BuildContext context, ContractorDefectRef defect) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(defect.category.name),
        subtitle: Text(defect.status.name),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onPressed: () => context.push('/report/detail/${defect.reportId}'),
        ),
      ),
    );
  }
}
