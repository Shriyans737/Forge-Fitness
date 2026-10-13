import 'package:flutter/material.dart';

import '../../theme.dart';
import 'coach_copy.dart';
import 'services/coach_engine.dart';
import 'services/coach_repository.dart';

class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({
    required this.contextSnapshot,
    required this.repository,
    super.key,
  });

  final CoachContext contextSnapshot;
  final CoachRepository repository;

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  late final _ReviewData _review = _ReviewData.fromContext(
    widget.contextSnapshot,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.repository.saveWeeklyReview(_review.weekKey, _review.toMap());
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: const Text(CoachCopy.weeklyReviewTitle),
        actions: [
          IconButton(
            tooltip: CoachCopy.pastReviewsTooltip,
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _PastReviews(repository: widget.repository),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              CoachCopy.reviewAtGlance,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.accentTeal,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _MetricCard(
              label: CoachCopy.workoutsMetric,
              value: _review.workouts.toDouble(),
              suffix: ' / ${_review.workoutGoalLabel}',
              decimals: 0,
            ),
            _MetricCard(
              label: CoachCopy.volumeMetric,
              value: _review.volume,
              suffix: _review.volumeChangeLabel,
              decimals: 0,
            ),
            _MetricCard(
              label: CoachCopy.personalRecordsMetric,
              value: _review.prs.toDouble(),
              suffix: '',
              decimals: 0,
            ),
            _MetricCard(
              label: CoachCopy.averageSleepMetric,
              value: _review.sleepHours,
              suffix: _review.sleepHours == null
                  ? CoachCopy.sleepHistoryNotAvailable
                  : CoachCopy.hourUnit,
              decimals: 1,
            ),
            _MetricCard(
              label: CoachCopy.averageRecoveryMetric,
              value: _review.recovery,
              suffix: _review.recovery == null
                  ? CoachCopy.scoreNotAvailable
                  : CoachCopy.percentUnit,
              decimals: 0,
            ),
            _MetricCard(
              label: CoachCopy.proteinGoalDaysMetric,
              value: _review.proteinDays?.toDouble(),
              suffix: _review.proteinDays == null
                  ? CoachCopy.foodHistoryNotAvailable
                  : CoachCopy.daysOfSeven,
              decimals: 0,
            ),
            _MetricCard(
              label: CoachCopy.averageStepsMetric,
              value: _review.stepsAverage?.toDouble(),
              suffix: _review.stepsAverage == null
                  ? CoachCopy.stepsHistoryNotAvailable
                  : CoachCopy.averagePerDay,
              decimals: 0,
            ),
            _MetricCard(
              label: CoachCopy.weightChangeMetric,
              value: _review.weightChange,
              suffix: _review.weightChange == null
                  ? CoachCopy.weightHistoryNotAvailable
                  : CoachCopy.kilogramUnit,
              decimals: 1,
            ),
            const SizedBox(height: 14),
            _ReviewList(title: CoachCopy.winsTitle, items: _review.wins),
            const SizedBox(height: 12),
            _ReviewList(
              title: CoachCopy.nextWeekFocusTitle,
              items: [_review.focus],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                CoachCopy.medicalDisclaimer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewData {
  const _ReviewData({
    required this.weekKey,
    required this.workouts,
    required this.workoutGoalLabel,
    required this.volume,
    required this.volumeChangeLabel,
    required this.prs,
    required this.sleepHours,
    required this.recovery,
    required this.proteinDays,
    required this.stepsAverage,
    required this.weightChange,
    required this.wins,
    required this.focus,
  });

  final String weekKey;
  final int workouts;
  final String workoutGoalLabel;
  final double volume;
  final String volumeChangeLabel;
  final int prs;
  final double? sleepHours;
  final double? recovery;
  final int? proteinDays;
  final int? stepsAverage;
  final double? weightChange;
  final List<String> wins;
  final String focus;

  static _ReviewData fromContext(CoachContext context) {
    final now = context.now;
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final end = start.add(const Duration(days: 7));
    final lastWeekStart = start.subtract(const Duration(days: 7));
    final currentWorkouts = context.workouts
        .where((item) => !item.date.isBefore(start) && item.date.isBefore(end))
        .toList();
    final priorWorkouts = context.workouts
        .where(
          (item) =>
              !item.date.isBefore(lastWeekStart) && item.date.isBefore(start),
        )
        .toList();
    final volume = currentWorkouts.fold<double>(
      0,
      (sum, item) => sum + item.volume,
    );
    final priorVolume = priorWorkouts.fold<double>(
      0,
      (sum, item) => sum + item.volume,
    );
    final percent = priorVolume == 0
        ? null
        : (volume - priorVolume) / priorVolume * 100;
    final weekScores = context.last14Days.where(
      (day) => !day.date.isBefore(start) && day.date.isBefore(end),
    );
    final sleep = weekScores
        .map((day) => day.sleepMinutes)
        .whereType<double>()
        .toList();
    final recovery = weekScores
        .map((day) => day.recovery)
        .whereType<double>()
        .toList();
    final prs = currentWorkouts
        .expand((item) => item.personalRecords)
        .toSet()
        .length;
    final weightReadings = context.bodyWeights
        .where((item) => !item.date.isBefore(start) && item.date.isBefore(end))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final weightChange = weightReadings.length < 2
        ? null
        : weightReadings.last.kilograms - weightReadings.first.kilograms;
    final wins = <String>[
      if (context.workoutsPerWeekGoal != null &&
          currentWorkouts.length >= context.workoutsPerWeekGoal!)
        CoachCopy.replace(CoachCopy.workoutsGoalReached, {
          'count': '${context.workoutsPerWeekGoal}',
        }),
      if (prs > 0)
        CoachCopy.replace(CoachCopy.prsThisWeek, {
          'count': '$prs',
          'kind': prs == 1 ? CoachCopy.recordSingular : CoachCopy.recordsPlural,
        }),
      if (percent != null && percent > 0)
        CoachCopy.replace(CoachCopy.volumeIncreased, {
          'percent': percent.toStringAsFixed(0),
        }),
    ];
    final focus = const CoachEngine()
            .generate(context)
            .where((item) => item.tone != CoachTone.positive)
            .firstOrNull
            ?.body ??
        CoachCopy.noFocus;
    final weekStart = start.toIso8601String().substring(0, 10);
    return _ReviewData(
      weekKey: weekStart,
      workouts: currentWorkouts.length,
      workoutGoalLabel:
          context.workoutsPerWeekGoal?.toString() ?? CoachCopy.goalNotSet,
      volume: volume,
      volumeChangeLabel: percent == null
          ? CoachCopy.volumeComparisonNotAvailable
          : CoachCopy.replace(CoachCopy.deltaVsLastWeek, {
              'sign': percent >= 0 ? '+' : '',
              'percent': percent.toStringAsFixed(0),
            }),
      prs: prs,
      sleepHours: sleep.isEmpty
          ? null
          : sleep.reduce((a, b) => a + b) / sleep.length / 60,
      recovery: recovery.isEmpty
          ? null
          : recovery.reduce((a, b) => a + b) / recovery.length,
      proteinDays: context.proteinGoalHitDays,
      stepsAverage: context.stepsAverage7Days,
      weightChange: weightChange,
      wins: wins.take(3).toList(),
      focus: focus,
    );
  }

  Map<String, Object?> toMap() => {
    'weekKey': weekKey,
    'workouts': workouts,
    'workoutGoalLabel': workoutGoalLabel,
    'volume': volume,
    'volumeChangeLabel': volumeChangeLabel,
    'prs': prs,
    'sleepHours': sleepHours,
    'recovery': recovery,
    'proteinDays': proteinDays,
    'stepsAverage': stepsAverage,
    'weightChange': weightChange,
    'wins': wins,
    'focus': focus,
  };
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.decimals,
  });

  final String label;
  final double? value;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (value == null)
            Flexible(
              child: Text(
                suffix,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value!),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 650),
              builder: (context, count, _) => Text(
                '${count.toStringAsFixed(decimals)}$suffix',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: tokens.accentTeal,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ),
        ],
      ),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.accentTeal,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(CoachCopy.emptyWeeklyWin)
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${CoachCopy.bulletPrefix}$item'),
              ),
        ],
      ),
    );
  }
}

class _PastReviews extends StatelessWidget {
  const _PastReviews({required this.repository});

  final CoachRepository repository;

  @override
  Widget build(BuildContext context) {
    final reviews = repository.weeklyReviews();
    return Scaffold(
      appBar: AppBar(title: const Text(CoachCopy.pastReviewsTitle)),
      body: reviews.isEmpty
          ? const Center(child: Text(CoachCopy.pastReviewsEmpty))
          : ListView.builder(
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final entry = reviews[index];
                return ListTile(
                  title: Text(
                    CoachCopy.replace(CoachCopy.weekOf, {'date': entry.key}),
                  ),
                  subtitle: Text(
                    '${entry.value['workouts'] ?? CoachCopy.notApplicable}'
                    '${CoachCopy.workoutsUnit}'
                    '${entry.value['prs'] ?? CoachCopy.notApplicable}'
                    '${CoachCopy.personalRecordsUnit}',
                  ),
                );
              },
            ),
    );
  }
}
