import 'package:flutter/material.dart';

import '../../theme.dart';
import 'coach_copy.dart';
import 'services/coach_engine.dart';
import 'services/coach_nudge_service.dart';
import 'services/coach_repository.dart';
import 'weekly_review_screen.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({
    required this.contextSnapshot,
    this.repository,
    super.key,
  });

  final CoachContext contextSnapshot;
  final CoachRepository? repository;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  late final List<CoachInsight> _insights = _loadInsights();
  final Set<String> _hiddenInsightIds = {};
  late final DateTime _now = widget.contextSnapshot.now;
  late int? _bedtimeMinutes = widget.contextSnapshot.bedtimeMinutes;

  List<CoachInsight> _loadInsights() {
    final generated = const CoachEngine().generate(widget.contextSnapshot);
    final repository = widget.repository;
    if (repository == null) return generated;
    return const CoachEngine()
        .withoutRecentlyShown(
          generated.where(
            (insight) =>
                !repository.wasDismissed(insight.id, _now),
          ),
          repository.shownTimestamps(),
          now: _now,
        );
  }

  Future<void> _dismiss(CoachInsight insight) async {
    await widget.repository?.dismiss(insight.id, _now);
    if (widget.repository case final repository?) {
      await CoachNudgeService.instance.rescheduleIfChanged(
        widget.contextSnapshot,
        repository,
      );
    }
    if (mounted) setState(() => _hiddenInsightIds.add(insight.id));
  }

  Future<void> _complete(CoachInsight insight) async {
    await widget.repository?.markShown(insight.id, _now);
    if (widget.repository case final repository?) {
      await CoachNudgeService.instance.rescheduleIfChanged(
        widget.contextSnapshot,
        repository,
      );
    }
    if (mounted) setState(() => _hiddenInsightIds.add(insight.id));
  }

  Future<void> _setBedtime() async {
    final current = _bedtimeMinutes;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 22, minute: 0)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (time == null || widget.repository == null) return;
    final minutes = time.hour * 60 + time.minute;
    await widget.repository!.saveBedtime(minutes);
    if (mounted) setState(() => _bedtimeMinutes = minutes);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final readiness = _insights.where((item) => item.id == 'readiness').firstOrNull;
    final verdict = readiness == null
        ? CoachCopy.fallbackReadiness
        : readiness.body.contains('Recover')
        ? CoachCopy.recover
        : readiness.body.contains('Maintain')
        ? CoachCopy.maintain
        : CoachCopy.push;
    final recommendation = _insights
        .where(
          (item) =>
              item.category == CoachCategory.training &&
              item.action != null,
        )
        .firstOrNull;
    final visibleInsights = _insights
        .where((item) => !_hiddenInsightIds.contains(item.id))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(CoachCopy.coachScreenTitle),
        actions: [
          if (widget.repository != null)
          IconButton(
            tooltip: CoachCopy.weeklyReview,
            icon: const Icon(Icons.calendar_view_week_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WeeklyReviewScreen(
                  contextSnapshot: widget.contextSnapshot,
                  repository: widget.repository!,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                gradient: tokens.primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: tokens.accentTeal.withValues(alpha: 0.2),
                    blurRadius: 28,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CoachCopy.todayPlan,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      color: tokens.background,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verdict,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: tokens.background,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recommendation?.action ??
                        (readiness?.action ?? CoachCopy.chooseSession),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.background,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PlanPill(
                        icon: Icons.directions_walk_rounded,
                        label: widget.contextSnapshot.stepsGoal == null
                            ? CoachCopy.stepsGoalNotSet
                            : CoachCopy.replace(CoachCopy.stepsGoalLabel, {
                                'steps': _number(widget.contextSnapshot.stepsGoal!),
                              }),
                      ),
                      _PlanPill(
                        icon: Icons.bedtime_outlined,
                        label: widget.contextSnapshot.sleepGoalMinutes == null
                            ? CoachCopy.sleepGoalNotSet
                            : CoachCopy.replace(CoachCopy.sleepGoalLabel, {
                                'duration': _duration(widget.contextSnapshot.sleepGoalMinutes!),
                              }),
                      ),
                      if (_bedtimeMinutes != null)
                        _PlanPill(
                          icon: Icons.nightlight_outlined,
                          label: CoachCopy.replace(CoachCopy.bedtimeLabel, {
                            'time': _bedtime(_bedtimeMinutes!),
                          }),
                        ),
                      if (_bedtimeMinutes == null)
                        _PlanPill(
                          icon: Icons.nightlight_outlined,
                          label: CoachCopy.bedtimeGoalNotSet,
                        ),
                      if (widget.repository != null)
                        ActionChip(
                          avatar: const Icon(Icons.schedule_rounded, size: 16),
                          label: Text(
                            _bedtimeMinutes == null
                                ? CoachCopy.setBedtime
                                : CoachCopy.changeBedtime,
                          ),
                          onPressed: _setBedtime,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SectionTitle(title: CoachCopy.insightsTitle),
            const SizedBox(height: 10),
            if (visibleInsights.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Center(child: Text(CoachCopy.learningEmpty)),
              )
            else
              for (final category in CoachCategory.values)
                ...visibleInsights
                    .where((item) => item.category == category)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InsightTile(
                          insight: item,
                          onDismiss: () => _dismiss(item),
                          onDone: () => _complete(item),
                        ),
                      ),
                    ),
            const SizedBox(height: 10),
            _SectionTitle(title: CoachCopy.habitsTitle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HabitChip(
                  label: CoachCopy.water,
                  icon: Icons.water_drop_outlined,
                  value: _habit('water')
                      .waterMillilitres
                      .toDouble(),
                  goal: 2000,
                  streak: _habit('water').streak,
                  onTap: () => _addWater(),
                  suffix: CoachCopy.replace(CoachCopy.mlSuffix, {
                    'amount': '${_habit('water').waterMillilitres}',
                  }),
                ),
                _HabitChip(
                  label: CoachCopy.stretch,
                  icon: Icons.self_improvement_rounded,
                  value: _habit('stretch').completed
                      ? 1
                      : 0,
                  goal: 1,
                  streak: _habit('stretch').streak,
                  onTap: () => _completeHabit('stretch'),
                ),
                _HabitChip(
                  label: CoachCopy.steps,
                  icon: Icons.directions_walk_rounded,
                  value: widget.contextSnapshot.steps?.toDouble() ?? 0,
                  goal: widget.contextSnapshot.stepsGoal?.toDouble() ?? 1,
                  streak: _habit('steps').streak,
                  onTap: _stepsDone,
                ),
                _HabitChip(
                  label: CoachCopy.protein,
                  icon: Icons.restaurant_outlined,
                  value: widget.contextSnapshot.proteinGrams ?? 0,
                  goal: widget.contextSnapshot.proteinGoalGrams ?? 1,
                  streak: _habit('protein').streak,
                  onTap: _proteinDone,
                ),
              ],
            ),
            const SizedBox(height: 26),
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

  Future<void> _addWater() async {
    await widget.repository?.setHabit('water', _now, waterDelta: 250);
    if (mounted) setState(() {});
  }

  Future<void> _completeHabit(String name) async {
    await widget.repository?.setHabit(name, _now);
    if (mounted) setState(() {});
  }

  void _stepsDone() {
    final steps = widget.contextSnapshot.steps;
    final goal = widget.contextSnapshot.stepsGoal;
    if (steps != null && goal != null && steps >= goal) {
      _completeHabit('steps');
    }
  }

  void _proteinDone() {
    final protein = widget.contextSnapshot.proteinGrams;
    final goal = widget.contextSnapshot.proteinGoalGrams;
    if (protein != null && goal != null && protein >= goal) {
      _completeHabit('protein');
    }
  }

  CoachHabitEntry _habit(String name) =>
      widget.repository?.habit(name, _now) ??
      const CoachHabitEntry(completed: false, streak: 0);

  static String _number(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );

  static String _duration(double minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes.round() % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  static String _bedtime(int minutes) {
    final hourOfDay = minutes ~/ 60;
    final hour = hourOfDay % 12 == 0 ? 12 : hourOfDay % 12;
    return '$hour:${(minutes % 60).toString().padLeft(2, '0')} '
        '${hourOfDay < 12 ? CoachCopy.am : CoachCopy.pm}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      letterSpacing: 1.2,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _PlanPill extends StatelessWidget {
  const _PlanPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.insight,
    required this.onDismiss,
    required this.onDone,
  });

  final CoachInsight insight;
  final VoidCallback onDismiss;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final accent = insight.tone == CoachTone.caution
        ? tokens.warning
        : insight.tone == CoachTone.positive
        ? tokens.accentTeal
        : tokens.accentLime;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(CoachCopy.categoryLabel(insight.category.name),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                letterSpacing: 1,
              )),
          const SizedBox(height: 5),
          Text(insight.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 5),
          Text(insight.body),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: const Text(CoachCopy.notHelpful),
              ),
              TextButton.icon(
                onPressed: onDone,
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text(CoachCopy.done),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitChip extends StatelessWidget {
  const _HabitChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.goal,
    required this.streak,
    required this.onTap,
    this.suffix,
  });

  final String label;
  final IconData icon;
  final double value;
  final double goal;
  final int streak;
  final VoidCallback onTap;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final progress = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);
    return ActionChip(
      onPressed: onTap,
      avatar: SizedBox.square(
        dimension: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              color: tokens.accentTeal,
              backgroundColor: tokens.border,
            ),
            Icon(icon, size: 14),
          ],
        ),
      ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (suffix != null) Text(suffix!, style: const TextStyle(fontSize: 11)),
          if (streak > 0)           Text(
            CoachCopy.replace(CoachCopy.habitStreak, {'days': '$streak'}),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }
}
