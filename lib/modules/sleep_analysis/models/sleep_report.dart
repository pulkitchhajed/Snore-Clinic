// Sleep Analysis Data Models

/// Represents a single snoring spike event detected during audio analysis
class SnoringEvent {
  final Duration timestamp;
  final double amplitude; // 0.0 – 1.0 normalized
  final Duration duration;

  const SnoringEvent({
    required this.timestamp,
    required this.amplitude,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
        'timestamp_ms': timestamp.inMilliseconds,
        'amplitude': amplitude,
        'duration_ms': duration.inMilliseconds,
      };
}

/// Quality label derived from sleep score
enum SleepQuality { excellent, good, fair, poor }

/// A single insight / tip surfaced from the analysis
class SleepInsight {
  final String title;
  final String description;
  final String emoji;

  const SleepInsight({
    required this.title,
    required this.description,
    required this.emoji,
  });
}

/// Amplitude sample for the timeline chart
class AmplitudeSample {
  final double timeSeconds; // x-axis
  final double amplitude; // y-axis (0.0 – 1.0)
  final bool isSnoring;

  const AmplitudeSample({
    required this.timeSeconds,
    required this.amplitude,
    required this.isSnoring,
  });
}

/// Full sleep report produced after audio analysis
class SleepReport {
  final String fileName;
  final DateTime recordedAt;
  final Duration totalDuration;
  final Duration snoringDuration;
  final int snoringEventCount;
  final double qualityScore; // 0–100
  final SleepQuality quality;
  final List<SnoringEvent> snoringEvents;
  final List<AmplitudeSample> amplitudeTimeline;
  final List<SleepInsight> insights;
  
  // AI Synthetic Metrics
  final double sleepDebtHours;
  final double lightSleepPercent;
  final double deepSleepPercent;
  final double remSleepPercent;
  final String apneaRiskLevel;

  const SleepReport({
    required this.fileName,
    required this.recordedAt,
    required this.totalDuration,
    required this.snoringDuration,
    required this.snoringEventCount,
    required this.qualityScore,
    required this.quality,
    required this.snoringEvents,
    required this.amplitudeTimeline,
    required this.insights,
    this.sleepDebtHours = 0.0,
    this.lightSleepPercent = 0.50,
    this.deepSleepPercent = 0.25,
    this.remSleepPercent = 0.25,
    this.apneaRiskLevel = 'Low',
  });

  double get snoringPercentage =>
      totalDuration.inSeconds > 0
          ? (snoringDuration.inSeconds / totalDuration.inSeconds) * 100
          : 0;

  String get qualityLabel {
    switch (quality) {
      case SleepQuality.excellent:
        return 'Excellent';
      case SleepQuality.good:
        return 'Good';
      case SleepQuality.fair:
        return 'Fair';
      case SleepQuality.poor:
        return 'Poor';
    }
  }

  String get qualityEmoji {
    switch (quality) {
      case SleepQuality.excellent:
        return '🌟';
      case SleepQuality.good:
        return '😊';
      case SleepQuality.fair:
        return '😐';
      case SleepQuality.poor:
        return '😴';
    }
  }
}
