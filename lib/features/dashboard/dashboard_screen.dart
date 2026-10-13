import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/motion.dart';
import '../../core/perf_diagnostics.dart';
import '../../features/coach/coach_screen.dart';
import '../../features/coach/services/coach_context_provider.dart';
import '../../features/coach/services/coach_engine.dart';
import '../../features/coach/services/coach_repository.dart';
import '../../features/coach/services/coach_nudge_service.dart';
import '../../features/coach/widgets/dashboard_coach_card.dart';
import '../../features/splash/splash_screen.dart';
import '../../models/workout_session.dart';
import '../../models/workout_template.dart';
import '../../screens/active_workout_screen.dart';
import '../../screens/friend_profile_screen.dart';
import '../../screens/friends_screen.dart';
import '../../screens/health_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/template_detail_screen.dart';
import '../../screens/templates_screen.dart';
import '../../screens/workout_detail_screen.dart';
import '../../screens/workout_home_screen.dart';
import '../../theme.dart';
import '../../widgets/ui/shimmer_box.dart';
import '../../services/friends_dashboard_controller.dart';
import '../../services/friends_service.dart';
import 'dashboard_controller.dart';
import 'widgets/dashboard_body_card.dart';
import 'widgets/dashboard_card.dart';
import 'widgets/dashboard_friends_card.dart';
import 'widgets/dashboard_health_card.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_muscles_card.dart';
import 'widgets/dashboard_nutrition_card.dart';
import 'widgets/dashboard_pr_card.dart';
import 'widgets/dashboard_recent_card.dart';
import 'widgets/dashboard_rings_card.dart';
import 'widgets/dashboard_scores_card.dart';
import 'widgets/dashboard_week_card.dart';
import 'widgets/liquid_start_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    this.controller,
    this.onStartWorkout,
    this.onNavigateToWorkouts,
    this.entryReplayKey = 0,
    this.scoreReplayTrigger,
    this.coachProvider,
    this.coachRepository,
    this.coachContext,
    this.friendsController,
    this.onNavigateToFriends,
    super.key,
  });

  final DashboardController? controller;
  final VoidCallback? onStartWorkout;
  final VoidCallback? onNavigateToWorkouts;
  final int entryReplayKey;
  final ValueListenable<int>? scoreReplayTrigger;
  final CoachContextProvider? coachProvider;
  final CoachRepository? coachRepository;
  final CoachContext? coachContext;
  final FriendsDashboardController? friendsController;
  final VoidCallback? onNavigateToFriends;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late final DashboardController _controller =
      widget.controller ?? DashboardController();
  late final bool _ownsController = widget.controller == null;
  late final FriendsDashboardController _friendsController =
      widget.friendsController ?? FriendsDashboardController();
  late final bool _ownsFriendsController = widget.friendsController == null;
  bool _isRefreshing = false;
  bool _loggedFirstBuild = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller;
    unawaited(_friendsController.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.refreshHealthIfDue());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) _controller.dispose();
    if (_ownsFriendsController) _friendsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedFirstBuild) {
      _loggedFirstBuild = true;
      PerfDiagnostics.log('DashboardScreen first build');
    }
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      child: AnimatedBuilder(
        animation: widget.coachProvider == null
            ? Listenable.merge([_controller, _friendsController])
            : Listenable.merge([
                _controller,
                _friendsController,
                widget.coachProvider!,
              ]),
        builder: (context, _) {
        final data = _controller.snapshot;
        final coachContext =
            widget.coachContext ?? widget.coachProvider?.context;
        final engine = const CoachEngine();
        final generatedCoachInsights = coachContext == null
            ? const <CoachInsight>[]
            : engine.withoutRecentlyShown(
                engine.generate(coachContext).where(
                  (insight) =>
                      widget.coachRepository?.wasDismissed(
                        insight.id,
                        coachContext.now,
                      ) !=
                      true,
                ),
                widget.coachRepository?.shownTimestamps() ?? const {},
                now: coachContext.now,
              );
        final dashboardCoachInsights = generatedCoachInsights
            .take(3)
            .toList(growable: false);
        if (coachContext != null && widget.coachRepository != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(
                CoachNudgeService.instance.rescheduleIfChanged(
                  coachContext,
                  widget.coachRepository!,
                ),
              );
            }
          });
        }
        if (kDebugMode) {
          debugPrint(
            'Dashboard ACTIVE KCAL ring input: '
            '${data.healthSummary?.activeCaloriesBurned ?? 'unavailable'} / 500',
          );
        }
        if (data.isLoading) {
          return _loadingBody(context);
        }

        final today = DateTime.now();
        final weeklyAverage = data.weeklyVolumes.isEmpty
            ? 0.0
            : data.weeklyVolumes.reduce((sum, value) => sum + value) /
                  data.weeklyVolumes.length;
        final steps = (data.healthSummary?.steps ?? 0).toDouble();
        return RefreshIndicator(
          color: tokens.accentTeal,
          backgroundColor: tokens.surface,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ForgeSpacing.md,
              ForgeSpacing.screenTop,
              ForgeSpacing.md,
              120 + safeBottom,
            ),
            children: [
              DashboardHeader(
                date: today,
                streak: _streakDays(data),
                displayName: data.displayName,
                isSyncing: data.healthLoading,
                onSync: () => unawaited(_refresh()),
                onSettings: _openSettings,
                onFriends: _openFriends,
                incomingRequestCount:
                    _friendsController.incomingRequestCount,
                reduceMotion: reduceMotion,
              ),
              const SizedBox(height: ForgeSpacing.cardGap),
              DashboardEntry(
                index: 0,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: LiquidStartButton(
                  key: ValueKey(
                    'dashboard-start-workout-${widget.entryReplayKey}',
                  ),
                  hasActiveWorkout: data.hasActiveWorkout,
                  nextTemplateName: data.templates.isEmpty
                      ? null
                      : data.templates.first.name,
                  reduceMotion: reduceMotion,
                  onStartWorkout: () =>
                      widget.onStartWorkout == null
                          ? _startOrResumeWorkout(data)
                          : widget.onStartWorkout!(),
                ),
              ),
              const SizedBox(height: ForgeSpacing.cardGap),
              DashboardEntry(
                index: 1,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardScoresCard(
                  key: ValueKey('dashboard-scores-${widget.entryReplayKey}'),
                  scores: data.scores,
                  history: data.scoreHistory,
                  replayTrigger: widget.scoreReplayTrigger,
                  reduceMotion: reduceMotion,
                  isRefreshing: _isRefreshing || data.healthLoading,
                  onOpenHealth: () => _openHealthTab(0),
                  hasHealthData: data.healthSummary?.hasAnyData == true,
                ),
              ),
              const SizedBox(height: ForgeSpacing.cardGap),
              DashboardEntry(
                index: 2,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardCoachCard(
                  insights: coachContext == null
                      ? const []
                      : dashboardCoachInsights,
                  onOpen: () => _openCoach(
                    coachContext ?? CoachContext(now: DateTime.now()),
                  ),
                  onInsightShown: (insight) {
                    final repository = widget.coachRepository;
                    if (repository == null || coachContext == null) return;
                    unawaited(() async {
                      await repository.markShown(insight.id, coachContext.now);
                      await CoachNudgeService.instance.rescheduleIfChanged(
                        coachContext,
                        repository,
                      );
                    }());
                  },
                ),
              ),
              const SizedBox(height: ForgeSpacing.cardGap),
              DashboardEntry(
                index: 3,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardFriendsCard(
                  controller: _friendsController,
                  onSeeAll: _openFriends,
                  onOpenFriend: _openFriend,
                ),
              ),
              const SizedBox(height: ForgeSpacing.cardGap),
              DashboardEntry(
                index: 4,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: _NextTemplateCard(
                  template: data.templates.isEmpty
                      ? null
                      : data.templates.first,
                  onTap: data.templates.isEmpty
                      ? _openTemplates
                      : () => _openTemplate(data.templates.first),
                  onAllTemplates: _openTemplates,
                ),
              ),
              const SizedBox(height: ForgeSpacing.cardGap),
              DashboardEntry(
                index: 4,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardRingsCard(
                  key: ValueKey('dashboard-progress-${widget.entryReplayKey}'),
                  metrics: [
                    DashboardRingMetric(
                      keyName: 'dashboard-volume-ring',
                      label: 'VOLUME',
                      value: data.todayVolume,
                      goal: weeklyAverage,
                      gradient: tokens.primaryGradient,
                    ),
                    DashboardRingMetric(
                      keyName: 'dashboard-calorie-ring',
                      label: 'ACTIVE KCAL',
                      value:
                          data.healthSummary?.activeCaloriesBurned ?? 0,
                      goal: 500,
                      gradient: tokens.energyGradient,
                    ),
                    DashboardRingMetric(
                      keyName: 'dashboard-steps-ring',
                      label: 'STEPS',
                      value: steps,
                      goal: 10000,
                      gradient: tokens.chartGradient,
                    ),
                  ],
                  reduceMotion: reduceMotion,
                  isRefreshing: _isRefreshing || data.healthLoading,
                  onTap: () => _openHealthTab(0),
                ),
              ),
              const SizedBox(height: ForgeSpacing.cardGap),
              DashboardEntry(
                index: 4,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardMusclesCard(
                  muscles: data.todayMuscles,
                  volume: data.todayVolume,
                  reps: data.todayReps,
                  onTap: _openWorkouts,
                ),
              ),
              const SizedBox(height: ForgeSpacing.md),
              DashboardEntry(
                index: 5,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardWeekCard(
                  key: ValueKey('dashboard-week-${widget.entryReplayKey}'),
                  volumes: data.weeklyVolumes,
                  workoutCount: data.weeklyWorkoutCount,
                  todayWeekday: today.weekday,
                  reduceMotion: reduceMotion,
                  onTap: widget.onNavigateToWorkouts,
                ),
              ),
              const SizedBox(height: ForgeSpacing.md),
              DashboardEntry(
                index: 6,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardNutritionCard(
                  calories: data.calories,
                  calorieGoal: data.calorieGoal,
                  protein: data.protein,
                  proteinGoal: data.proteinGoal,
                  carbs: data.carbs,
                  carbsGoal: data.carbsGoal,
                  fat: data.fat,
                  fatGoal: data.fatGoal,
                  onAddFood: () => _openHealthTab(2),
                  reduceMotion: reduceMotion,
                  onOpenNutrition: () => _openHealthTab(2),
                ),
              ),
              const SizedBox(height: ForgeSpacing.md),
              DashboardEntry(
                index: 7,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardHealthCard(
                  summary: data.healthSummary,
                  isLoading: data.healthLoading,
                  error: data.healthError,
                  hasPermissions: data.hasHealthPermissions,
                  lastSyncedAt: data.lastHealthSync,
                  onOpenHealth: () => _openHealthTab(0),
                ),
              ),
              const SizedBox(height: ForgeSpacing.md),
              DashboardEntry(
                index: 8,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardBodyCard(
                  entries: data.bodyLogs,
                  onTap: () => _openHealthTab(1),
                  reduceMotion: reduceMotion,
                ),
              ),
              const SizedBox(height: ForgeSpacing.md),
              DashboardEntry(
                index: 9,
                reduceMotion: reduceMotion,
                replayKey: widget.entryReplayKey,
                child: DashboardRecentCard(
                  sessions: data.recentWorkouts,
                  onSessionTap: _openWorkout,
                  onSeeAll: _openWorkouts,
                ),
              ),
              if (data.prs.isNotEmpty) ...[
                const SizedBox(height: ForgeSpacing.md),
                DashboardEntry(
                  index: 10,
                  reduceMotion: reduceMotion,
                  replayKey: widget.entryReplayKey,
                  child: DashboardPrCard(
                    records: data.prs,
                    onTap: _openWorkouts,
                  ),
                ),
              ],
              if (data.localError != null) ...[
                const SizedBox(height: ForgeSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    data.localError!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: tokens.error),
                  ),
                ),
              ],
            ],
          ),
        );
        },
      ),
    );
  }

  Widget _loadingBody(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ForgeSpacing.md),
      children: const [
        ShimmerBox(width: 190, height: 48),
        SizedBox(height: ForgeSpacing.lg),
        ShimmerBox(width: double.infinity, height: 150, borderRadius: 28),
        SizedBox(height: ForgeSpacing.md),
        ShimmerBox(width: double.infinity, height: 210, borderRadius: 24),
        SizedBox(height: ForgeSpacing.md),
        ShimmerBox(width: double.infinity, height: 180, borderRadius: 24),
      ],
    );
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    var synced = false;
    try {
      synced = await _controller.refresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              synced ? 'Synced' : 'Health data could not be synced. Check permissions and try again.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  void _startOrResumeWorkout(DashboardSnapshot data) {
    if (data.hasActiveWorkout && data.activeDraft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The saved workout could not be resumed. Open Workouts to review it.',
          ),
        ),
      );
      return;
    }
    if (data.hasActiveWorkout) {
      final draft = data.activeDraft!;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ActiveWorkoutScreen(sessionId: draft.id, resumeDraft: true),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(sessionId: const Uuid().v4()),
      ),
    );
  }

  void _openHealthTab(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HealthScreen(initialTabIndex: index)),
    );
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openFriends() {
    if (widget.onNavigateToFriends != null) {
      widget.onNavigateToFriends!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendsHomeScreen(displayName: _controller.snapshot.displayName),
      ),
    );
  }

  void _openFriend(FriendSummary friend) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/friends/profile'),
        builder: (_) => FriendProfileScreen(friend: friend),
      ),
    );
  }

  void _openCoach(CoachContext coachContext) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoachScreen(
          contextSnapshot: coachContext,
          repository: widget.coachRepository,
        ),
      ),
    );
  }

  void _openWorkout(WorkoutSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutDetailScreen(session: session)),
    );
  }

  void _openTemplate(WorkoutTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplateDetailScreen(template: template),
      ),
    );
  }

  void _openTemplates() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TemplatesScreen()));
  }

  void _openWorkouts() {
    if (widget.onNavigateToWorkouts != null) {
      widget.onNavigateToWorkouts!();
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const WorkoutHomeScreen()));
    }
  }

  static int _streakDays(DashboardSnapshot data) {
    final days = data.sessions.map((session) {
      final date = session.date.toLocal();
      return DateTime(date.year, date.month, date.day);
    }).toSet();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    if (data.hasActiveWorkout) days.add(todayStart);
    var cursor = days.contains(todayStart)
        ? todayStart
        : todayStart.subtract(const Duration(days: 1));
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _NextTemplateCard extends StatelessWidget {
  const _NextTemplateCard({
    required this.template,
    required this.onTap,
    required this.onAllTemplates,
  });

  final WorkoutTemplate? template;
  final VoidCallback onTap;
  final VoidCallback onAllTemplates;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return DashboardCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: ForgeSpacing.md,
        vertical: ForgeSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.event_note_rounded, color: tokens.accentTeal),
          const SizedBox(width: ForgeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template == null ? 'WORKOUT TEMPLATES' : 'NEXT PLANNED',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: tokens.textSecondary),
                ),
                Text(
                  template?.name ?? 'Browse and build a plan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onAllTemplates, child: const Text('View')),
        ],
      ),
    );
  }
}

class DashboardEntry extends StatefulWidget {
  const DashboardEntry({
    required this.index,
    required this.reduceMotion,
    required this.child,
    this.replayKey = 0,
    super.key,
  });

  final int index;
  final bool reduceMotion;
  final Widget child;
  final int replayKey;

  @override
  State<DashboardEntry> createState() => _DashboardEntryState();
}

class _DashboardEntryState extends State<DashboardEntry>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Timer? _delay;
  bool _standaloneAnimationStarted = false;
  bool _sawSplashTimeline = false;
  bool _introComplete = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SplashAnimationScope.maybeOf(context) != null) {
      _sawSplashTimeline = true;
      _delay?.cancel();
      _controller?.dispose();
      _controller = null;
      return;
    }
    if (_sawSplashTimeline) {
      _introComplete = true;
      _delay?.cancel();
      _controller?.dispose();
      _controller = null;
      return;
    }
    _startStandaloneAnimation();
  }

  void _startStandaloneAnimation() {
    if (_standaloneAnimationStarted) return;
    _standaloneAnimationStarted = true;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: ForgeMotion.cardEntry,
    );
    if (widget.reduceMotion) {
      controller.value = 1;
    } else {
      _delay = Timer(ForgeMotion.cardStagger * widget.index, () {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DashboardEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayKey != widget.replayKey) {
      _replayEntry();
      return;
    }
    if (oldWidget.reduceMotion != widget.reduceMotion && widget.reduceMotion) {
      _delay?.cancel();
      _controller?.value = 1;
      _introComplete = true;
    }
  }

  void _replayEntry() {
    _delay?.cancel();
    if (widget.reduceMotion) {
      _controller?.value = 1;
      _introComplete = true;
      return;
    }
    _introComplete = false;
    _controller ??= AnimationController(
      vsync: this,
      duration: ForgeMotion.cardEntry,
    );
    _controller!
      ..stop()
      ..value = 0;
    _delay = Timer(
      ForgeMotion.tabCardEntryDelay + ForgeMotion.tabCardStagger * widget.index,
      () {
        if (mounted) _controller?.forward();
      },
    );
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final splashAnimation = SplashAnimationScope.maybeOf(context);
    if (splashAnimation != null) {
      _sawSplashTimeline = true;
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: splashAnimation,
          child: widget.child,
          builder: (context, child) => _buildEntry(
            child,
            _introProgress(splashAnimation.value, widget.index),
          ),
        ),
      );
    }
    if (_introComplete || widget.reduceMotion) {
      return RepaintBoundary(child: widget.child);
    }
    final controller = _controller;
    if (controller == null) return RepaintBoundary(child: widget.child);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        child: widget.child,
        builder: (context, child) => _buildEntry(child, controller.value),
      ),
    );
  }

  Widget _buildEntry(Widget? child, double progress) => Opacity(
    opacity: progress,
    child: Transform.translate(
      offset: Offset(0, (1 - progress) * ForgeMotion.tabCardOffset),
      child: child,
    ),
  );

  static double _introProgress(double animationValue, int index) {
    if (animationValue >= 1) return 1;
    final elapsed =
        animationValue * ForgeMotion.dashboardSplashTimeline.inMilliseconds;
    final delay = ForgeMotion.cardStagger.inMilliseconds * index;
    final progress =
        ((elapsed -
                    (ForgeMotion.dashboardEntryIntroDelay.inMilliseconds +
                        delay)) /
                ForgeMotion.cardEntry.inMilliseconds)
            .clamp(0.0, 1.0);
    return ForgeMotion.referenceEase.transform(progress);
  }
}
