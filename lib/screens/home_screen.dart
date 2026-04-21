import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../modules/onboarding/providers/onboarding_provider.dart';
import '../modules/sleep_analysis/services/sleep_storage_service.dart';
import '../modules/sleep_analysis/models/sleep_report.dart';
import '../modules/paywall/providers/subscription_provider.dart';
import '../core/router/app_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SleepReport> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final reports = await SleepStorageService().getAllReports();
    if (mounted) {
      setState(() {
        _recent = reports.take(7).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<OnboardingProvider>().profile;
    final greeting = _greeting();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecent,
          color: AppTheme.primaryIndigo,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(greeting,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14)),
                      Text(profile.name.isEmpty ? 'Good to see you!' : profile.name,
                          style: Theme.of(context).textTheme.displayMedium),
                    ]),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRouter.settings),
                      child: CircleAvatar(
                        backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.2),
                        child: Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '👤',
                          style: const TextStyle(
                              fontSize: 20, color: AppTheme.primaryIndigo),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Last night summary
                _lastNightCard(),
                const SizedBox(height: 20),

                // Quick Actions
                Text('Quick Actions',
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 12),
                Row(children: [
                  _quickAction(
                    '🎙️', 'Record Sleep',
                    AppTheme.primaryIndigo,
                    () => Navigator.pushNamed(context, AppRouter.sleepAnalysis),
                  ),
                  const SizedBox(width: 12),
                  _quickAction(
                    '😴', 'Relax',
                    AppTheme.accentTeal,
                    () => Navigator.pushNamed(context, AppRouter.relaxation),
                  ),
                  const SizedBox(width: 12),
                  _quickAction(
                    '📝', 'Journal',
                    AppTheme.primaryGold,
                    () => Navigator.pushNamed(context, AppRouter.eveningJournal),
                  ),
                ]),
                const SizedBox(height: 16),

                // Premium Upgrade Banner
                _premiumBanner(context),
                const SizedBox(height: 24),

                // History Preview
                if (_recent.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Sessions',
                          style: Theme.of(context).textTheme.headlineLarge),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRouter.sleepHistory),
                        child: const Text('See All',
                            style: TextStyle(color: AppTheme.primaryIndigo)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._recent.map((r) => _sessionTile(r)),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lastNightCard() {
    if (_recent.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryIndigo.withValues(alpha: 0.3),
              AppTheme.primaryIndigo.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(children: [
          const Text('🌙', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('No sleep data yet',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Record your first sleep session tonight!',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRouter.sleepAnalysis),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('Start Recording'),
          ),
        ]),
      );
    }

    final last = _recent.first;
    final snoreColor = last.qualityScore >= 85
        ? AppTheme.success
        : last.qualityScore >= 65
            ? AppTheme.primaryGold
            : AppTheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D3A), Color(0xFF0F1120)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Last Night',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statCol('Sleep', _formatDur(last.totalDuration), '⏱️'),
          _divider(),
          _statCol('Snore Score', '${last.qualityScore.toInt()}',
              last.qualityScore >= 75 ? '🌟' : '😮',
              color: snoreColor),
          _divider(),
          _statCol('Events', '${last.snoringEventCount}', '🔊'),
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, AppRouter.sleepReport, arguments: last),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.4))),
            child: const Center(
                child: Text('View Full Report',
                    style: TextStyle(
                        color: AppTheme.primaryIndigo,
                        fontWeight: FontWeight.w600))),
          ),
        ),
      ]),
    );
  }

  Widget _statCol(String label, String value, String emoji,
      {Color color = AppTheme.textPrimary}) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.w700)),
      Text(label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ]);
  }

  Widget _divider() => Container(
        width: 1, height: 50,
        color: AppTheme.cardBorder,
      );

  Widget _quickAction(
      String emoji, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 12),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _sessionTile(SleepReport r) {
    final color = r.qualityScore >= 75 ? AppTheme.success : AppTheme.primaryGold;
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRouter.sleepReport, arguments: r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text('${r.qualityScore.toInt()}',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('EEE, MMM d').format(r.recordedAt),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              Text(
                  '${_formatDur(r.totalDuration)} • ${r.snoringEventCount} snore events',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ]),
      ),
    );
  }

  String _formatDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    if (hour < 21) return 'Good evening,';
    return 'Sleep well tonight,';
  }

  Widget _premiumBanner(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    if (sub.isPremium) {
      // Already premium — subtle badge
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.verified_rounded, color: AppTheme.success, size: 20),
          const SizedBox(width: 10),
          Text('Premium Active',
              style: TextStyle(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const Spacer(),
          Text(sub.currentPlan.name,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ]),
      );
    }

    // Free tier — upgrade banner
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRouter.paywall),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E245E), Color(0xFF1A1D3A)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryIndigo.withValues(alpha: 0.25),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: AppTheme.primaryGold, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [AppTheme.primaryGold, Color(0xFFFFD700)],
                    ).createShader(rect),
                    child: const Text('Unlock Premium',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  ),
                  const SizedBox(height: 2),
                  const Text('AI insights, sleep stages & more',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: AppTheme.primaryGold, size: 16),
        ]),
      ),
    );
  }
}
