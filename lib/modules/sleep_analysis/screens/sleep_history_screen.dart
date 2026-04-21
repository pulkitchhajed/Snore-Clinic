import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/sleep_analysis_provider.dart';
import '../models/sleep_report.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<SleepAnalysisProvider>().loadHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SleepAnalysisProvider>(
        builder: (context, provider, _) {
          if (provider.history.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: provider.history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final report = provider.history[index];
              return _HistoryCard(
                report: report,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRouter.sleepReport,
                  arguments: report,
                ),
                onDelete: () => _confirmDelete(context, provider, report),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded, size: 80, color: AppTheme.cardBorder),
          const SizedBox(height: 20),
          Text(
            'No Sleep History Yet',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Your future recordings and analysis will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SleepAnalysisProvider provider, SleepReport report) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text('This will permanently remove this sleep analysis result.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (delete == true) {
      provider.deleteFromHistory(report);
    }
  }
}

class _HistoryCard extends StatelessWidget {
  final SleepReport report;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.report,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, MMM d, yyyy').format(report.recordedAt);
    final time = DateFormat('h:mm a').format(report.recordedAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _getQualityColor(report.quality).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  report.qualityEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$time • ${report.totalDuration.inHours}h ${report.totalDuration.inMinutes % 60}m',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${report.qualityScore.toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: _getQualityColor(report.quality),
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getQualityColor(SleepQuality quality) {
    switch (quality) {
      case SleepQuality.excellent: return AppTheme.success;
      case SleepQuality.good: return AppTheme.accentTeal;
      case SleepQuality.fair: return AppTheme.primaryGold;
      case SleepQuality.poor: return AppTheme.error;
    }
  }
}
