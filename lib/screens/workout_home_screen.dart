import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/motion.dart';
import '../models/active_workout_draft.dart';
import '../models/workout_session.dart';
import '../theme.dart';
import '../widgets/ui/gradient_ring.dart';
import '../widgets/ui/primary_gradient_button.dart';
import '../widgets/ui/section_header.dart';
import 'active_workout_screen.dart';
import 'ai_suggestion_screen.dart';
import 'build_workout_screen.dart';
import 'workout_detail_screen.dart';

class WorkoutHomeScreen extends StatelessWidget {
  const WorkoutHomeScreen({super.key});

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final workoutBox = Hive.box<WorkoutSession>('workoutSessions');
    final activeWorkoutBox = Hive.box<dynamic>('activeWorkout');
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
      ),
      body: ValueListenableBuilder<Box<WorkoutSession>>(
        valueListenable: workoutBox.listenable(),
        builder: (context, box, _) {
          final sessions = box.values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final now = DateTime.now();
          final todaySessions = sessions.where((session) {
            final date = session.date.toLocal();
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          }).toList(growable: false);
          final todayVolume = todaySessions.fold<double>(
            0,
            (total, session) => total + session.totalVolume,
          );
          final todayMinutes = todaySessions.fold<int>(
            0,
            (total, session) => total + session.durationMinutes,
          );
          final todaySets = todaySessions.fold<int>(
            0,
            (total, session) =>
                total +
                session.exercises.fold<int>(
                  0,
                  (count, exercise) => count + exercise.sets.length,
                ),
          );

          return ListView(
            padding: EdgeInsets.fromLTRB(
              ForgeSpacing.md,
              ForgeSpacing.xs,
              ForgeSpacing.md,
              ForgeSpacing.md +
                  ForgeMotion.navBarHeight +
                  ForgeMotion.navBottomInset +
                  MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
            _ResumeWorkoutCard(
              onResume: () {
                final rawDraft = activeWorkoutBox.get('activeWorkout');
                if (rawDraft is! Map) {
                  return;
                }
                try {
                  final draft = ActiveWorkoutDraft.fromMap(rawDraft);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ActiveWorkoutScreen(
                        sessionId: draft.id,
                        resumeDraft: true,
                      ),
                    ),
                  );
                } catch (error, stackTrace) {
                  debugPrint(
                    'Unable to resume active workout: $error\n$stackTrace',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This saved workout cannot be resumed. Discard it to start a new workout.',
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: ForgeSpacing.sm),
            Text(
                _greeting(now),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: tokens.textSecondary,
                    ),
              ),
              const SizedBox(height: ForgeSpacing.xxs),
              Text(
                'Show up. Get stronger.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: ForgeSpacing.lg),
              _TodaySummaryCard(
                sessionCount: todaySessions.length,
                minutes: todayMinutes,
                volume: todayVolume,
                sets: todaySets,
              ),
              const SizedBox(height: ForgeSpacing.md),
              PrimaryGradientButton(
                label: 'Start a workout',
                icon: Icons.play_arrow_rounded,
                expand: true,
                onPressed: () async {
                  if (activeWorkoutBox.containsKey('activeWorkout')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Resume or discard your saved workout before starting another.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ActiveWorkoutScreen(
                        sessionId: const Uuid().v4(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: ForgeSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BuildWorkoutScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Build'),
                    ),
                  ),
                  const SizedBox(width: ForgeSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AiSuggestionScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Forge AI'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ForgeSpacing.xl),
              const SectionHeader(title: 'Recent workouts'),
              const SizedBox(height: ForgeSpacing.sm),
              if (sessions.isEmpty)
                const _EmptyWorkoutsCard()
              else
                ...sessions.take(8).map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: ForgeSpacing.sm),
                    child: _WorkoutListCard(
                      session: session,
                      dateLabel: _formatDate(session.date),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkoutDetailScreen(
                              session: session,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ResumeWorkoutCard extends StatefulWidget {
  const _ResumeWorkoutCard({required this.onResume});

  final VoidCallback onResume;

  @override
  State<_ResumeWorkoutCard> createState() => _ResumeWorkoutCardState();
}

class _ResumeWorkoutCardState extends State<_ResumeWorkoutCard> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _formatElapsed(DateTime startedAt) {
    final seconds = DateTime.now().difference(startedAt).inSeconds.clamp(0, 1 << 31);
    final hours = seconds ~/ 3600;
    final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$remainder' : '$minutes:$remainder';
  }

  Future<void> _discard(BuildContext context) async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('This in-progress workout will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep workout'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (shouldDiscard != true || !context.mounted) {
      return;
    }

    try {
      final box = Hive.box<dynamic>('activeWorkout');
      await box.delete('activeWorkout');
      await box.flush();
    } catch (error, stackTrace) {
      debugPrint('Failed to discard active workout: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to discard the saved workout.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final box = Hive.box<dynamic>('activeWorkout');

    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: box.listenable(keys: const ['activeWorkout']),
      builder: (context, activeBox, _) {
        final rawDraft = activeBox.get('activeWorkout');
        if (rawDraft == null) {
          return const SizedBox.shrink();
        }

        late final ActiveWorkoutDraft draft;
        try {
          if (rawDraft is! Map) {
            throw const FormatException('Draft is not a map.');
          }
          draft = ActiveWorkoutDraft.fromMap(rawDraft);
        } catch (error, stackTrace) {
          debugPrint('Unable to display active workout draft: $error\n$stackTrace');
          return _ResumeWorkoutErrorCard(onDiscard: () => _discard(context));
        }

        final isStale = DateTime.now().difference(draft.startedAt) >
            const Duration(hours: 24);
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
                'Workout in progress',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: tokens.accentTeal,
                    ),
              ),
              const SizedBox(height: ForgeSpacing.xxs),
              Text(
                draft.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: ForgeSpacing.xxs),
              Text(
                '${_formatElapsed(draft.startedAt)} elapsed · '
                '${draft.completedSetCount} '
                '${draft.completedSetCount == 1 ? 'set' : 'sets'} done'
                '${isStale ? ' · Started over 24 hours ago' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
              ),
              const SizedBox(height: ForgeSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: PrimaryGradientButton(
                      label: 'Resume workout',
                      icon: Icons.play_arrow_rounded,
                      expand: true,
                      onPressed: widget.onResume,
                    ),
                  ),
                  const SizedBox(width: ForgeSpacing.xs),
                  TextButton(
                    onPressed: () => _discard(context),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResumeWorkoutErrorCard extends StatelessWidget {
  const _ResumeWorkoutErrorCard({required this.onDiscard});

  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.error),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Saved workout cannot be resumed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onDiscard, child: const Text('Discard')),
        ],
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.sessionCount,
    required this.minutes,
    required this.volume,
    required this.sets,
  });

  final int sessionCount;
  final int minutes;
  final double volume;
  final int sets;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final hasSession = sessionCount > 0;

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.surfaceVariant, tokens.surface],
        ),
        borderRadius: BorderRadius.circular(tokens.heroRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TODAY'S TRAINING",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: tokens.textSecondary,
                            letterSpacing: 1,
                          ),
                    ),
                    const SizedBox(height: ForgeSpacing.xs),
                    Text(
                      hasSession ? 'Work logged' : 'Your day is open',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: ForgeSpacing.xxs),
                    Text(
                      hasSession
                          ? '$sessionCount ${sessionCount == 1 ? 'workout' : 'workouts'} completed'
                          : 'Start a session and build momentum.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ForgeSpacing.sm),
              GradientRing(
                value: hasSession ? 1 : 0,
                size: ForgeSpacing.xxxl,
                strokeWidth: ForgeSpacing.xs,
                centerChild: Icon(
                  hasSession ? Icons.check_rounded : Icons.bolt_rounded,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.md),
          Row(
            children: [
              Expanded(
                child: _TodayMetric(
                  label: 'TIME',
                  value: '$minutes min',
                ),
              ),
              Expanded(
                child: _TodayMetric(
                  label: 'VOLUME',
                  value: '${volume.toStringAsFixed(0)} kg',
                ),
              ),
              Expanded(
                child: _TodayMetric(
                  label: 'SETS',
                  value: '$sets',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.textMuted,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: ForgeSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

class _WorkoutListCard extends StatelessWidget {
  const _WorkoutListCard({
    required this.session,
    required this.dateLabel,
    required this.onTap,
  });

  final WorkoutSession session;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final setCount = session.exercises.fold<int>(
      0,
      (total, exercise) => total + exercise.sets.length,
    );

    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(tokens.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(ForgeSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.cardRadius),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Container(
                width: ForgeSpacing.xxxl,
                height: ForgeSpacing.xxxl,
                decoration: BoxDecoration(
                  color: tokens.surfaceVariant,
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                ),
                child: Icon(Icons.fitness_center, color: tokens.accentTeal),
              ),
              const SizedBox(width: ForgeSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: tokens.textPrimary,
                          ),
                    ),
                    const SizedBox(height: ForgeSpacing.xxs),
                    Text(
                      '$dateLabel · ${session.durationMinutes} min · $setCount sets',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ForgeSpacing.xs),
              Icon(Icons.chevron_right, color: tokens.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkoutsCard extends StatelessWidget {
  const _EmptyWorkoutsCard();

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
          Icon(Icons.history, color: tokens.textMuted),
          const SizedBox(width: ForgeSpacing.sm),
          Expanded(
            child: Text(
              'Your recent sessions will show up here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
