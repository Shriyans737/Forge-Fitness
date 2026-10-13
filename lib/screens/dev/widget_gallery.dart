import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/ui/floating_bottom_nav.dart';
import '../../widgets/ui/gradient_ring.dart';
import '../../widgets/ui/pill_tag.dart';
import '../../widgets/ui/primary_gradient_button.dart';
import '../../widgets/ui/section_header.dart';
import '../../widgets/ui/shimmer_box.dart';
import '../../widgets/ui/sparkline_chart.dart';
import '../../widgets/ui/stat_card.dart';
import '../../widgets/ui/vertical_pill_gauge.dart';

class WidgetGalleryScreen extends StatefulWidget {
  const WidgetGalleryScreen({super.key});

  @override
  State<WidgetGalleryScreen> createState() => _WidgetGalleryScreenState();
}

class _WidgetGalleryScreenState extends State<WidgetGalleryScreen> {
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget gallery')),
      body: ListView(
        padding: const EdgeInsets.all(ForgeSpacing.md),
        children: [
          _themeGallery('Dark', ForgeTheme.darkTheme),
          const SizedBox(height: ForgeSpacing.lg),
          _themeGallery('Light', ForgeTheme.lightTheme),
        ],
      ),
    );
  }

  Widget _themeGallery(String title, ThemeData theme) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final tokens = Theme.of(context).extension<ForgeTokens>()!;
          return Container(
            padding: const EdgeInsets.all(ForgeSpacing.md),
            decoration: BoxDecoration(
              color: tokens.background,
              borderRadius: BorderRadius.circular(tokens.heroRadius),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: ForgeSpacing.lg),
                const SectionHeader(
                  title: 'Training overview',
                  actionLabel: 'View all',
                  onAction: _noop,
                ),
                const SizedBox(height: ForgeSpacing.sm),
                const Wrap(
                  spacing: ForgeSpacing.sm,
                  runSpacing: ForgeSpacing.sm,
                  children: [
                    PillTag(
                      label: 'On track',
                      variant: PillTagVariant.success,
                      icon: Icons.check_circle_outline,
                    ),
                    PillTag(label: 'Recovery', variant: PillTagVariant.warning),
                    PillTag(
                      label: 'This week',
                      variant: PillTagVariant.neutral,
                    ),
                    PillTag(label: 'Selected', variant: PillTagVariant.accent),
                  ],
                ),
                const SizedBox(height: ForgeSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth =
                        (constraints.maxWidth - ForgeSpacing.sm) / 2;
                    return Wrap(
                      spacing: ForgeSpacing.sm,
                      runSpacing: ForgeSpacing.sm,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: const StatCard(
                            label: 'Workouts',
                            number: '12',
                            unit: 'sessions',
                            trend: StatTrend.up,
                            delta: '+2 this week',
                            icon: Icons.fitness_center,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: const StatCard(
                            label: 'Resting HR',
                            number: '58',
                            unit: 'bpm',
                            trend: StatTrend.down,
                            delta: '-3 bpm',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: ForgeSpacing.lg),
                Text(
                  'Gradient rings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: ForgeSpacing.sm),
                const Wrap(
                  spacing: ForgeSpacing.md,
                  runSpacing: ForgeSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GradientRing(value: 0, size: ForgeSpacing.xxxl),
                    GradientRing(value: 1, size: ForgeSpacing.xxxl),
                    GradientRing(value: null, size: ForgeSpacing.xxxl),
                    GradientRing(
                      value: 0.68,
                      size: ForgeSpacing.xxxl,
                      centerChild: Text('68%'),
                    ),
                  ],
                ),
                const SizedBox(height: ForgeSpacing.lg),
                Text(
                  'Sparkline edge cases',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: ForgeSpacing.sm),
                const SparklineChart(values: []),
                const SizedBox(height: ForgeSpacing.xs),
                const SparklineChart(values: [4]),
                const SizedBox(height: ForgeSpacing.xs),
                const SparklineChart(values: [2, 5, 3, 8, 6, 9, 7]),
                const SizedBox(height: ForgeSpacing.lg),
                Text('Vitals', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: ForgeSpacing.sm),
                const Wrap(
                  spacing: ForgeSpacing.lg,
                  runSpacing: ForgeSpacing.md,
                  children: [
                    VerticalPillGauge(value: 0, label: 'Low'),
                    VerticalPillGauge(value: 1, label: 'Peak'),
                    VerticalPillGauge(value: 0.68, label: 'Sleep'),
                  ],
                ),
                const SizedBox(height: ForgeSpacing.lg),
                const PrimaryGradientButton(
                  label: 'Start workout',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _noop,
                  expand: true,
                ),
                const SizedBox(height: ForgeSpacing.sm),
                const PrimaryGradientButton(
                  label: 'Preparing workout',
                  onPressed: null,
                  isLoading: true,
                  expand: true,
                ),
                const SizedBox(height: ForgeSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ShimmerBox(
                        height: ForgeSpacing.xl,
                        borderRadius: tokens.controlRadius,
                      ),
                    ),
                    const SizedBox(width: ForgeSpacing.sm),
                    ShimmerBox(
                      width: ForgeSpacing.xxl,
                      height: ForgeSpacing.xxl,
                      borderRadius: tokens.controlRadius,
                    ),
                  ],
                ),
                const SizedBox(height: ForgeSpacing.md),
                FloatingBottomNav(
                  items: const [
                    FloatingNavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                    ),
                    FloatingNavItem(
                      icon: Icons.fitness_center_outlined,
                      selectedIcon: Icons.fitness_center_rounded,
                      label: 'Train',
                    ),
                    FloatingNavItem(
                      icon: Icons.favorite_outline,
                      selectedIcon: Icons.favorite_rounded,
                      label: 'Health',
                    ),
                    FloatingNavItem(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person_rounded,
                      label: 'Profile',
                    ),
                  ],
                  selectedIndex: _selectedNavIndex,
                  onTap: (index) => setState(() => _selectedNavIndex = index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void _noop() {}
}
