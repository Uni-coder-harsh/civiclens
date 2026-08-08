import 'dart:math';
import 'package:fftea/fftea.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/vibration_payload.dart';

// ── Isolate entry point ────────────────────────────────────────────────────────

/// Data contract for the isolate — plain POD, no Flutter objects.
class _FftInput {
  final List<double> samples;
  final int sampleRateHz;

  const _FftInput({required this.samples, required this.sampleRateHz});
}

/// Top-level function (required by [compute]) — runs in a separate isolate.
FftSummary _runFftInIsolate(_FftInput input) {
  final samples = input.samples;
  final sampleRate = input.sampleRateHz;

  if (samples.isEmpty) {
    return const FftSummary(
      dominantFrequencyHz: 0,
      dominantMagnitude: 0,
      energy: 0,
      heavyVehicleCount: 0,
    );
  }

  // Pad or trim to the nearest power of 2 for Radix-2 FFT efficiency.
  final n = _nextPowerOf2(samples.length);
  final padded = List<double>.filled(n, 0);
  for (var i = 0; i < samples.length && i < n; i++) {
    padded[i] = samples[i];
  }

  // Apply a Hann window to reduce spectral leakage.
  _applyHannWindow(padded);

  // Run FFT — this is the CPU-intensive step, safely on the isolate.
  final fft = FFT(n);
  final complexResult = fft.realFft(padded);
  final mags = complexResult.magnitudes();

  // Only the first half has unique information (Nyquist).
  final halfN = n ~/ 2;
  final freqResolution = sampleRate / n;

  // Find dominant frequency and magnitude.
  var maxMag = 0.0;
  var maxBin = 0;
  for (var i = 1; i < halfN; i++) {
    if (mags[i] > maxMag) {
      maxMag = mags[i];
      maxBin = i;
    }
  }

  final dominantHz = maxBin * freqResolution;

  // RMS energy proxy: mean of squared magnitudes across lower half.
  var sumSq = 0.0;
  for (var i = 0; i < halfN; i++) {
    sumSq += mags[i] * mags[i];
  }
  final energy = sqrt(sumSq / halfN);

  // Count heavy-vehicle spikes: bins whose magnitude > 30 % of peak
  // and frequency < 50 Hz (structural range for heavy vehicles).
  var spikeCount = 0;
  final threshold = maxMag * 0.30;
  for (var i = 1; i < halfN; i++) {
    final hz = i * freqResolution;
    if (hz > 50) break; // only structural range
    if (mags[i] >= threshold) spikeCount++;
  }

  return FftSummary(
    dominantFrequencyHz: dominantHz,
    dominantMagnitude: maxMag,
    energy: energy,
    heavyVehicleCount: spikeCount,
  );
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Runs FFT analysis on a list of samples in a separate [compute] isolate.
///
/// Never call this from the UI thread directly at 200 Hz — use it once when
/// the recording window has closed.
Future<FftSummary> analyzeAccelSamples({
  required List<double> samples,
  required int sampleRateHz,
}) {
  return compute(
    _runFftInIsolate,
    _FftInput(samples: samples, sampleRateHz: sampleRateHz),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

int _nextPowerOf2(int n) {
  if (n <= 0) return 1;
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}

void _applyHannWindow(List<double> samples) {
  final n = samples.length;
  for (var i = 0; i < n; i++) {
    final window = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
    samples[i] *= window;
  }
}
