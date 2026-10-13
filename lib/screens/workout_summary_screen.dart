import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../models/workout_template.dart';
import '../services/ads_service.dart';
import '../services/progress_repository.dart';
import '../services/progress_service.dart';
import '../services/workout_share_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/shareable_workout_card.dart';
import '../theme.dart';
import '../widgets/ui/pill_tag.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/shimmer_box.dart';
import '../widgets/ui/sparkline_chart.dart';
import '../widgets/ui/stat_card.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  WorkoutSummaryScreen({required this.session, super.key});

  final WorkoutSession session;
  final GlobalKey _cardKey = GlobalKey();

  Future<void> _share(BuildContext context) {
    return WorkoutShareService.share(
      context: context,
      cardKey: _cardKey,
      data: WorkoutShareData.completed(session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = WorkoutShareData.completed(session);
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final setCount = session.exercises.fold<int>(
      0,
      (total, exercise) => total + exercise.sets.length,
    );
    final repCount = session.exercises.fold<int>(
      0,
      (total, exercise) =>
          total + exercise.sets.fold<int>(0, (reps, set) => reps + set.reps),
    );
    final volumeHistory = Hive.box<WorkoutSession>(
      'workoutSessions',
    ).values.where((item) => item.id != session.id).toList()..add(session);
    volumeHistory.sort((a, b) => a.date.compareTo(b.date));
    final recentVolumeHistory = volumeHistory.skip(
      volumeHistory.length > 8 ? volumeHistory.length - 8 : 0,
    );
    final chartValues = recentVolumeHistory
        .map((item) => item.totalVolume)
        .toList(growable: false);
    final personalRecords = _personalRecords(session, volumeHistory);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout complete'),
        actions: [
          IconButton(
            tooltip: 'Share workout',
            onPressed: () => _share(context),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            ForgeSpacing.md,
            ForgeSpacing.sm,
            ForgeSpacing.md,
            ForgeSpacing.md,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(ForgeSpacing.lg),
              decoration: BoxDecoration(
                gradient: tokens.primaryGradient,
                borderRadius: BorderRadius.circular(tokens.heroRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(height: ForgeSpacing.sm),
                  Text(
                    session.name,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: ForgeSpacing.xxs),
                  Text(
                    'Strong work. Your session is saved.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary
                          .withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ForgeSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth =
                    (constraints.maxWidth - ForgeSpacing.xs * 3) / 4;
                return Row(
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        label: 'Duration',
                        number: '${session.durationMinutes}',
                        unit: 'min',
                      ),
                    ),
                    const SizedBox(width: ForgeSpacing.xs),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        label: 'Volume',
                        number: session.totalVolume.toStringAsFixed(0),
                        unit: 'kg',
                      ),
                    ),
                    const SizedBox(width: ForgeSpacing.xxs),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        label: 'Sets',
                        number: '$setCount',
                      ),
                    ),
                    const SizedBox(width: ForgeSpacing.xxs),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        label: 'Reps',
                        number: '$repCount',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: ForgeSpacing.md),
            _MusclesTrainedCard(session: session),
            const SizedBox(height: ForgeSpacing.md),
            _PersonalRecordsCard(records: personalRecords),
            if (chartValues.length > 1) ...[
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
                    const SectionHeader(title: 'Volume trend'),
                    const SizedBox(height: ForgeSpacing.md),
                    SparklineChart(
                      values: chartValues,
                      height: ForgeSpacing.xxxl,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: ForgeSpacing.md),
            RepaintBoundary(
              key: _cardKey,
              child: ShareableWorkoutCard(data: data),
            ),
            const SizedBox(height: ForgeSpacing.md),
            _NextTimeHints(session: session),
            const SizedBox(height: ForgeSpacing.md),
            BannerAdWidget(adUnitId: AdsService.summaryBanner),
            const SizedBox(height: ForgeSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
            const SizedBox(height: ForgeSpacing.xs),
            OutlinedButton.icon(
              onPressed: () => _saveAsTemplate(context),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save as template'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAsTemplate(BuildContext context) async {
    final controller = TextEditingController(text: session.name);
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ForgeSpacing.md,
            ForgeSpacing.md,
            ForgeSpacing.md,
            MediaQuery.viewInsetsOf(sheetContext).bottom + ForgeSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Template name'),
              ),
              const SizedBox(height: ForgeSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, controller.text),
                child: const Text('Save template'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    final exerciseIds = session.exercises
        .map((exercise) => exercise.exerciseId)
        .toSet()
        .toList();
    final template = WorkoutTemplate(
      id: const Uuid().v4(),
      name: name.trim(),
      exerciseIds: exerciseIds,
      plannedExercises: session.exercises
          .map(
            (exercise) => PlannedExercise(
              exerciseId: exercise.exerciseId,
              sets: exercise.sets
                  .map(
                    (set) => PlannedSet(
                      reps: set.reps,
                      weight: set.weight,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
    await Hive.box<WorkoutTemplate>('workoutTemplates').put(
      template.id,
      template,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${template.name}” saved as a template.')),
      );
    }
  }
}

class _MusclesTrainedCard extends StatelessWidget {
  const _MusclesTrainedCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final muscles = <String>{};
    final exercises = Hive.box<Exercise>('exercises');
    for (final logged in session.exercises) {
      final exercise = exercises.get(logged.exerciseId);
      if (exercise != null) {
        muscles
          ..addAll(exercise.primaryMuscles)
          ..addAll(exercise.secondaryMuscles);
      }
    }
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Muscles trained'),
          const SizedBox(height: ForgeSpacing.sm),
          if (muscles.isEmpty)
            Text(
              'Muscle details are unavailable for this workout.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: ForgeSpacing.xs,
              runSpacing: ForgeSpacing.xs,
              children: muscles
                  .map(
                    (muscle) => PillTag(
                      label: muscle,
                      variant: PillTagVariant.success,
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _NextTimeHints extends StatefulWidget {
  const _NextTimeHints({required this.session});

  final WorkoutSession session;

  @override
  State<_NextTimeHints> createState() => _NextTimeHintsState();
}

class _NextTimeHintsState extends State<_NextTimeHints> {
  late final Future<Map<String, ExerciseProgressHistory>> _historiesFuture;

  @override
  void initState() {
    super.initState();
    _historiesFuture = ProgressRepository.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, ExerciseProgressHistory>>(
      future: _historiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ShimmerBox(
            height: ForgeSpacing.xxxl,
            borderRadius: ForgeSpacing.md,
          );
        }
        if (snapshot.hasError) {
          return Text(
            'Progress suggestions are unavailable right now.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final histories = snapshot.data!;
        final suggestions = <String>[];
        for (final loggedExercise in widget.session.exercises) {
          final history = histories[loggedExercise.exerciseId];
          if (history == null) {
            continue;
          }
          final exercise = Hive.box<Exercise>('exercises')
              .get(loggedExercise.exerciseId);
          final suggestion = ProgressionRules.suggest(
            history: history,
            targetRepMin: exercise?.targetRepMin ?? 8,
            targetRepMax: exercise?.targetRepMax ?? 12,
          );
          final target = suggestion?.summaryTarget;
          if (target == null) {
            continue;
          }
          final load = target.weight <= 0
              ? 'bodyweight'
              : '${_formatWeight(target.weight)} kg';
          suggestions.add(
            '${loggedExercise.exerciseName}: try $load x ${target.reps}',
          );
        }
        if (suggestions.isEmpty) {
          return const SizedBox.shrink();
        }

        final tokens = Theme.of(context).extension<ForgeTokens>()!;
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
              const SectionHeader(title: 'Next time'),
              const SizedBox(height: ForgeSpacing.xs),
              ...suggestions.map(
                (text) => Padding(
                  padding: const EdgeInsets.only(top: ForgeSpacing.xxs),
                  child: Text(text),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<String> _personalRecords(
  WorkoutSession session,
  List<WorkoutSession> history,
) {
  final previousMaxByExercise = <String, double>{};
  for (final previous in history.where((item) => item.id != session.id)) {
    for (final exercise in previous.exercises) {
      for (final set in exercise.sets) {
        if (set.weight <= 0 || set.reps <= 0) continue;
        final currentBest = previousMaxByExercise[exercise.exerciseId] ?? 0;
        if (set.weight > currentBest) {
          previousMaxByExercise[exercise.exerciseId] = set.weight;
        }
      }
    }
  }

  final records = <String>[];
  for (final exercise in session.exercises) {
    final best = exercise.sets
        .where((set) => set.weight > 0 && set.reps > 0)
        .fold<double>(
          0,
          (maxWeight, set) => set.weight > maxWeight ? set.weight : maxWeight,
        );
    if (best > (previousMaxByExercise[exercise.exerciseId] ?? 0)) {
      records.add('${exercise.exerciseName} · ${_formatWeight(best)} kg');
    }
  }
  return records;
}

class _PersonalRecordsCard extends StatelessWidget {
  const _PersonalRecordsCard({required this.records});

  final List<String> records;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
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
          const SectionHeader(title: 'Personal records'),
          const SizedBox(height: ForgeSpacing.sm),
          if (records.isEmpty)
            Text(
              'No new load records this session. Keep building your baseline.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.textSecondary),
            )
          else
            Wrap(
              spacing: ForgeSpacing.xs,
              runSpacing: ForgeSpacing.xs,
              children: records
                  .map(
                    (record) => PillTag(
                      label: record,
                      variant: PillTagVariant.success,
                      icon: Icons.emoji_events_outlined,
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

String _formatWeight(double weight) => weight == weight.roundToDouble()
    ? weight.toStringAsFixed(0)
    : weight.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
