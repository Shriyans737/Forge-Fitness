import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../theme.dart';
import 'dashboard_card.dart';

class DashboardNutritionCard extends StatelessWidget {
  const DashboardNutritionCard({
    required this.calories,
    required this.calorieGoal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.fat,
    required this.fatGoal,
    required this.onAddFood,
    required this.reduceMotion,
    this.onOpenNutrition,
    super.key,
  });

  final double calories;
  final double calorieGoal;
  final double protein;
  final double proteinGoal;
  final double carbs;
  final double carbsGoal;
  final double fat;
  final double fatGoal;
  final VoidCallback onAddFood;
  final bool reduceMotion;
  final VoidCallback? onOpenNutrition;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final left = (calorieGoal - calories).clamp(0.0, double.infinity);
    return DashboardCard(
      onTap: onOpenNutrition,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('NUTRITION', style: Theme.of(context).textTheme.labelLarge),
              ),
              Text(
                '${left.round()} kcal left',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: tokens.accentTeal,
                    ),
              ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.md),
          Text(
            '${calories.round()}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            'of ${calorieGoal.round()} kcal',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
          ),
          const SizedBox(height: ForgeSpacing.md),
          _MacroBar(
            label: 'Protein',
            value: protein,
            goal: proteinGoal,
            color: tokens.accentTeal,
            reduceMotion: reduceMotion,
          ),
          const SizedBox(height: ForgeSpacing.sm),
          _MacroBar(
            label: 'Carbs',
            value: carbs,
            goal: carbsGoal,
            color: tokens.accentLime,
            reduceMotion: reduceMotion,
          ),
          const SizedBox(height: ForgeSpacing.sm),
          _MacroBar(
            label: 'Fat',
            value: fat,
            goal: fatGoal,
            color: tokens.energyGradient.colors.first,
            reduceMotion: reduceMotion,
          ),
          const SizedBox(height: ForgeSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAddFood,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add food'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    required this.reduceMotion,
  });

  final String label;
  final double value;
  final double goal;
  final Color color;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.pillRadius),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0,
              ),
              duration: reduceMotion ? Duration.zero : ForgeMotion.chartBar,
              curve: ForgeMotion.easeOut,
              builder: (context, progress, _) => LinearProgressIndicator(
                value: progress,
                minHeight: ForgeSpacing.xs,
                backgroundColor: tokens.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: ForgeSpacing.xs),
        SizedBox(
          width: 54,
          child: Text(
            '${value.round()}g',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
