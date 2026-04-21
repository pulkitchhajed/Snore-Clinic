import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/sleep_report.dart';
import '../widgets/sleep_quality_card.dart';
import '../widgets/snoring_chart_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class SleepReportScreen extends StatelessWidget {
  final SleepReport report;

  const SleepReportScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              SleepQualityCard(report: report),
              const SizedBox(height: 28),
              _buildAIStatsSection(context),
              const SizedBox(height: 28),
              _buildChartSection(context),
              const SizedBox(height: 28),
              _buildInsightsSection(context),
              const SizedBox(height: 28),
              _buildSnoringEventsSection(context),
              const SizedBox(height: 32),
              _buildNewAnalysisButton(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMM d • h:mm a').format(report.recordedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last Night\'s Sleep',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '📁 ${report.fileName}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: AppTheme.primaryIndigo),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildAIStatsSection(BuildContext context) {
    Color apneaRiskColor = AppTheme.success;
    if (report.apneaRiskLevel == 'High') apneaRiskColor = AppTheme.error;
    if (report.apneaRiskLevel == 'Moderate') apneaRiskColor = AppTheme.primaryGold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Sleep Analysis',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Text('Sleep Debt', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Text('${report.sleepDebtHours}h', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryIndigo)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Text('Apnea Risk', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Text(report.apneaRiskLevel, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: apneaRiskColor)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sleep Stages Distribution', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: [
                            PieChartSectionData(color: AppTheme.primaryIndigo.withValues(alpha: 0.6), value: report.lightSleepPercent * 100, title: '${(report.lightSleepPercent*100).toInt()}%', radius: 40),
                            PieChartSectionData(color: AppTheme.primaryIndigo, value: report.deepSleepPercent * 100, title: '${(report.deepSleepPercent*100).toInt()}%', radius: 45),
                            PieChartSectionData(color: AppTheme.accentTeal, value: report.remSleepPercent * 100, title: '${(report.remSleepPercent*100).toInt()}%', radius: 40),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStageLegend('Light Sleep', AppTheme.primaryIndigo.withValues(alpha: 0.6)),
                          const SizedBox(height: 12),
                          _buildStageLegend('Deep Sleep', AppTheme.primaryIndigo),
                          const SizedBox(height: 12),
                          _buildStageLegend('REM Sleep', AppTheme.accentTeal),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStageLegend(String title, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Snoring Activity',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Amplitude over time — red bars indicate snoring events',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: SnoringChartWidget(
            samples: report.amplitudeTimeline,
            totalDuration: report.totalDuration,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights & Tips',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        ...report.insights.map(
          (insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.emoji,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          insight.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnoringEventsSection(BuildContext context) {
    if (report.snoringEvents.isEmpty) return const SizedBox();
    final topEvents = report.snoringEvents
      ..sort((a, b) => b.amplitude.compareTo(a.amplitude));
    final display = topEvents.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Snoring Spikes',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Loudest events detected during recording',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: display.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              final isLast = i == display.length - 1;
              final timeStr = _formatTimestamp(event.timestamp);
              final durationStr = _formatDuration(event.duration);
              final intensity = (event.amplitude * 100).toInt();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'At $timeStr • $durationStr',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Intensity: $intensity%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        _IntensityBadge(intensity: intensity),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1, color: AppTheme.cardBorder),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNewAnalysisButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.pushReplacementNamed(
        context,
        AppRouter.sleepAnalysis,
      ),
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Analyse Another Recording'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.surfaceElevated,
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: AppTheme.cardBorder),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  String _formatTimestamp(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }
}

class _IntensityBadge extends StatelessWidget {
  final int intensity;

  const _IntensityBadge({required this.intensity});

  Color get _color {
    if (intensity >= 70) return AppTheme.error;
    if (intensity >= 45) return AppTheme.primaryGold;
    return AppTheme.accentTeal;
  }

  String get _label {
    if (intensity >= 70) return 'High';
    if (intensity >= 45) return 'Med';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
