import 'package:flutter/material.dart';

import '../models/subscription_plan.dart';
import '../../../core/theme/app_theme.dart';

/// A premium-styled plan card with price, badge, and subscribe button.
class PlanCardWidget extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final bool isCurrentPlan;
  final VoidCallback onTap;

  const PlanCardWidget({
    super.key,
    required this.plan,
    required this.isSelected,
    required this.isCurrentPlan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAnnual = plan.tier == PlanTier.annual;
    final borderColor = isSelected
        ? AppTheme.primaryIndigo
        : AppTheme.cardBorder;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryIndigo.withValues(alpha: 0.18),
                    AppTheme.surfaceElevated,
                  ],
                )
              : null,
          color: isSelected ? null : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 8),
                  _buildPrice(context),
                  const SizedBox(height: 6),
                  Text(
                    plan.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (isAnnual) ...[
                    const SizedBox(height: 10),
                    _buildSavingsBadge(context),
                  ],
                  const SizedBox(height: 16),
                  _buildSelectButton(context),
                ],
              ),
            ),
            if (plan.badge != null) _buildTopBadge(plan.badge!),
            if (isCurrentPlan) _buildCurrentPlanBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            plan.tier == PlanTier.annual
                ? Icons.workspace_premium_rounded
                : Icons.star_rounded,
            color: AppTheme.primaryGold,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          plan.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }

  Widget _buildPrice(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: plan.price,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          TextSpan(
            text: '  ${plan.billingCycle}',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
      ),
      child: const Text(
        '💰  Save ₹1,589 vs monthly',
        style: TextStyle(
          color: AppTheme.success,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSelectButton(BuildContext context) {
    if (isCurrentPlan) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
            SizedBox(width: 8),
            Text(
              'Current Plan',
              style: TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [AppTheme.primaryIndigo, Color(0xFF8B83FF)],
              )
            : null,
        color: isSelected ? null : AppTheme.cardBorder.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isSelected ? 'Subscribe Now' : 'Select Plan',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTopBadge(String label) {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryGold, Color(0xFFFF9800)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlanBadge() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.5)),
        ),
        child: const Text(
          '✓ Active',
          style: TextStyle(
            color: AppTheme.success,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
