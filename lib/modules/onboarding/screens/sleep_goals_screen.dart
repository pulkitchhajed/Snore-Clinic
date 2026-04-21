import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';
import 'permissions_screen.dart';

class SleepGoalsScreen extends StatefulWidget {
  const SleepGoalsScreen({super.key});
  @override
  State<SleepGoalsScreen> createState() => _SleepGoalsScreenState();
}

class _SleepGoalsScreenState extends State<SleepGoalsScreen> {
  TimeOfDay _bedtime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 6, minute: 30);
  int _goalHours = 8;

  String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime(bool isBed) async {
    final initial = isBed ? _bedtime : _wakeTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isBed) {
          _bedtime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Sleep Goals'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepIndicator(2, 3),
              const SizedBox(height: 24),
              Text('Set your sleep goals',
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text('We\'ll notify you at the right time and track your progress.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 40),

              _timeTile('🌙 Bedtime', _fmt(_bedtime), () => _pickTime(true)),
              const SizedBox(height: 16),
              _timeTile('☀️ Wake Time', _fmt(_wakeTime), () => _pickTime(false)),
              const SizedBox(height: 32),

              Text('Sleep Duration Goal: $_goalHours hours',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              Slider(
                value: _goalHours.toDouble(),
                min: 4, max: 12,
                divisions: 8,
                label: '$_goalHours h',
                activeColor: AppTheme.primaryGold,
                onChanged: (v) => setState(() => _goalHours = v.round()),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Adults typically need 7–9 hours. Aim for consistency.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    final p = context.read<OnboardingProvider>();
    p.updateBedtime(_fmt(_bedtime));
    p.updateWakeTime(_fmt(_wakeTime));
    p.updateGoalDuration(_goalHours * 60);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PermissionsScreen()));
  }

  Widget _timeTile(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: i < current ? AppTheme.primaryIndigo : AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
