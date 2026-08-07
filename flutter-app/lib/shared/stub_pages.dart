import 'package:flutter/material.dart';

/// Placeholder page used while other features are being built in later phases.
class StubPage extends StatelessWidget {
  final String title;
  const StubPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_rounded,
                color: Color(0xFF4F46E5), size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming in a later phase',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

// Named stub page constructors for go_router builder clarity
class CameraPage extends StubPage {
  const CameraPage({super.key}) : super(title: 'Camera Capture');
}

class ReportFormPage extends StubPage {
  final String? draftId;
  const ReportFormPage({super.key, this.draftId}) : super(title: 'Report Form');
}

class DraftStatusPage extends StubPage {
  final String draftId;
  const DraftStatusPage({super.key, required this.draftId})
      : super(title: 'Draft Status');
}

class ReportDetailPage extends StubPage {
  final String reportId;
  const ReportDetailPage({super.key, required this.reportId})
      : super(title: 'Report Detail');
}

class OfficerQueuePage extends StubPage {
  const OfficerQueuePage({super.key}) : super(title: 'Officer Queue');
}

class OfficerTicketPage extends StubPage {
  final String reportId;
  const OfficerTicketPage({super.key, required this.reportId})
      : super(title: 'Officer Ticket');
}

class ContractorClaimsPage extends StubPage {
  const ContractorClaimsPage({super.key}) : super(title: 'Contractor Claims');
}

class ContractorTicketPage extends StubPage {
  final String reportId;
  const ContractorTicketPage({super.key, required this.reportId})
      : super(title: 'Contractor Ticket');
}

class ShareCardPage extends StubPage {
  const ShareCardPage({super.key}) : super(title: 'Share Report Card');
}

class WitnessPage extends StubPage {
  final String reportId;
  const WitnessPage({super.key, required this.reportId})
      : super(title: 'Witness Report');
}

class LeaderboardPage extends StubPage {
  const LeaderboardPage({super.key}) : super(title: 'Contractor Leaderboard');
}

class ContractorPassportPage extends StubPage {
  final String contractorId;
  const ContractorPassportPage({super.key, required this.contractorId})
      : super(title: 'Contractor Passport');
}

class BridgeCheckPage extends StubPage {
  const BridgeCheckPage({super.key}) : super(title: 'Bridge Check');
}

class DroneUploadPage extends StubPage {
  const DroneUploadPage({super.key}) : super(title: 'Drone Upload');
}
