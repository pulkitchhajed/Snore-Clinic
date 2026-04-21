import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';
import 'sleep_goals_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  int _age = 25;
  String _gender = 'male';
  double _weight = 70;
  double _height = 170;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Your Profile'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepIndicator(1, 3),
              const SizedBox(height: 24),
              Text('Tell us about yourself',
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text('This helps us calculate your BMI and personalise analysis.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),

              // Name
              _label('Your Name'),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _inputDeco('e.g. Arjun'),
              ),
              const SizedBox(height: 24),

              // Age
              _label('Age: $_age years'),
              Slider(
                value: _age.toDouble(),
                min: 13, max: 90,
                divisions: 77,
                activeColor: AppTheme.primaryIndigo,
                onChanged: (v) => setState(() => _age = v.round()),
              ),
              const SizedBox(height: 16),

              // Gender
              _label('Gender'),
              const SizedBox(height: 8),
              Row(
                children: ['male', 'female', 'other'].map((g) {
                  final selected = _gender == g;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _gender = g),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryIndigo.withValues(alpha: 0.2)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryIndigo
                                : AppTheme.cardBorder,
                          ),
                        ),
                        child: Text(
                          g[0].toUpperCase() + g.substring(1),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? AppTheme.primaryIndigo
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Weight
              _label('Weight: ${_weight.toStringAsFixed(1)} kg'),
              Slider(
                value: _weight,
                min: 30, max: 200,
                activeColor: AppTheme.accentTeal,
                onChanged: (v) => setState(() => _weight = v),
              ),
              const SizedBox(height: 16),

              // Height
              _label('Height: ${_height.toStringAsFixed(0)} cm'),
              Slider(
                value: _height,
                min: 100, max: 220,
                activeColor: AppTheme.accentTeal,
                onChanged: (v) => setState(() => _height = v),
              ),
              const SizedBox(height: 40),

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
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    final provider =
        context.read<OnboardingProvider>();
    provider.updateName(_nameCtrl.text.trim().isEmpty
        ? 'Friend'
        : _nameCtrl.text.trim());
    provider.updateAge(_age);
    provider.updateGender(_gender);
    provider.updateWeight(_weight);
    provider.updateHeight(_height);

    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SleepGoalsScreen()));
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
    );
  }

  Widget _stepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primaryIndigo
                  : AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.cardBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.cardBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppTheme.primaryIndigo, width: 1.5)),
      );
}
