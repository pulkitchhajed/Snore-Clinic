import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../sleep_analysis/services/sleep_storage_service.dart';
import '../../sleep_analysis/models/sleep_report.dart';
import '../services/gemini_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<SleepReport> _reports = [];
  bool _loading = true;
  Map<String, dynamic>? _aiSummary;
  final _gemini = GeminiService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await SleepStorageService().getAllReports();
    Map<String, dynamic>? summary;
    if (data.isNotEmpty) {
      summary = await _gemini.analyzeSession(data.first, null);
    }
    setState(() {
      _reports = data;
      _aiSummary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Insights & Analytics'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo))
          : _reports.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryIndigo,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // AI Summary Card
                      if (_aiSummary != null) _aiCard(),
                      const SizedBox(height: 20),
                      // Stats Row
                      _statsRow(),
                      const SizedBox(height: 24),
                      Text('Sleep Quality Trend',
                          style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 12),
                      _qualityChart(),
                      const SizedBox(height: 24),
                      Text('Snoring Duration (min)',
                          style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 12),
                      _snoringChart(),
                      const SizedBox(height: 24),
                      Text('Recent Sessions',
                          style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 12),
                      ..._reports.take(10).map((r) => _reportRow(r)),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
    );
  }

  Widget _aiCard() {
    final ai = _aiSummary!;
    final score = ai['aiScore'] ?? 0;
    final rec = ai['recommendation'] ?? 'No recommendation available.';
    final factors = ai['lifestyleFactors'] as List<dynamic>? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryIndigo.withValues(alpha: 0.3),
            AppTheme.primaryIndigo.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryIndigo.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🤖', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('AI Analysis',
              style: TextStyle(
                  color: AppTheme.primaryIndigo,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('AI Score: $score', style: const TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold, fontSize: 12)),
          )
        ]),
        const SizedBox(height: 16),
        Text(rec,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 14, height: 1.6)),
        if (factors.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Identified Factors:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: factors.map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder)
              ),
              child: Text(f.toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            )).toList(),
          ),
        ]
      ]),
    );
  }

  Widget _statsRow() {
    final avg = _reports.isEmpty
        ? 0.0
        : _reports.map((r) => r.qualityScore).reduce((a, b) => a + b) /
            _reports.length;
    final avgSnore = _reports.isEmpty
        ? 0
        : _reports
                .map((r) => r.snoringDuration.inMinutes)
                .reduce((a, b) => a + b) ~/
            _reports.length;
    final total = _reports.length;

    return Row(children: [
      _statCard('Avg Score', '${avg.toInt()}', '📊', AppTheme.primaryIndigo),
      const SizedBox(width: 10),
      _statCard('Snore Avg', '${avgSnore}m', '🔊', AppTheme.error),
      const SizedBox(width: 10),
      _statCard('Sessions', '$total', '🌙', AppTheme.accentTeal),
    ]);
  }

  Widget _statCard(String label, String value, String icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _qualityChart() {
    final spots = _reports.reversed
        .take(7)
        .toList()
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.qualityScore))
        .toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _reports.length) return const SizedBox();
                final r = _reports.reversed.toList()[idx];
                return Text(DateFormat('d/M').format(r.recordedAt),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10));
              },
            )),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.primaryIndigo,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snoringChart() {
    final bars = _reports.reversed
        .take(7)
        .toList()
        .asMap()
        .entries
        .map((e) => BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.snoringDuration.inMinutes.toDouble(),
                  color: e.value.snoringDuration.inMinutes > 30
                      ? AppTheme.error
                      : AppTheme.accentTeal,
                  width: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ))
        .toList();

    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: bars,
        ),
      ),
    );
  }

  Widget _reportRow(SleepReport r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(children: [
        Text(DateFormat('MMM d').format(r.recordedAt),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        Text('Score ${r.qualityScore.toInt()}',
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(width: 16),
        Text('${r.snoringDuration.inMinutes}m snore',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('📈', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        Text('No data yet', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Record your first sleep session to\nunlock insights and trends.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center),
      ]),
    );
  }
}
