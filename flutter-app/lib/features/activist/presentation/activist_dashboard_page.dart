import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_providers.dart';
import '../../../shared/defect.dart';
import '../../../shared/report_payload.dart';
import '../../map/data/map_repository.dart';

class ActivistDashboardPage extends ConsumerStatefulWidget {
  const ActivistDashboardPage({super.key});

  @override
  ConsumerState<ActivistDashboardPage> createState() => _ActivistDashboardPageState();
}

class _ActivistDashboardPageState extends ConsumerState<ActivistDashboardPage> {
  List<NearbyDefect> _defects = [];
  bool _isLoading = false;
  String _selectedZone = 'All Regions';
  String _selectedSeverity = 'All Severities';
  Position? _currentPosition;

  final List<String> _zones = ['All Regions', 'Deccan Gymkhana', 'Shivajinagar', 'Model Colony', 'FC Road', 'Swargate', 'Aundh', 'Bibwewadi'];
  final List<String> _severities = ['All Severities', 'critical', 'high', 'medium', 'low'];

  @override
  void initState() {
    super.initState();
    _loadDefects();
  }

  Future<void> _loadDefects() async {
    setState(() => _isLoading = true);
    try {
      double lat = 18.5204;
      double lng = 73.8567;

      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 3),
        );
        _currentPosition = pos;
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        // Fallback to Pune
      }

      final repo = ref.read(mapRepositoryProvider);
      // Fetch within 10km to get a broad region view for activists
      final list = await repo.fetchNearbyDefects(lat, lng, 10000);
      setState(() {
        _defects = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<NearbyDefect> get _filteredDefects {
    return _defects.where((d) {
      final matchesZone = _selectedZone == 'All Regions' ||
          (d.address != null && d.address!.toLowerCase().contains(_selectedZone.toLowerCase()));
      
      final matchesSeverity = _selectedSeverity == 'All Severities' ||
          (d.aiSeverity != null && d.aiSeverity!.toLowerCase() == _selectedSeverity.toLowerCase());
          
      return matchesZone && matchesSeverity;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredDefects;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Text(
              'Activist Portal',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDefects,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedZone,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      labelText: 'Region',
                    ),
                    items: _zones.map((z) => DropdownMenuItem(value: z, child: Text(z, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedZone = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSeverity,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      labelText: 'Severity',
                    ),
                    items: _severities.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSeverity = val);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Feed List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.feed_rounded, size: 64, color: theme.disabledColor),
                            const SizedBox(height: 12),
                            Text(
                              'No infrastructure hazards reported in this area.',
                              style: TextStyle(color: theme.disabledColor),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _ActivistFeedCard(defect: filtered[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ActivistFeedCard extends StatefulWidget {
  final NearbyDefect defect;
  const _ActivistFeedCard({required this.defect});

  @override
  State<_ActivistFeedCard> createState() => _ActivistFeedCardState();
}

class _ActivistFeedCardState extends State<_ActivistFeedCard> {
  bool _isExpanded = false;

  // Telemetry algorithms based on variables
  String _calculateTimeToFailure(String severity) {
    int baseDays = 180;
    if (severity.toLowerCase() == 'critical') {
      baseDays = 6;
    } else if (severity.toLowerCase() == 'high') {
      baseDays = 24;
    } else if (severity.toLowerCase() == 'medium') {
      baseDays = 75;
    }
    
    // Environmental factors
    double weatherDegradationFactor = 0.85; // monsoon acceleration
    double trafficStressFactor = 0.8; // structural loading
    double naturalCalamityIndex = 0.95;

    int finalDays = (baseDays * weatherDegradationFactor * trafficStressFactor * naturalCalamityIndex).round();
    if (finalDays < 1) finalDays = 1;

    if (finalDays <= 7) {
      return '$finalDays days (CRITICAL)';
    } else if (finalDays <= 30) {
      return '$finalDays days (~${(finalDays / 7).round()} weeks)';
    } else {
      return '${(finalDays / 30).round()} months';
    }
  }

  Color _severityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF97316);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defect = widget.defect;
    final severity = defect.aiSeverity ?? 'medium';
    final timeToFailure = _calculateTimeToFailure(severity);
    final categoryLabel = defect.category.name.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header details
          ListTile(
            title: Text(
              categoryLabel,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
            ),
            subtitle: Text(
              defect.address ?? 'Pune, India',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _severityColor(severity).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _severityColor(severity).withValues(alpha: 0.4)),
              ),
              child: Text(
                severity.toUpperCase(),
                style: TextStyle(color: _severityColor(severity), fontWeight: FontWeight.w700, fontSize: 10),
              ),
            ),
          ),

          // Photo preview
          if (defect.thumbnailUrl.isNotEmpty)
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(defect.thumbnailUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Action expansion panel
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Structural Degradation Telemetry',
                      style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                    ),
                    IconButton(
                      icon: Icon(_isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                      onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 8),
                  _TelemetryRow(
                    label: 'Est. Complete Collapse:',
                    value: timeToFailure,
                    valueColor: const Color(0xFFEF4444),
                    isBold: true,
                  ),
                  const _TelemetryRow(label: 'Weather Acceleration:', value: '🌧️ Monsoon Storm Risk (High)'),
                  const _TelemetryRow(label: 'Daily Traffic Loading:', value: '🚛 Heavy Freight / Transit Lane'),
                  const _TelemetryRow(label: 'Environmental Calamity:', value: '🌊 Active Flood Drainage Area'),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.campaign_rounded, color: Colors.white),
                        label: const Text('Mobilize Reach (AI)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => _SocialCampaignSheet(
                              defect: defect,
                              timeToFailure: timeToFailure,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _TelemetryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// Bottom Sheet for campaign generation and editing
class _SocialCampaignSheet extends ConsumerStatefulWidget {
  final NearbyDefect defect;
  final String timeToFailure;

  const _SocialCampaignSheet({
    required this.defect,
    required this.timeToFailure,
  });

  @override
  ConsumerState<_SocialCampaignSheet> createState() => _SocialCampaignSheetState();
}

class _SocialCampaignSheetState extends ConsumerState<_SocialCampaignSheet> {
  String _caption = '';
  String _tags = '';
  bool _isLoading = false;
  final TextEditingController _instructionController = TextEditingController();

  final List<Map<String, String>> _rajkotInfluencers = [
    {'name': 'Rajkot Live News', 'handle': '@rajkotlivenews'},
    {'name': 'Rajkot Municipal Corp.', 'handle': '@rajkot_municipal_corporation'},
    {'name': 'Active Rajkot Group', 'handle': '@active_rajkot'},
    {'name': 'Rajkot Updates', 'handle': '@rajkotupdates'},
  ];
  final Set<String> _selectedInfluencers = {};

  @override
  void initState() {
    super.initState();
    _generateCampaign();
  }

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  String get _fullTagsText {
    if (_selectedInfluencers.isEmpty) return _tags;
    final handles = _selectedInfluencers.join(' ');
    return '$handles\n$_tags';
  }

  Future<void> _generateCampaign([String? customInstruction]) async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/v1/ai/generate-caption',
        data: {
          'category': widget.defect.category.name,
          'severity': widget.defect.aiSeverity ?? 'medium',
          'description': widget.defect.aiLabel ?? 'Reported structural defect requiring immediate municipal review.',
          'address': widget.defect.address ?? 'Pune, India',
          'time_to_failure': widget.timeToFailure,
          'custom_instruction': customInstruction,
        },
      );
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _caption = data['caption'] ?? '';
        _tags = data['tags'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate campaign: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + keyboardHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI Social Media Mobilization',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    SizedBox(height: 12),
                    Text('AI generating activist campaign captions & tags...', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ),
            )
          else ...[
            // Target local Rajkot Influencers
            Text(
              'Target Local Channels & Authorities (Rajkot)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _rajkotInfluencers.length,
                itemBuilder: (context, index) {
                  final inf = _rajkotInfluencers[index];
                  final name = inf['name']!;
                  final handle = inf['handle']!;
                  final isSelected = _selectedInfluencers.contains(handle);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selectedColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                      selected: isSelected,
                      label: Text('$name ($handle)', style: const TextStyle(fontSize: 10)),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedInfluencers.add(handle);
                          } else {
                            _selectedInfluencers.remove(handle);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Generated Caption Preview
            Container(
              padding: const EdgeInsets.all(12),
              maxHeight: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  '$_caption\n\n$_fullTagsText',
                  style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Refinement instructions
            TextField(
              controller: _instructionController,
              decoration: InputDecoration(
                hintText: 'e.g. Sarcastic tone, add Marathi tags, focus on floods...',
                labelText: 'Refine with NLP instruction',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6)),
                  onPressed: () {
                    if (_instructionController.text.trim().isNotEmpty) {
                      _generateCampaign(_instructionController.text.trim());
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Post action controls
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF8B5CF6)),
                    label: const Text('Copy to Clipboard', style: TextStyle(color: Color(0xFF8B5CF6))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '$_caption\n\n$_fullTagsText'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Campaign text copied to clipboard!')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: const Text('Post Campaign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      // Copy to clipboard automatically first so they can paste easily on Instagram
                      Clipboard.setData(ClipboardData(text: '$_caption\n\n$_fullTagsText'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Activist Caption copied! Opening Share Sheet...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      // Trigger share sheet
                      final text = '$_caption\n\n$_fullTagsText';
                      await Share.share(text, subject: 'CivicLens activist mobilization campaign');
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
