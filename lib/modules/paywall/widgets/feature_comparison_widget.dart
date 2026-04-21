import 'package:flutter/material.dart';

import '../models/subscription_plan.dart';
import '../../../core/theme/app_theme.dart';

/// Full feature comparison table: Free vs Premium columns.
class FeatureComparisonWidget extends StatelessWidget {
  const FeatureComparisonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          _buildTableHeader(context),
          const Divider(height: 1, color: AppTheme.cardBorder),
          ...Plans.features.asMap().entries.map((entry) {
            final isLast = entry.key == Plans.features.length - 1;
            return Column(
              children: [
                _buildFeatureRow(context, entry.value),
                if (!isLast)
                  const Divider(height: 1, color: AppTheme.cardBorder),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Feature',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Trial',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [AppTheme.primaryIndigo, Color(0xFF8B83FF)],
                ).createShader(rect),
                child: const Text(
                  'Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, PlanFeature feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature.name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _CheckIcon(included: feature.includedInFree),
            ),
          ),
          Expanded(
            child: Center(
              child: _CheckIcon(
                included: feature.includedInPremium,
                premiumStyle: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckIcon extends StatelessWidget {
  final bool included;
  final bool premiumStyle;

  const _CheckIcon({required this.included, this.premiumStyle = false});

  @override
  Widget build(BuildContext context) {
    if (included) {
      return Icon(
        Icons.check_circle_rounded,
        color: premiumStyle ? AppTheme.primaryIndigo : AppTheme.success,
        size: 18,
      );
    }
    return const Icon(
      Icons.remove_circle_outline_rounded,
      color: AppTheme.cardBorder,
      size: 18,
    );
  }
}
