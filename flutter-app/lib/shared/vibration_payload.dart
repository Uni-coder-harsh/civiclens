import 'report_payload.dart';

class SensorChannel {
  final String name;
  final int sampleRateHz;
  final List<double> samples;
  final String encoding;

  const SensorChannel({
    required this.name,
    required this.sampleRateHz,
    required this.samples,
    required this.encoding,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'sample_rate_hz': sampleRateHz,
        'samples': samples,
        'encoding': encoding,
      };

  factory SensorChannel.fromJson(Map<String, dynamic> json) => SensorChannel(
        name: json['name'] as String,
        sampleRateHz: json['sample_rate_hz'] as int,
        samples: (json['samples'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(),
        encoding: json['encoding'] as String,
      );
}

class FftSummary {
  final double dominantFrequencyHz;
  final double dominantMagnitude;
  final double energy;
  final int heavyVehicleCount;

  const FftSummary({
    required this.dominantFrequencyHz,
    required this.dominantMagnitude,
    required this.energy,
    required this.heavyVehicleCount,
  });

  Map<String, dynamic> toJson() => {
        'dominant_frequency_hz': dominantFrequencyHz,
        'dominant_magnitude': dominantMagnitude,
        'energy': energy,
        'heavy_vehicle_count': heavyVehicleCount,
      };

  factory FftSummary.fromJson(Map<String, dynamic> json) => FftSummary(
        dominantFrequencyHz: (json['dominant_frequency_hz'] as num).toDouble(),
        dominantMagnitude: (json['dominant_magnitude'] as num).toDouble(),
        energy: (json['energy'] as num).toDouble(),
        heavyVehicleCount: json['heavy_vehicle_count'] as int,
      );
}

class VibrationPayload {
  final String id;
  final String userId;
  final String? infrastructureId;
  final GeoCapture capture;
  final int durationMs;
  final List<SensorChannel> channels;
  final FftSummary? fftSummary;
  final bool phoneFlatOnDeck;
  final bool trafficTriggered;

  const VibrationPayload({
    required this.id,
    required this.userId,
    this.infrastructureId,
    required this.capture,
    required this.durationMs,
    required this.channels,
    this.fftSummary,
    required this.phoneFlatOnDeck,
    required this.trafficTriggered,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'infrastructure_id': infrastructureId,
        'capture': capture.toJson(),
        'duration_ms': durationMs,
        'channels': channels.map((c) => c.toJson()).toList(),
        'fft_summary': fftSummary?.toJson(),
        'phone_flat_on_deck': phoneFlatOnDeck,
        'traffic_triggered': trafficTriggered,
      };

  factory VibrationPayload.fromJson(Map<String, dynamic> json) =>
      VibrationPayload(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        infrastructureId: json['infrastructure_id'] as String?,
        capture: GeoCapture.fromJson(json['capture'] as Map<String, dynamic>),
        durationMs: json['duration_ms'] as int,
        channels: (json['channels'] as List<dynamic>)
            .map((c) => SensorChannel.fromJson(c as Map<String, dynamic>))
            .toList(),
        fftSummary: json['fft_summary'] != null
            ? FftSummary.fromJson(json['fft_summary'] as Map<String, dynamic>)
            : null,
        phoneFlatOnDeck: json['phone_flat_on_deck'] as bool,
        trafficTriggered: json['traffic_triggered'] as bool,
      );
}

class AcousticDiagnosticResult {
  final String id;
  final double dominantFrequencyHz;
  final double energy;
  final int heavyVehicleCount;
  final double distressIndex;
  final String? suggestedAction;
  final DateTime analyzedAtUtc;

  const AcousticDiagnosticResult({
    required this.id,
    required this.dominantFrequencyHz,
    required this.energy,
    required this.heavyVehicleCount,
    required this.distressIndex,
    this.suggestedAction,
    required this.analyzedAtUtc,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dominant_frequency_hz': dominantFrequencyHz,
        'energy': energy,
        'heavy_vehicle_count': heavyVehicleCount,
        'distress_index': distressIndex,
        'suggested_action': suggestedAction,
        'analyzed_at_utc': analyzedAtUtc.toUtc().toIso8601String(),
      };

  factory AcousticDiagnosticResult.fromJson(Map<String, dynamic> json) =>
      AcousticDiagnosticResult(
        id: json['id'] as String,
        dominantFrequencyHz: (json['dominant_frequency_hz'] as num).toDouble(),
        energy: (json['energy'] as num).toDouble(),
        heavyVehicleCount: json['heavy_vehicle_count'] as int,
        distressIndex: (json['distress_index'] as num).toDouble(),
        suggestedAction: json['suggested_action'] as String?,
        analyzedAtUtc: DateTime.parse(json['analyzed_at_utc'] as String),
      );
}
