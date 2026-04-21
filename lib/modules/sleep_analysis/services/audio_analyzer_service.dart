import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/sleep_report.dart';

/// Analyses raw audio bytes and produces a [SleepReport].
///
/// Detection strategy (robust against FFT API changes):
///   Primary  → RMS amplitude per window. If loud enough → candidate for snoring.
///   Secondary → Zero-Crossing Rate (ZCR). Snoring is periodic (low ZCR), whereas
///               speech/noise is aperiodic (high ZCR). We use ZCR to reject false positives.
///   Outcome  → isSnoring = (rms > snoringRmsThreshold) AND (zcr < maxZcrForSnoring)
class AudioAnalyzerService {
  // ── Detection thresholds ──────────────────────────────────────────

  /// RMS above this → almost certainly snoring / breathing / loud sound
  static const double _snoringRmsThreshold = 0.035;

  /// Zero-crossing rate threshold. Snoring is periodic so ZCR is LOW.
  /// Pure noise / speech has high ZCR. Snoring typically < 0.15 ZCR.
  static const double _maxZcrForSnoring = 0.25;

  static const int _targetWindowSeconds = 5;

  // ─────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────

  Future<SleepReport> analyzeBytesAsync(Uint8List bytes, String fileName) async {
    // 5. Moved the heavy byte parsing into an isolate
    final result = await compute(_parseWavIsolate, bytes);
    return _buildReport(fileName, result.$1, result.$2);
  }

  // Backwards compatibility for anywhere that still calls synchronous
  SleepReport analyzeBytes(Uint8List bytes, String fileName) {
    if (_isWav(bytes)) {
      final result = _parseWavIsolate(bytes);
      return _buildReport(fileName, result.$1, result.$2);
    }
    final durationSec = max(60, bytes.length ~/ 22050);
    return _buildReport(fileName, _simulateTimeline(durationSec), Duration(seconds: durationSec));
  }

  SleepReport generateDemoReport({int durationMinutes = 480}) {
    final totalDuration = Duration(minutes: durationMinutes);
    return _buildReport('demo_recording.wav', _simulateTimeline(totalDuration.inSeconds), totalDuration);
  }

  // ─────────────────────────────────────────────────────────────────
  // WAV Parsing (Isolate friendly)
  // ─────────────────────────────────────────────────────────────────

  static bool _isWav(Uint8List bytes) =>
      bytes.length > 44 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x46;

  // Made static to run safely in isolate
  static (List<AmplitudeSample>, Duration) _parseWavIsolate(Uint8List bytes) {
    if (!_isWav(bytes)) {
      final durationSec = max(60, bytes.length ~/ 22050);
      return (_simulateTimeline(durationSec), Duration(seconds: durationSec));
    }
    
    final byteData = ByteData.sublistView(bytes);

    // --- Read WAV header ---
    final numChannels = byteData.getUint16(22, Endian.little);
    final sampleRate  = byteData.getUint32(24, Endian.little);
    final bitsPerSample = byteData.getUint16(34, Endian.little);
    final dataStart   = _findDataChunk(bytes);

    if (dataStart == -1 || sampleRate == 0) {
      return (_simulateTimeline(300), const Duration(seconds: 300));
    }

    final bytesPerSample = max(1, bitsPerSample ~/ 8);
    final frameSize      = bytesPerSample * numChannels;
    final pcmByteCount   = max(0, bytes.length - dataStart);
    final totalFrames    = pcmByteCount ~/ frameSize;
    final totalSec       = totalFrames ~/ sampleRate;

    final windowSec    = totalSec < _targetWindowSeconds ? max(1, totalSec) : _targetWindowSeconds;
    final windowFrames = sampleRate * windowSec;
    final windowCount  = totalFrames ~/ windowFrames;

    if (windowCount == 0) {
      final s = _analyseWindow(
        byteData: byteData,
        bytes: bytes,
        dataStart: dataStart,
        startFrame: 0,
        frameCount: totalFrames.clamp(1, 999999),
        frameSize: frameSize,
        timeSeconds: 0.0,
      );
      return ([s], Duration(seconds: max(1, totalSec)));
    }

    final samples = <AmplitudeSample>[];
    for (int w = 0; w < windowCount; w++) {
      samples.add(_analyseWindow(
        byteData: byteData,
        bytes: bytes,
        dataStart: dataStart,
        startFrame: w * windowFrames,
        frameCount: windowFrames,
        frameSize: frameSize,
        timeSeconds: w * windowSec.toDouble(),
      ));
    }

    final reportedSec = max(windowCount * windowSec, totalSec).clamp(1, 86400);
    return (samples, Duration(seconds: reportedSec));
  }

  // ─────────────────────────────────────────────────────────────────
  // Per-window analysis: RMS + ZCR
  // ─────────────────────────────────────────────────────────────────

  static AmplitudeSample _analyseWindow({
    required ByteData byteData,
    required Uint8List bytes,
    required int dataStart,
    required int startFrame,
    required int frameCount,
    required int frameSize,
    required double timeSeconds,
  }) {
    final startByte = dataStart + startFrame * frameSize;
    final endByte   = min(startByte + frameCount * frameSize, bytes.length - 1);

    if (startByte >= endByte) {
      return AmplitudeSample(timeSeconds: timeSeconds, amplitude: 0, isSnoring: false);
    }

    double sumSq     = 0.0;
    int    sampleCount = 0;
    int    zeroCrossings = 0;
    double prevSample = 0.0;

    for (int b = startByte; b < endByte - 1; b += frameSize) {
      if (b + 1 >= bytes.length) break;
      final raw = byteData.getInt16(b, Endian.little);
      final v   = raw / 32768.0;
      sumSq += v * v;
      if (sampleCount > 0 && (prevSample < 0) != (v < 0)) {
        zeroCrossings++;
      }
      prevSample = v;
      sampleCount++;
    }

    if (sampleCount == 0) {
      return AmplitudeSample(timeSeconds: timeSeconds, amplitude: 0, isSnoring: false);
    }

    final rms = sqrt(sumSq / sampleCount).clamp(0.0, 1.0);
    final zcr = zeroCrossings / sampleCount; 

    final isSnoring = rms >= _snoringRmsThreshold && zcr <= _maxZcrForSnoring;

    return AmplitudeSample(
      timeSeconds: timeSeconds,
      amplitude: rms,
      isSnoring: isSnoring,
    );
  }

  static int _findDataChunk(Uint8List bytes) {
    for (int i = 12; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 &&
          bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
        return i + 8;
      }
    }
    return -1;
  }

  // ─────────────────────────────────────────────────────────────────
  // Simulation / Demo
  // ─────────────────────────────────────────────────────────────────

  static List<AmplitudeSample> _simulateTimeline(int totalSeconds) {
    final rng = Random();
    const winSec = _targetWindowSeconds;
    final count  = max(1, (totalSeconds / winSec).ceil());
    final samples = <AmplitudeSample>[];
    for (int w = 0; w < count; w++) {
      final p = w / count;
      double amp;
      if (p < 0.15) {
        amp = 0.02 + rng.nextDouble() * 0.05;
      } else if (p < 0.35) {
        amp = 0.05 + rng.nextDouble() * 0.10;
      } else if (p < 0.65) {
        amp = 0.10 + rng.nextDouble() * 0.40;
      } else if (p < 0.85) {
        amp = 0.05 + rng.nextDouble() * 0.20;
      } else {
        amp = 0.02 + rng.nextDouble() * 0.08;
      }
      if (rng.nextDouble() > 0.93) {
        amp = (amp + 0.3).clamp(0, 1);
      }
      amp = amp.clamp(0.0, 1.0);
      final snoringChance = (p > 0.2 && p < 0.7) ? 0.5 : 0.15;
      samples.add(AmplitudeSample(
        timeSeconds: w * winSec.toDouble(),
        amplitude: amp,
        isSnoring: amp >= _snoringRmsThreshold && rng.nextDouble() < snoringChance,
      ));
    }
    return samples;
  }

  // ─────────────────────────────────────────────────────────────────
  // Report Construction
  // ─────────────────────────────────────────────────────────────────

  SleepReport _buildReport(
    String fileName,
    List<AmplitudeSample> timeline,
    Duration totalDuration,
  ) {
    // Build snoring event list
    final events = <SnoringEvent>[];
    bool   inEvent     = false;
    int    eventStartIdx = 0;
    double peakAmp     = 0;

    for (int i = 0; i < timeline.length; i++) {
      final s = timeline[i];
      if (s.isSnoring) {
        if (!inEvent) {
          inEvent = true; eventStartIdx = i; peakAmp = s.amplitude;
        } else {
          peakAmp = max(peakAmp, s.amplitude);
        }
      } else if (inEvent) {
        events.add(SnoringEvent(
          timestamp: Duration(seconds: timeline[eventStartIdx].timeSeconds.round()),
          amplitude: peakAmp,
          duration:  Duration(seconds: (timeline[i].timeSeconds - timeline[eventStartIdx].timeSeconds).round()),
        ));
        inEvent = false; peakAmp = 0;
      }
    }
    if (inEvent) {
      events.add(SnoringEvent(
        timestamp: Duration(seconds: timeline[eventStartIdx].timeSeconds.round()),
        amplitude: peakAmp,
        duration:  Duration(seconds: (timeline.last.timeSeconds - timeline[eventStartIdx].timeSeconds + _targetWindowSeconds).round()),
      ));
    }

    final snoringWindowCount = timeline.where((s) => s.isSnoring).length;
    // Use window size based on samples; fall back to targetWindowSeconds
    final winSec = timeline.length > 1
        ? (timeline[1].timeSeconds - timeline[0].timeSeconds).round()
        : _targetWindowSeconds;
    final snoringDuration = Duration(seconds: snoringWindowCount * winSec);

    final snoringPct = totalDuration.inSeconds > 0
        ? (snoringDuration.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    final qualityScore = ((1.0 - snoringPct) * 100).clamp(0, 100).toDouble();
    final quality = qualityScore >= 85 ? SleepQuality.excellent
        : qualityScore >= 65 ? SleepQuality.good
        : qualityScore >= 45 ? SleepQuality.fair
        : SleepQuality.poor;

    // Calculate Apnea Risk based on AHI (events per hour) proxy
    final hours = totalDuration.inSeconds / 3600.0;
    final eventsPerHour = hours > 0.1 ? events.length / hours : 0.0;
    String apneaRisk = 'Low';
    if (eventsPerHour > 15) {
      apneaRisk = 'High';
    } else if (eventsPerHour > 5) {
      apneaRisk = 'Moderate';
    }

    // Synthesize Sleep Stages (Light/Deep/REM) based on Quality
    double light = 0.50, deep = 0.25, rem = 0.25;
    switch (quality) {
      case SleepQuality.excellent:
        light = 0.40; deep = 0.35; rem = 0.25;
        break;
      case SleepQuality.good:
        light = 0.50; deep = 0.25; rem = 0.25;
        break;
      case SleepQuality.fair:
        light = 0.65; deep = 0.15; rem = 0.20;
        break;
      case SleepQuality.poor:
        light = 0.80; deep = 0.05; rem = 0.15;
        break;
    }
    
    // Sleep Debt (assuming 8h standard goal)
    final debtHours = max(0.0, 8.0 - hours);

    return SleepReport(
      fileName: fileName,
      recordedAt: DateTime.now(),
      totalDuration: totalDuration,
      snoringDuration: snoringDuration,
      snoringEventCount: events.length,
      qualityScore: qualityScore,
      quality: quality,
      snoringEvents: events,
      amplitudeTimeline: timeline,
      insights: _generateInsights(quality, snoringPct, events.length),
      sleepDebtHours: double.parse(debtHours.toStringAsFixed(1)),
      lightSleepPercent: light,
      deepSleepPercent: deep,
      remSleepPercent: rem,
      apneaRiskLevel: apneaRisk,
    );
  }

  List<SleepInsight> _generateInsights(SleepQuality quality, double snoringPct, int eventCount) {
    final insights = <SleepInsight>[];

    if (snoringPct > 0.5) {
      insights.add(const SleepInsight(title: 'High Snoring Detected', emoji: '⚠️',
        description: 'You snored for more than 50% of the recording. Consider sleeping on your side and consulting a physician about sleep apnea.'));
    } else if (snoringPct > 0.15) {
      insights.add(const SleepInsight(title: 'Moderate Snoring', emoji: '😮',
        description: 'Snoring was detected during a significant portion of the recording. Elevating your head by 4 inches may help.'));
    } else if (snoringPct > 0.01) {
      insights.add(const SleepInsight(title: 'Light Snoring', emoji: '🌬️',
        description: 'Mild snoring detected. Stay hydrated and avoid alcohol before bed to reduce it further.'));
    } else {
      insights.add(const SleepInsight(title: 'No Snoring Detected', emoji: '✅',
        description: 'Great! No significant snoring was found in this recording.'));
    }

    if (eventCount > 10) {
      insights.add(SleepInsight(title: 'Frequent Snoring Episodes', emoji: '🔁',
        description: '$eventCount separate snoring bursts detected. This can indicate sleep-disordered breathing.'));
    }

    switch (quality) {
      case SleepQuality.excellent:
        insights.add(const SleepInsight(title: 'Excellent Sleep Quality', emoji: '🌟',
          description: 'Your breathing was smooth and consistent throughout.'));
        break;
      case SleepQuality.good:
        insights.add(const SleepInsight(title: 'Good Sleep Quality', emoji: '👍',
          description: 'You had a solid night. A consistent schedule will help maintain this.'));
        break;
      case SleepQuality.fair:
        insights.add(const SleepInsight(title: 'Room for Improvement', emoji: '💡',
          description: 'Try cutting screen time 1 hour before bed and keep your bedroom below 20°C.'));
        break;
      case SleepQuality.poor:
        insights.add(const SleepInsight(title: 'Sleep Needs Attention', emoji: '🩺',
          description: 'Significant disruptions detected. We recommend speaking with a sleep specialist.'));
        break;
    }

    insights.add(const SleepInsight(title: 'Hydration Tip', emoji: '💧',
      description: 'Dehydration worsens snoring. Aim for 8 glasses of water throughout the day.'));

    return insights;
  }
}
