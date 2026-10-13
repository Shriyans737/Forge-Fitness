import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/motion.dart';
import '../models/body_log_model.dart';
import '../models/food_log_model.dart';
import '../models/workout_session.dart';
import '../services/health_service.dart';
import '../services/open_food_facts_service.dart';
import '../theme.dart';
import '../widgets/ui/gradient_ring.dart';
import '../widgets/ui/primary_gradient_button.dart';
import '../widgets/ui/section_header.dart' as forge_ui;
import '../widgets/ui/shimmer_box.dart';
import '../widgets/ui/sparkline_chart.dart';
import '../widgets/ui/vertical_pill_gauge.dart' as forge_ui;
import '../widgets/net_energy_gradient_bar.dart';
import '../widgets/ui/health_sync_button.dart';
import '../widgets/vital_pill_gauge.dart';
import 'active_workout_screen.dart';
import 'barcode_scanner_screen.dart';
import 'food_search_screen.dart';
import 'manual_food_entry_screen.dart';
import 'photo_food_review_screen.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({
    this.initialTabIndex = 0,
    this.entryReplayKey = 0,
    this.onOpenCoach,
    super.key,
  });

  final int initialTabIndex;
  final int entryReplayKey;
  final ValueChanged<BuildContext>? onOpenCoach;

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final HealthService _healthService = HealthService();
  late Future<HealthSummary?> _summaryFuture;
  late Future<List<HealthWorkoutEntry>> _workoutsFuture;
  late final TabController _tabController;
  bool _isSyncing = false;
  DateTime? _lastAutoSync;
  DateTime? _lastSyncedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(
      length: 3,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
      vsync: this,
    );
    _summaryFuture = Future.value(null);
    _workoutsFuture = _healthService.fetchRecentWorkouts(7);
    final syncedValue = Hive.box<dynamic>('settings').get('healthLastSyncedAt');
    _lastSyncedAt = switch (syncedValue) {
      DateTime value => value,
      int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    };
    unawaited(_syncHealth(showFeedback: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final lastSync = _lastAutoSync;
    if (lastSync == null ||
        DateTime.now().difference(lastSync) >= const Duration(minutes: 1)) {
      _lastAutoSync = DateTime.now();
      _syncHealth(showFeedback: false);
    }
  }

  Future<void> _syncHealth({bool showFeedback = true}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    var succeeded = false;
    var feedback = 'Health data could not be synced.';
    try {
      final summary = await _healthService.syncTodaySummary();
      if (!mounted) return;
      succeeded = summary?.fetchSucceeded == true;
      if (summary?.hasPermissions == true &&
          summary?.sleepAsleepMinutes == null &&
          _sleepQueryFailed(summary!)) {
        feedback = "Couldn't read sleep data. Check Settings > Privacy > Health > Forge.";
      } else if (summary?.hasPermissions == true &&
          (summary!.failedTypes.contains(HealthDataType.STEPS) ||
              summary.failedTypes.contains(
                HealthDataType.ACTIVE_ENERGY_BURNED,
              ))) {
        feedback = "Couldn't read activity data. Check Settings > Privacy > Health > Forge.";
      } else if (summary?.hasPermissions == true &&
          summary?.sleepAsleepMinutes == null) {
        feedback = 'No sleep data found for last night. Available health data was refreshed.';
      } else if (succeeded) {
        feedback = 'Synced';
      } else {
        feedback = 'Health data could not be synced. Check Settings > Privacy > Health > Forge.';
      }
      if (kDebugMode && summary?.syncErrors.isNotEmpty == true) {
        debugPrint('Health sync partial failures: ${summary!.syncErrors}');
      }
      final syncedValue = Hive.box<dynamic>('settings')
          .get('healthLastSyncedAt');
      setState(() {
        _summaryFuture = Future.value(summary);
        _workoutsFuture = _healthService.fetchRecentWorkouts(7);
        _lastSyncedAt = switch (syncedValue) {
          DateTime value => value,
          int value => DateTime.fromMillisecondsSinceEpoch(value),
          _ => _lastSyncedAt,
        };
        _isSyncing = false;
      });
      _lastAutoSync = DateTime.now();
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('Health tab sync failed: $error\n$stackTrace');
      if (!mounted) return;
      feedback = 'Health data could not be synced. Check Settings > Privacy > Health > Forge.';
      setState(() {
        _summaryFuture = Future.error(error);
        _workoutsFuture = _healthService.fetchRecentWorkouts(7);
        _isSyncing = false;
      });
    }
    if (showFeedback && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(feedback),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _connectHealth() async {
    await _syncHealth();
  }

  bool _isWorkoutAlreadyLogged(HealthWorkoutEntry workout) {
    final box = Hive.box<WorkoutSession>('workoutSessions');
    final tolerance = const Duration(minutes: 10);

    for (final session in box.values) {
      final sessionDate = session.date;
      final sameType =
          session.name.toLowerCase().contains(workout.type.toLowerCase()) ||
          workout.type.toLowerCase().contains(session.name.toLowerCase());
      final withinWindow =
          sessionDate.isAfter(workout.startTime.subtract(tolerance)) &&
          sessionDate.isBefore(workout.endTime.add(tolerance));
      if (sameType && withinWindow) {
        return true;
      }
    }
    return false;
  }

  Future<void> _openWorkoutLogging(HealthWorkoutEntry workout) async {
    final durationMinutes = workout.endTime
        .difference(workout.startTime)
        .inMinutes;
    final formatted = workout.type.trim().isNotEmpty ? workout.type : 'Workout';

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(
          initialWorkoutName: formatted,
          initialDurationMinutes: durationMinutes > 0 ? durationMinutes : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          if (widget.onOpenCoach != null)
            IconButton(
              tooltip: 'Health Coach',
              onPressed: () => widget.onOpenCoach!(context),
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
          HealthSyncButton(
            isSyncing: _isSyncing,
            onPressed: () => _syncHealth(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Body Log'),
            Tab(text: 'Nutrition'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _syncHealth(showFeedback: false),
        child: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(
              summaryFuture: _summaryFuture,
              workoutsFuture: _workoutsFuture,
              lastSyncedAt: _lastSyncedAt,
              replayKey: widget.entryReplayKey,
              onConnect: _connectHealth,
              onLog: _openWorkoutLogging,
              isLogged: _isWorkoutAlreadyLogged,
            ),
            const _BodyLogSection(),
            _NutritionTab(replayKey: widget.entryReplayKey),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.summaryFuture,
    required this.workoutsFuture,
    required this.lastSyncedAt,
    required this.replayKey,
    required this.onConnect,
    required this.onLog,
    required this.isLogged,
  });

  final Future<HealthSummary?> summaryFuture;
  final Future<List<HealthWorkoutEntry>> workoutsFuture;
  final DateTime? lastSyncedAt;
  final int replayKey;
  final VoidCallback onConnect;
  final Future<void> Function(HealthWorkoutEntry workout) onLog;
  final bool Function(HealthWorkoutEntry workout) isLogged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 +
            ForgeMotion.navBarHeight +
            ForgeMotion.navBottomInset +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        HealthOverviewRings(
          summaryFuture: summaryFuture,
          lastSyncedAt: lastSyncedAt,
        ),
        const SizedBox(height: 20),
        const forge_ui.SectionHeader(title: 'Activity'),
        const SizedBox(height: 12),
        _HealthSummaryCard(
          summaryFuture: summaryFuture,
          onConnect: onConnect,
          replayKey: replayKey,
        ),
        const SizedBox(height: 20),
        const forge_ui.SectionHeader(title: 'Watch Workouts'),
        const SizedBox(height: 12),
        _WatchWorkoutsCard(
          workoutsFuture: workoutsFuture,
          onConnect: onConnect,
          onLog: onLog,
          isLogged: isLogged,
        ),
      ],
    );
  }
}

class HealthOverviewRings extends StatelessWidget {
  const HealthOverviewRings({
    required this.summaryFuture,
    required this.lastSyncedAt,
    super.key,
  });

  final Future<HealthSummary?> summaryFuture;
  final DateTime? lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return FutureBuilder<HealthSummary?>(
      future: summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerBox(
            height: ForgeSpacing.xxxl * 2,
            borderRadius: ForgeSpacing.lg,
          );
        }
        if (snapshot.hasError) {
          return _HealthMessageCard(
            icon: Icons.sync_problem_rounded,
            message: 'Health data could not be loaded. Pull down to try again.',
          );
        }

        final summary = snapshot.data;
        if (summary == null) {
          return _HealthMessageCard(
            icon: Icons.monitor_heart_outlined,
            message: 'No health data is available yet.',
          );
        }

        const stepsGoal = 10000.0;
        const activeEnergyGoal = 500.0;
        const sleepGoalMinutes = 8.0 * 60.0;
        final rings = [
          (
            label: 'Steps',
            raw: summary.steps?.toDouble(),
            goal: stepsGoal,
            detail: summary.failedTypes.contains(HealthDataType.STEPS)
                ? "Couldn't read (check Health permissions)"
                : summary.steps == null
                ? 'No reading'
                : '${_shortNumber(summary.steps!)} / ${_shortNumber(stepsGoal)}',
            gradient: tokens.primaryGradient,
          ),
          (
            label: 'Active',
            raw: summary.activeCaloriesBurned,
            goal: activeEnergyGoal,
            detail:
                summary.failedTypes.contains(
                  HealthDataType.ACTIVE_ENERGY_BURNED,
                )
                ? "Couldn't read (check Health permissions)"
                : summary.activeCaloriesBurned == null
                ? 'No reading'
                : '${_shortNumber(summary.activeCaloriesBurned!)} / ${_shortNumber(activeEnergyGoal)} kcal',
            gradient: tokens.energyGradient,
          ),
          (
            label: 'Sleep',
            raw: summary.sleepAsleepMinutes,
            goal: sleepGoalMinutes,
            detail: _sleepQueryFailed(summary)
                ? "Couldn't read (check Health permissions)"
                : summary.sleepAsleepMinutes == null
                ? 'No sleep data found for last night'
                : 'last night',
            gradient: tokens.recoveryGradient,
          ),
        ];

        return Container(
          padding: const EdgeInsets.all(ForgeSpacing.md),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(tokens.heroRadius),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today at a glance',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: ForgeSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rings
                    .map(
                      (ring) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ForgeSpacing.xxs,
                          ),
                          child: _HealthRingMetric(
                            label: ring.label,
                            value: ring.raw,
                            goal: ring.goal,
                            detail: ring.detail,
                            gradient: ring.gradient,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: ForgeSpacing.sm),
              Text(
                lastSyncedAt == null
                    ? 'Not synced yet'
                    : 'Last synced at ${DateFormat('MMM d, h:mm a').format(lastSyncedAt!)}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _shortNumber(num value) {
    final number = value.toDouble();
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number >= 10000 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '')}k';
    }
    return number.round().toString();
  }

  static String _formatSleep(double minutes) {
    final totalMinutes = minutes.round();
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours == 0) {
      return '${mins}m';
    }
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}m';
  }
}

class _HealthRingMetric extends StatelessWidget {
  const _HealthRingMetric({
    required this.label,
    required this.value,
    required this.goal,
    required this.detail,
    required this.gradient,
  });

  final String label;
  final double? value;
  final double goal;
  final String detail;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final hasValue = value != null;
    final progress = hasValue && goal > 0
        ? (value! / goal).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      children: [
        GradientRing(
          value: hasValue ? progress : 0,
          size: ForgeSpacing.xxxl,
          strokeWidth: ForgeSpacing.xxs,
          gradient: gradient,
          centerChild: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              hasValue ? _displayHealthValue(label, value!) : '—',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: tokens.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: ForgeSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ForgeSpacing.xxs),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: tokens.textSecondary),
        ),
      ],
    );
  }

  String _displayHealthValue(String label, double value) {
    if (label == 'Steps') return HealthOverviewRings._shortNumber(value);
    if (label == 'Active') return '${value.round()}';
    return HealthOverviewRings._formatSleep(value);
  }
}

class _HealthMessageCard extends StatelessWidget {
  const _HealthMessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: tokens.textSecondary),
          const SizedBox(width: ForgeSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class HealthStatCard extends StatelessWidget {
  const HealthStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.secondary,
    this.footer,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? secondary;
  final Widget? footer;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    final displayUnit = unit == null || unit!.isEmpty ? '' : unit!;

    return Container(
      height: 180,
      padding: EdgeInsets.all(palette.cardPadding),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(palette.cardRadius),
        border: Border.all(
          color: palette.secondaryText.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: palette.heroGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: valueColor ?? palette.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (displayUnit.isNotEmpty)
                  TextSpan(
                    text: ' $displayUnit',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 8),
            Text(
              secondary!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.secondaryText),
            ),
          ],
          const Spacer(),
          footer ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: palette.primaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.kind});

  final String label;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    final colors = switch (kind) {
      'Complete' => (
        fg: palette.statusCompleteFg,
        bg: palette.statusCompleteBg,
      ),
      'Progress' => (
        fg: palette.statusProgressFg,
        bg: palette.statusProgressBg,
      ),
      _ => (fg: palette.statusIncompleteFg, bg: palette.statusIncompleteBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: colors.fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class GoalGaugeCard extends StatelessWidget {
  const GoalGaugeCard({super.key, required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    final clamped = value.clamp(0.0, 100.0);

    return Container(
      padding: EdgeInsets.all(palette.cardPadding),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(palette.cardRadius),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: clamped / 100),
              duration: const Duration(milliseconds: 400),
              builder: (context, progress, _) {
                return CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: palette.secondaryText.withValues(
                    alpha: 0.18,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    palette.heroGradient.colors.first,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${clamped.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: palette.primaryText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.secondaryText),
          ),
        ],
      ),
    );
  }
}

class HealthSparkline extends StatelessWidget {
  const HealthSparkline({super.key, required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final span = (max - min).clamp(1.0, double.infinity);

    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((value) {
          final normalized = ((value - min) / span).clamp(0.0, 1.0);
          return Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 22 + (normalized * 8),
                decoration: BoxDecoration(
                  gradient: palette.heroGradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NutritionTab extends StatefulWidget {
  const _NutritionTab({this.replayKey = 0});

  final int replayKey;

  @override
  State<_NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<_NutritionTab> {
  final Box<FoodLog> _foodLogBox = Hive.box<FoodLog>('foodLogs');
  final Box<dynamic> _settingsBox = Hive.box<dynamic>('settings');

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  double _sumField(
    List<FoodLog> entries,
    double? Function(FoodLog entry) selector,
  ) {
    double total = 0;
    for (final entry in entries) {
      final value = selector(entry);
      if (value != null) {
        total += value;
      }
    }
    return total;
  }

  double? _readGoal(String key) {
    final value = _settingsBox.get(key);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Future<void> _openFoodSearch() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FoodSearchScreen()));
  }

  Future<void> _openBarcodeScan() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) {
      return;
    }

    final product = await OpenFoodFactsFoodService().lookupBarcode(barcode);
    if (!mounted) {
      return;
    }
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No matching product was found for this barcode.'),
        ),
      );
      return;
    }

    if (!product.nutrition.hasAnyValues) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManualFoodEntryScreen(initialFoodName: product.name),
        ),
      );
      return;
    }

    final quantity = await showDialog<double>(
      context: context,
      builder: (_) => FoodServingConfirmationDialog(product: product),
    );

    if (quantity == null || !mounted) {
      return;
    }

    final foodLog = product.toFoodLog(
      quantity: quantity,
      source: FoodLogSource.barcode,
    );
    await Hive.box<FoodLog>('foodLogs').put(foodLog.id, foodLog);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} added to today’s log.')),
      );
    }
  }

  Future<void> _openPhotoEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhotoFoodReviewScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo food added to today’s log.')),
      );
    }
  }

  Future<void> _openManualEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ManualFoodEntryScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food added to today’s log.')),
      );
    }
  }

  Future<void> _editEntry(FoodLog entry) async {
    final controller = TextEditingController(text: entry.quantity.toString());
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantity for ${entry.foodName}',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) {
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (value == null || !mounted) {
      return;
    }

    entry.quantity = value;
    await entry.save();
  }

  Future<void> _deleteEntry(FoodLog entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete food log?'),
        content: Text('Remove “${entry.foodName}” from today’s log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await entry.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return ValueListenableBuilder<Box<FoodLog>>(
      valueListenable: _foodLogBox.listenable(),
      builder: (context, box, _) {
        final today = DateTime.now();
        final entries =
            box.values
                .where((entry) => _isSameDay(entry.loggedAt, today))
                .toList()
              ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

        final totals = {
          'calories': _sumField(
            entries,
            (entry) => entry.caloriesPerServing == null
                ? null
                : entry.caloriesPerServing! * entry.quantity,
          ),
          'protein': _sumField(
            entries,
            (entry) => entry.proteinGramsPerServing == null
                ? null
                : entry.proteinGramsPerServing! * entry.quantity,
          ),
          'carbs': _sumField(
            entries,
            (entry) => entry.carbsGramsPerServing == null
                ? null
                : entry.carbsGramsPerServing! * entry.quantity,
          ),
          'fat': _sumField(
            entries,
            (entry) => entry.fatGramsPerServing == null
                ? null
                : entry.fatGramsPerServing! * entry.quantity,
          ),
        };

        final goals = {
          'calories': _readGoal('nutritionGoalCalories'),
          'protein': _readGoal('nutritionGoalProtein'),
          'carbs': _readGoal('nutritionGoalCarbs'),
          'fat': _readGoal('nutritionGoalFat'),
        };

        const defaultCaloriesGoal = 2000.0;
        const defaultProteinGoal = 150.0;
        const defaultCarbsGoal = 250.0;
        const defaultFatGoal = 70.0;
        final caloriesGoal = goals['calories'] ?? defaultCaloriesGoal;
        final caloriesLogged = totals['calories'] ?? 0.0;
        final proteinToday = totals['protein'] ?? 0.0;
        final carbsToday = totals['carbs'] ?? 0.0;
        final fatToday = totals['fat'] ?? 0.0;
        final proteinGoal = goals['protein'] ?? defaultProteinGoal;
        final carbsGoal = goals['carbs'] ?? defaultCarbsGoal;
        final fatGoal = goals['fat'] ?? defaultFatGoal;
        final proteinProgress = proteinGoal > 0
            ? proteinToday / proteinGoal
            : 0.0;
        final carbsProgress = carbsGoal > 0 ? carbsToday / carbsGoal : 0.0;
        final fatProgress = fatGoal > 0 ? fatToday / fatGoal : 0.0;
        debugPrint(
          'Nutrition totals: entries=${entries.length} calories=$caloriesLogged protein=$proteinToday '
          'carbs=$carbsToday fat=$fatToday goals=calories:$caloriesGoal protein:$proteinGoal carbs:$carbsGoal fat:$fatGoal | '
          'macroProgress p=$proteinProgress c=$carbsProgress f=$fatProgress',
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(
            ForgeSpacing.md,
            ForgeSpacing.md,
            ForgeSpacing.md,
            ForgeSpacing.md +
                ForgeMotion.navBarHeight +
                ForgeMotion.navBottomInset +
                MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(ForgeSpacing.lg),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(tokens.heroRadius),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calories today',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: ForgeSpacing.xs),
                        Text(
                          '${caloriesLogged.round()} kcal',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        Text(
                          'of ${caloriesGoal.round()} kcal goal',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ForgeSpacing.sm),
                  GradientRing(
                    value: caloriesGoal > 0
                        ? caloriesLogged / caloriesGoal
                        : null,
                    size: ForgeSpacing.xxxl * 2,
                    strokeWidth: ForgeSpacing.xs,
                    gradient: tokens.primaryGradient,
                    centerChild: Text(
                      caloriesGoal > 0
                          ? '${(caloriesLogged / caloriesGoal * 100).round()}%'
                          : '—',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ForgeSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - ForgeSpacing.sm) / 2;
                return Wrap(
                  spacing: ForgeSpacing.sm,
                  runSpacing: ForgeSpacing.sm,
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _NutritionMetricCard(
                        label: 'Calories',
                        value: totals['calories']!,
                        goal: goals['calories'],
                        unit: 'kcal',
                      ),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _NutritionMetricCard(
                        label: 'Protein',
                        value: totals['protein']!,
                        goal: goals['protein'],
                        unit: 'g',
                      ),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _NutritionMetricCard(
                        label: 'Carbs',
                        value: totals['carbs']!,
                        goal: goals['carbs'],
                        unit: 'g',
                      ),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _NutritionMetricCard(
                        label: 'Fat',
                        value: totals['fat']!,
                        goal: goals['fat'],
                        unit: 'g',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: ForgeSpacing.md),
            forge_ui.SectionHeader(title: 'Macros'),
            const SizedBox(height: ForgeSpacing.sm),
            _MacroProgressCard(
              key: ValueKey('macro-protein-${widget.replayKey}'),
              label: 'Protein',
              consumed: proteinToday,
              goal: proteinGoal,
              color: tokens.accentTeal,
            ),
            const SizedBox(height: ForgeSpacing.xs),
            _MacroProgressCard(
              key: ValueKey('macro-carbs-${widget.replayKey}'),
              label: 'Carbs',
              consumed: carbsToday,
              goal: carbsGoal,
              color: tokens.warning,
            ),
            const SizedBox(height: ForgeSpacing.xs),
            _MacroProgressCard(
              key: ValueKey('macro-fat-${widget.replayKey}'),
              label: 'Fat',
              consumed: fatToday,
              goal: fatGoal,
              color: tokens.recoveryGradient.colors.first,
            ),
            if (caloriesGoal > 0) ...[
              const SizedBox(height: ForgeSpacing.md),
              Text(
                'Net energy',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(height: ForgeSpacing.xs),
              NetEnergyGradientBar(
                value: caloriesLogged - caloriesGoal,
                min: -caloriesGoal,
                max: caloriesGoal,
                height: 18,
              ),
            ],
            const SizedBox(height: ForgeSpacing.md),
            SectionHeader(title: 'Add food', trailing: const SizedBox.shrink()),
            const SizedBox(height: ForgeSpacing.xs),
            PrimaryGradientButton(
              label: 'Search foods',
              icon: Icons.search_rounded,
              expand: true,
              onPressed: _openFoodSearch,
            ),
            const SizedBox(height: ForgeSpacing.sm),
            Wrap(
              spacing: ForgeSpacing.xs,
              runSpacing: ForgeSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: _openBarcodeScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan barcode'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.border),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openPhotoEntry,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.border),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openManualEntry,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Manual entry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.border),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ForgeSpacing.md),
            SectionHeader(title: 'Today’s log'),
            const SizedBox(height: ForgeSpacing.xs),
            if (entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(ForgeSpacing.md),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(tokens.cardRadius),
                  border: Border.all(color: tokens.border),
                ),
                child: Text(
                  'No food logged today yet. Add a meal to get started.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: tokens.textSecondary),
                ),
              )
            else
              ...entries.map((entry) {
                final calories = entry.caloriesPerServing == null
                    ? null
                    : entry.caloriesPerServing! * entry.quantity;
                final protein = entry.proteinGramsPerServing == null
                    ? null
                    : entry.proteinGramsPerServing! * entry.quantity;
                final carbs = entry.carbsGramsPerServing == null
                    ? null
                    : entry.carbsGramsPerServing! * entry.quantity;
                final fat = entry.fatGramsPerServing == null
                    ? null
                    : entry.fatGramsPerServing! * entry.quantity;

                return Container(
                  margin: const EdgeInsets.only(bottom: ForgeSpacing.sm),
                  padding: const EdgeInsets.all(ForgeSpacing.md),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(tokens.cardRadius),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.foodName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: tokens.textPrimary),
                              softWrap: true,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit quantity',
                            onPressed: () => _editEntry(entry),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete log',
                            onPressed: () => _deleteEntry(entry),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: ForgeSpacing.xxs),
                      Text(
                        '${entry.quantity.toStringAsFixed(entry.quantity % 1 == 0 ? 0 : 2)} × ${entry.servingSize}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                      const SizedBox(height: ForgeSpacing.xs),
                      Wrap(
                        spacing: ForgeSpacing.xs,
                        runSpacing: ForgeSpacing.xxs,
                        children:
                            [
                                  '${calories?.toStringAsFixed(0) ?? '—'} kcal',
                                  '${protein?.toStringAsFixed(1) ?? '—'} g protein',
                                  '${carbs?.toStringAsFixed(1) ?? '—'} g carbs',
                                  '${fat?.toStringAsFixed(1) ?? '—'} g fat',
                                ]
                                .map(
                                  (label) => Text(
                                    label,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: tokens.textSecondary),
                                  ),
                                )
                                .toList(growable: false),
                      ),
                      const SizedBox(height: ForgeSpacing.xxs),
                      Text(
                        'Source: ${entry.source}',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: tokens.textMuted),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _MacroProgressCard extends StatefulWidget {
  const _MacroProgressCard({
    super.key,
    required this.label,
    required this.consumed,
    required this.goal,
    required this.color,
  });

  final String label;
  final double consumed;
  final double goal;
  final Color color;

  @override
  State<_MacroProgressCard> createState() => _MacroProgressCardState();
}

class _MacroProgressCardState extends State<_MacroProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: ForgeMotion.macroDots,
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotionPreference();
  }

  @override
  void didUpdateWidget(covariant _MacroProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consumed != widget.consumed ||
        oldWidget.goal != widget.goal) {
      _dots
        ..stop()
        ..value = _reduceMotion ? 1 : 0;
      if (!_reduceMotion) _dots.forward();
    }
  }

  void _updateMotionPreference() {
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == disabled && _dots.isAnimating == !disabled) return;
    _reduceMotion = disabled;
    if (disabled) {
      _dots
        ..stop()
        ..value = 1;
    } else {
      _dots.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final progress = widget.goal > 0
        ? (widget.consumed / widget.goal).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.controlRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${widget.consumed.round()} / ${widget.goal.round()} g',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.sm),
          AnimatedBuilder(
            animation: _dots,
            builder: (context, _) => Row(
              children: List.generate(20, (index) {
                final start =
                    index *
                    ForgeMotion.tabCardStagger.inMilliseconds /
                    ForgeMotion.macroDots.inMilliseconds;
                final span = 0.12;
                final localProgress = _reduceMotion
                    ? 1.0
                    : ((_dots.value - start) / span).clamp(0.0, 1.0);
                final dotFill =
                    (progress * 20 - index).clamp(0.0, 1.0) *
                    Curves.easeOutCubic.transform(localProgress);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          tokens.surfaceVariant,
                          widget.color,
                          dotFill,
                        ),
                        borderRadius: BorderRadius.circular(tokens.pillRadius),
                        boxShadow: dotFill > 0.72
                            ? [
                                BoxShadow(
                                  color: widget.color.withValues(
                                    alpha: dotFill * 0.28,
                                  ),
                                  blurRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionMetricCard extends StatelessWidget {
  const _NutritionMetricCard({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
  });

  final String label;
  final double value;
  final double? goal;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final hasGoal = goal != null && goal! > 0;
    final progress = hasGoal ? (value / goal!).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ForgeSpacing.xs),
          Text(
            '${value.toStringAsFixed(value >= 100 ? 0 : 1)} $unit',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: ForgeSpacing.xs),
          if (hasGoal) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.pillRadius),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: ForgeSpacing.xs,
                backgroundColor: tokens.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.accentTeal),
              ),
            ),
            const SizedBox(height: ForgeSpacing.xs),
            Text(
              '${goal!.toStringAsFixed(0)} $unit goal',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: tokens.textSecondary),
            ),
          ] else
            Text(
              'No goal set',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: tokens.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _HealthSummaryCard extends StatelessWidget {
  const _HealthSummaryCard({
    required this.summaryFuture,
    required this.onConnect,
    required this.replayKey,
  });

  final Future<HealthSummary?> summaryFuture;
  final VoidCallback onConnect;
  final int replayKey;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Card(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        side: BorderSide(color: tokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ForgeSpacing.md),
        child: FutureBuilder<HealthSummary?>(
          future: summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ShimmerBox(
                height: ForgeSpacing.xxxl,
                borderRadius: ForgeSpacing.md,
              );
            }

            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Couldn't read (check Health permissions)."),
                  const SizedBox(height: ForgeSpacing.sm),
                  const _HealthSettingsButton(),
                  FilledButton.icon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reconnect Health'),
                  ),
                ],
              );
            }

            final summary =
                snapshot.data ??
                const HealthSummary(
                  hasPermissions: false,
                  errorMessage: 'Health data unavailable.',
                );

            if (!summary.hasPermissions || summary.errorMessage != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Couldn't read (check Health permissions). "
                    '${summary.errorMessage ?? ''}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: ForgeSpacing.sm),
                  const _HealthSettingsButton(),
                  FilledButton.icon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.connect_without_contact_rounded),
                    label: const Text('Connect Health'),
                  ),
                ],
              );
            }

            return _HealthMetrics(summary: summary, replayKey: replayKey);
          },
        ),
      ),
    );
  }
}

class _HealthMetrics extends StatelessWidget {
  const _HealthMetrics({required this.summary, required this.replayKey});

  final HealthSummary summary;
  final int replayKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MetricSectionTitle(title: 'Activity'),
        _MetricGrid(
          replayKey: replayKey,
          metrics: [
            _MetricData(
              label: 'Steps',
              value: summary.steps?.toString(),
              icon: Icons.directions_walk_rounded,
              failed: summary.failedTypes.contains(HealthDataType.STEPS),
            ),
            _MetricData(
              label: 'Active energy',
              value: _formatNumber(summary.activeCaloriesBurned, 'kcal'),
              icon: Icons.local_fire_department_rounded,
              failed: summary.failedTypes.contains(
                HealthDataType.ACTIVE_ENERGY_BURNED,
              ),
            ),
            _MetricData(
              label: 'Distance',
              value: summary.distanceMeters == null
                  ? null
                  : '${(summary.distanceMeters! / 1000).toStringAsFixed(2)} km',
              icon: Icons.route_rounded,
              failed:
                  summary.failedTypes.contains(
                    HealthDataType.DISTANCE_WALKING_RUNNING,
                  ) ||
                  summary.failedTypes.contains(HealthDataType.DISTANCE_DELTA),
            ),
            _MetricData(
              label: 'Flights climbed',
              value: _formatNumber(summary.flightsClimbed, 'flights'),
              icon: Icons.stairs_rounded,
              failed: summary.failedTypes.contains(
                HealthDataType.FLIGHTS_CLIMBED,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _MetricSectionTitle(title: 'Sleep'),
        _MetricGrid(
          replayKey: replayKey,
          metrics: [
            _MetricData(
              label: 'Time asleep',
              value: _formatSleep(summary.sleepAsleepMinutes),
              icon: Icons.bedtime_rounded,
              failed: _sleepQueryFailed(summary),
            ),
            _MetricData(
              label: 'Awake',
              value: _formatSleep(summary.sleepAwakeMinutes),
              icon: Icons.wb_sunny_outlined,
              failed: summary.failedTypes.contains(HealthDataType.SLEEP_AWAKE),
            ),
            _MetricData(
              label: 'Deep sleep',
              value: _formatSleep(summary.sleepDeepMinutes),
              icon: Icons.nightlight_round,
              failed: summary.failedTypes.contains(HealthDataType.SLEEP_DEEP),
            ),
            _MetricData(
              label: 'Light / REM',
              value: _formatSleepPair(
                summary.sleepLightMinutes,
                summary.sleepRemMinutes,
              ),
              icon: Icons.brightness_5_outlined,
              failed:
                  summary.failedTypes.contains(HealthDataType.SLEEP_LIGHT) ||
                  summary.failedTypes.contains(HealthDataType.SLEEP_REM),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _MetricSectionTitle(title: 'Health Monitor'),
        _HealthMonitorGrid(
          replayKey: replayKey,
          metrics: [
            _MetricData(
              label: 'Resting heart rate',
              value: _formatNumber(summary.restingHeartRate, 'bpm'),
              icon: Icons.favorite_rounded,
              metricValue: summary.restingHeartRate,
              failed: summary.failedTypes.contains(
                HealthDataType.RESTING_HEART_RATE,
              ),
              normalRangeMin: 50,
              normalRangeMax: 70,
            ),
            _MetricData(
              label: 'Average heart rate',
              value: _formatNumber(summary.averageHeartRate, 'bpm'),
              icon: Icons.monitor_heart_outlined,
              metricValue: summary.averageHeartRate,
              failed: summary.failedTypes.contains(HealthDataType.HEART_RATE),
              normalRangeMin: 40,
              normalRangeMax: 180,
            ),
            _MetricData(
              label: 'Blood oxygen',
              value: _formatNumber(summary.bloodOxygen, '%'),
              icon: Icons.air_rounded,
              metricValue: summary.bloodOxygen,
              failed: summary.failedTypes.contains(HealthDataType.BLOOD_OXYGEN),
              normalRangeMin: 90,
              normalRangeMax: 100,
            ),
            _MetricData(
              label: 'Time asleep',
              value: _formatSleep(summary.sleepAsleepMinutes),
              icon: Icons.bedtime_rounded,
              metricValue: summary.sleepAsleepMinutes,
              failed: _sleepQueryFailed(summary),
              normalRangeMin: 0,
              normalRangeMax: 480,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _MetricSectionTitle(title: 'Body'),
        _MetricGrid(
          replayKey: replayKey,
          metrics: [
            _MetricData(
              label: 'Synced weight',
              value: _formatNumber(summary.weightKg, 'kg'),
              icon: Icons.monitor_weight_outlined,
              failed: summary.failedTypes.contains(HealthDataType.WEIGHT),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricSectionTitle extends StatelessWidget {
  const _MetricSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.replayKey});

  final List<_MetricData> metrics;
  final int replayKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricTile(
                    key: ValueKey('metric-${metric.label}-$replayKey'),
                    metric: metric,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _HealthMonitorGrid extends StatelessWidget {
  const _HealthMonitorGrid({required this.metrics, required this.replayKey});

  final List<_MetricData> metrics;
  final int replayKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = ForgeSpacing.sm;
        final columns = constraints.maxWidth < ForgeSpacing.xxxl * 5 ? 1 : 2;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _HealthMonitorTile(
                    key: ValueKey('vital-${metric.label}-$replayKey'),
                    metric: metric,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    this.metricValue,
    this.normalRangeMin,
    this.normalRangeMax,
    this.failed = false,
  });

  final String label;
  final String? value;
  final IconData icon;
  final double? metricValue;
  final double? normalRangeMin;
  final double? normalRangeMax;
  final bool failed;
}

bool _sleepQueryFailed(HealthSummary summary) =>
    summary.sleepAsleepMinutes == null &&
    const {
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    }.any(summary.failedTypes.contains);

VitalGaugeStatus _vitalStatusForValue(double? value, double min, double max) {
  if (value == null) {
    return VitalGaugeStatus.noData;
  }
  if (value < min) {
    return VitalGaugeStatus.low;
  }
  if (value > max) {
    return VitalGaugeStatus.high;
  }
  return VitalGaugeStatus.normal;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({super.key, required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final hasValue = metric.value != null;
    final palette =
        Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    final hasGaugeRange =
        metric.normalRangeMin != null && metric.normalRangeMax != null;
    final gaugeStatus = hasGaugeRange
        ? _vitalStatusForValue(
            metric.metricValue,
            metric.normalRangeMin!,
            metric.normalRangeMax!,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(palette.cardRadius),
        border: Border.all(
          color: palette.secondaryText.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(metric.icon, size: 20, color: palette.primaryText),
                const SizedBox(height: 8),
                Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.secondaryText,
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasValue ? metric.value! : '—',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.primaryText,
                  ),
                ),
                if (!hasValue && metric.failed)
                  const Text(
                    "Couldn't read (check Health permissions)",
                    style: TextStyle(fontSize: 11),
                  )
                else if (!hasValue)
                  Text(
                    metric.label == 'Time asleep'
                        ? 'No sleep data found for last night'
                        : 'No data today',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: palette.secondaryText),
                  ),
                if (!hasValue && metric.failed) const _HealthSettingsButton(),
              ],
            ),
          ),
          if (hasGaugeRange)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 6),
              child: VitalPillGauge(
                value: metric.metricValue ?? 0,
                normalRangeMin: metric.normalRangeMin!,
                normalRangeMax: metric.normalRangeMax!,
                status: gaugeStatus ?? VitalGaugeStatus.noData,
                width: 78,
                height: 52,
              ),
            ),
        ],
      ),
    );
  }
}

class _HealthSettingsButton extends StatelessWidget {
  const _HealthSettingsButton();

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () async {
      try {
        final opened = await launchUrl(
          Uri.parse('app-settings:'),
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open iOS Settings.')),
          );
        }
      } catch (error, stackTrace) {
        debugPrint('Opening iOS Settings failed: $error\n$stackTrace');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to open iOS Settings: $error')),
          );
        }
      }
    },
    icon: const Icon(Icons.settings_outlined, size: 16),
    label: const Text('Open Settings'),
  );
}

class _HealthMonitorTile extends StatelessWidget {
  const _HealthMonitorTile({super.key, required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final value = metric.metricValue;
    final min = metric.normalRangeMin;
    final max = metric.normalRangeMax;
    final hasValue = value != null && min != null && max != null && max > min;
    final progress = hasValue
        ? ((value - min) / (max - min)).clamp(0.0, 1.0)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ForgeSpacing.md),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          children: [
            Icon(metric.icon, color: tokens.accentTeal),
            const SizedBox(height: ForgeSpacing.xs),
            Text(
              hasValue
                  ? metric.value!
                  : metric.failed
                  ? "Couldn't read (check Health permissions)"
                  : metric.label == 'Time asleep'
                  ? 'No sleep data found for last night'
                  : 'No reading',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: hasValue ? tokens.textPrimary : tokens.textMuted,
              ),
            ),
            const SizedBox(height: ForgeSpacing.xs),
            if (hasValue)
              forge_ui.VerticalPillGauge(
                value: progress,
                label: metric.label,
                height: ForgeSpacing.xxxl,
                width: ForgeSpacing.sm,
                labelWidth: constraints.maxWidth,
                gradient: tokens.recoveryGradient,
              )
            else
              SizedBox(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      metric.label,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                    if (metric.failed) const _HealthSettingsButton(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String? _formatNumber(double? value, String unit) {
  if (value == null) {
    return null;
  }
  final decimals = value.truncateToDouble() == value ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} $unit';
}

String? _formatSleep(double? minutes) {
  if (minutes == null) {
    return null;
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes.round() % 60;
  if (hours == 0) {
    return '${remainingMinutes}m';
  }
  return '${hours}h ${remainingMinutes}m';
}

String? _formatSleepPair(double? lightMinutes, double? remMinutes) {
  if (lightMinutes == null && remMinutes == null) {
    return null;
  }
  final light = _formatSleep(lightMinutes) ?? '—';
  final rem = _formatSleep(remMinutes) ?? '—';
  return '$light / $rem';
}

class _WatchWorkoutsCard extends StatelessWidget {
  const _WatchWorkoutsCard({
    required this.workoutsFuture,
    required this.onConnect,
    required this.onLog,
    required this.isLogged,
  });

  final Future<List<HealthWorkoutEntry>> workoutsFuture;
  final VoidCallback onConnect;
  final Future<void> Function(HealthWorkoutEntry workout) onLog;
  final bool Function(HealthWorkoutEntry workout) isLogged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Card(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        side: BorderSide(color: tokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ForgeSpacing.md),
        child: FutureBuilder<List<HealthWorkoutEntry>>(
          future: workoutsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ShimmerBox(
                height: ForgeSpacing.xxxl,
                borderRadius: ForgeSpacing.md,
              );
            }

            if (snapshot.hasError) {
              return const Text(
                'Recent workouts could not be loaded. Pull down to retry.',
              );
            }

            final workouts = snapshot.data ?? const <HealthWorkoutEntry>[];
            if (workouts.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No recent workouts from your health app were found.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: ForgeSpacing.sm),
                  FilledButton.icon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.connect_without_contact_rounded),
                    label: const Text('Connect Health'),
                  ),
                ],
              );
            }

            return Column(
              children: workouts.map((workout) {
                final alreadyLogged = isLogged(workout);
                final duration = _formatDuration(
                  workout.startTime,
                  workout.endTime,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: ForgeSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: ForgeSpacing.xxxl,
                        height: ForgeSpacing.xxxl,
                        decoration: BoxDecoration(
                          color: tokens.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            tokens.controlRadius,
                          ),
                        ),
                        child: Icon(
                          Icons.watch_rounded,
                          color: tokens.accentTeal,
                        ),
                      ),
                      const SizedBox(width: ForgeSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.type,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: tokens.textPrimary),
                            ),
                            const SizedBox(height: ForgeSpacing.xxs),
                            Text(
                              '${MaterialLocalizations.of(context).formatShortDate(workout.startTime)} · $duration · ${workout.calories.toStringAsFixed(0)} kcal',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      alreadyLogged
                          ? const Icon(Icons.check_circle_rounded)
                          : TextButton(
                              onPressed: () => onLog(workout),
                              child: const Text('Log'),
                            ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  static String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final minutes = duration.inMinutes;
    if (minutes <= 0) {
      return '0 min';
    }
    return '$minutes min';
  }
}

class _BodyLogSection extends StatefulWidget {
  const _BodyLogSection();

  @override
  State<_BodyLogSection> createState() => _BodyLogSectionState();
}

class _BodyLogSectionState extends State<_BodyLogSection> {
  final Box<BodyLog> _bodyLogBox = Hive.box<BodyLog>('bodyLogs');

  Future<void> _addEntrySheet() async {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.heroRadius),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _BodyLogAddForm(bodyLogBox: _bodyLogBox),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<BodyLog>>(
      valueListenable: _bodyLogBox.listenable(),
      builder: (context, box, _) {
        final entries = box.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final chartEntries = entries.take(30).toList().reversed.toList();
        final weights = chartEntries
            .where((entry) => entry.weightKg != null)
            .map((entry) => entry.weightKg!)
            .toList(growable: false);
        final tokens = Theme.of(context).extension<ForgeTokens>()!;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            ForgeSpacing.md,
            ForgeSpacing.md,
            ForgeSpacing.md,
            ForgeSpacing.md +
                ForgeMotion.navBarHeight +
                ForgeMotion.navBottomInset +
                MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            PrimaryGradientButton(
              label: 'Add body entry',
              icon: Icons.add_rounded,
              expand: true,
              onPressed: _addEntrySheet,
            ),
            const SizedBox(height: ForgeSpacing.md),
            Container(
              padding: const EdgeInsets.all(ForgeSpacing.md),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(tokens.cardRadius),
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  forge_ui.SectionHeader(title: 'Weight trend'),
                  const SizedBox(height: ForgeSpacing.md),
                  if (weights.length >= 2)
                    SparklineChart(
                      values: weights,
                      height: ForgeSpacing.xxxl * 2,
                      gradient: tokens.recoveryGradient,
                    )
                  else
                    Text(
                      weights.isEmpty
                          ? 'Add a weight entry to start tracking your trend.'
                          : 'One entry logged · add another to reveal your trend.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  if (weights.isNotEmpty) ...[
                    const SizedBox(height: ForgeSpacing.sm),
                    Text(
                      '${weights.first.toStringAsFixed(1)} kg → ${weights.last.toStringAsFixed(1)} kg',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: ForgeSpacing.lg),
            const forge_ui.SectionHeader(title: 'Recent entries'),
            const SizedBox(height: ForgeSpacing.sm),
            if (entries.isEmpty)
              _HealthMessageCard(
                icon: Icons.monitor_weight_outlined,
                message: 'No body entries yet. Add your first measurement.',
              )
            else
              ...entries.take(5).map((entry) => _BodyLogEntryRow(entry: entry)),
          ],
        );
      },
    );
  }
}

class _BodyLogEntryRow extends StatelessWidget {
  const _BodyLogEntryRow({required this.entry});

  final BodyLog entry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final measurements =
        entry.measurements?.entries
            .where((item) => item.value > 0)
            .toList(growable: false) ??
        const <MapEntry<String, double>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: ForgeSpacing.sm),
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMM d, yyyy').format(entry.date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (entry.weightKg != null)
                Text(
                  '${entry.weightKg!.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: tokens.accentTeal),
                ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.xs),
          if (measurements.isEmpty)
            Text(
              'No measurements logged',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: tokens.textSecondary),
            )
          else
            Wrap(
              spacing: ForgeSpacing.xs,
              runSpacing: ForgeSpacing.xs,
              children: measurements
                  .map(
                    (measurement) => Text(
                      '${measurement.key}: ${measurement.value.toStringAsFixed(0)} cm',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _BodyLogAddForm extends StatefulWidget {
  const _BodyLogAddForm({required this.bodyLogBox});

  final Box<BodyLog> bodyLogBox;

  @override
  State<_BodyLogAddForm> createState() => _BodyLogAddFormState();
}

class _BodyLogAddFormState extends State<_BodyLogAddForm> {
  late DateTime _selectedDate;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Map<String, TextEditingController> _measurementControllers = {
    'chest': TextEditingController(),
    'waist': TextEditingController(),
    'hips': TextEditingController(),
    'arms': TextEditingController(),
    'thighs': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    for (final controller in _measurementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _save() {
    final weightText = _weightController.text.trim();
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);

    final measurements = <String, double>{};
    for (final entry in _measurementControllers.entries) {
      final valueText = entry.value.text.trim();
      if (valueText.isEmpty) {
        continue;
      }
      final value = double.tryParse(valueText);
      if (value != null) {
        measurements[entry.key] = value;
      }
    }

    if (weight == null && measurements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a weight or at least one measurement before saving.',
          ),
        ),
      );
      return;
    }

    final entry = BodyLog(
      date: _selectedDate,
      weightKg: weight,
      measurements: measurements.isEmpty ? null : measurements,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    widget.bodyLogBox.put(entry.id, entry);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add Body Log',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('MMM d, yyyy').format(_selectedDate),
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ..._measurementControllers.entries.map((entry) {
              final label = entry.key[0].toUpperCase() + entry.key.substring(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: entry.value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '$label (cm)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save body log'),
            ),
          ],
        ),
      ),
    );
  }
}
