import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../onboarding/screens/profile_setup_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<OnboardingProvider>().profile;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Profile card
          _profileCard(context, profile.name, profile.age),
          const SizedBox(height: 28),

          _sectionHeader('Account'),
          _tile(context,
            icon: Icons.person_outline_rounded,
            label: 'Edit Profile',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileSetupScreen())),
          ),
          _tile(context,
            icon: auth.isAuthenticated ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            label: 'Cloud Sync',
            subtitle: auth.isAuthenticated ? 'Data synced to ${auth.user?.email}' : 'Not synced (Guest Mode)',
            onTap: auth.isAuthenticated ? null : () {
              // Trigger Google sign in to link account
              auth.signInWithGoogle();
            },
          ),
          _tile(context,
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            iconColor: AppTheme.error,
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: 24),

          _sectionHeader('Notifications'),
          _switchTile(context,
            icon: Icons.notifications_outlined,
            label: 'Bedtime Reminder',
            subtitle: 'Alert at ${profile.bedtime}',
            value: true,
            onChanged: (_) {},
          ),
          _switchTile(context,
            icon: Icons.wb_sunny_outlined,
            label: 'Morning Prompt',
            subtitle: 'Prompt to log morning journal',
            value: true,
            onChanged: (_) {},
          ),
          const SizedBox(height: 24),

          _sectionHeader('Privacy & Data'),
          _tile(context,
            icon: Icons.delete_outline_rounded,
            label: 'Clear All Sleep Data',
            iconColor: AppTheme.error,
            onTap: () => _confirmClear(context),
          ),
          _tile(context,
            icon: Icons.info_outline_rounded,
            label: 'Privacy Policy',
            onTap: () {},
          ),
          const SizedBox(height: 24),

          _sectionHeader('About'),
          _tile(context,
            icon: Icons.star_outline_rounded,
            label: 'Rate SnoreClinics AI',
            onTap: () {},
          ),
          _tile(context,
            icon: Icons.code_rounded,
            label: 'Version 2.0.0',
            onTap: null,
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _profileCard(BuildContext context, String name, int age) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.3),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '😴',
            style: const TextStyle(fontSize: 28, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isEmpty ? 'SnoreClinics User' : name,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          Text('Age $age • SnoreClinics AI v2.0',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ]),
      ]),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.2)),
      );

  Widget _tile(BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.primaryIndigo).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.primaryIndigo, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary)
          : null,
      onTap: onTap,
    );
  }

  Widget _switchTile(BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryIndigo, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.primaryIndigo,
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
            'This will permanently delete all sleep sessions, journals, and your profile. Are you sure?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await context.read<OnboardingProvider>().clearProfile();
              if (!context.mounted) return;
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (_) => false,
              );
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
            'Are you sure you want to sign out? Your data will remain safely in the cloud.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (!context.mounted) return;
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (_) => false,
              );
            },
            child: const Text('Sign Out',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
