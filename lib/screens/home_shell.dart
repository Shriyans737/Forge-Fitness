import 'dart:async';

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/widgets/glass_nav_bar.dart';
import '../features/coach/coach_copy.dart';
import '../features/coach/coach_screen.dart';
import '../features/coach/services/coach_context_provider.dart';
import '../features/coach/services/coach_nudge_service.dart';
import '../features/coach/services/coach_repository.dart';
import '../features/coach/weekly_review_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/dashboard_controller.dart';
import '../services/friends_dashboard_controller.dart';
import '../widgets/ui/floating_bottom_nav.dart';
import 'floating_chat_overlay.dart';
import 'friends_screen.dart';
import 'health_screen.dart';
import 'library_screen.dart';
import 'workout_home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  late bool _reduceMotion = false;
  final ValueNotifier<int> _dashboardReplayTrigger = ValueNotifier(0);
  late final DashboardController _dashboardController;
  late final FriendsDashboardController _friendsDashboardController;
  late final CoachContextProvider _coachContextProvider;
  late final CoachRepository _coachRepository;
  late final AnimationController _tabTransition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    value: 1,
  );
  late final Animation<double> _tabFade = _tabTransition.drive(
    CurveTween(curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    registerForgeMainShell();
    _dashboardController = DashboardController();
    _friendsDashboardController = FriendsDashboardController();
    unawaited(_friendsDashboardController.start());
    _coachContextProvider = CoachContextProvider(_dashboardController);
    _coachRepository = CoachRepository();
    WidgetsBinding.instance.addObserver(this);
    CoachNudgeService.routeRequests.addListener(_handleCoachNotification);
  }

  static const List<FloatingNavItem> _items = [
    FloatingNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    FloatingNavItem(
      label: 'Workouts',
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center_rounded,
    ),
    FloatingNavItem(
      label: 'Library',
      icon: Icons.library_books_outlined,
      selectedIcon: Icons.library_books_rounded,
    ),
    FloatingNavItem(
      label: 'Health',
      icon: Icons.favorite_outline,
      selectedIcon: Icons.favorite_rounded,
    ),
    FloatingNavItem(
      label: 'Friends',
      icon: Icons.people_alt_outlined,
      selectedIcon: Icons.people_alt_rounded,
    ),
  ];

  late final List<Widget?> _screens = List<Widget?>.filled(_items.length, null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    unregisterForgeMainShell();
    WidgetsBinding.instance.removeObserver(this);
    CoachNudgeService.routeRequests.removeListener(_handleCoachNotification);
    _dashboardReplayTrigger.dispose();
    _coachContextProvider.dispose();
    _dashboardController.dispose();
    _friendsDashboardController.dispose();
    _tabTransition.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selectedIndex == 0) {
      _dashboardReplayTrigger.value++;
    }
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _items.length || index == _selectedIndex) return;
    _screens[index] ??= _screenFor(index);
    if (_reduceMotion) {
      _tabTransition
        ..stop()
        ..value = 1;
      setState(() => _selectedIndex = index);
      return;
    }
    _tabTransition
      ..stop()
      ..value = 0;
    setState(() => _selectedIndex = index);
    _tabTransition.forward();
  }

  Widget _screenFor(int index) => switch (index) {
    0 => DashboardScreen(
      controller: _dashboardController,
      scoreReplayTrigger: _dashboardReplayTrigger,
      coachProvider: _coachContextProvider,
      coachRepository: _coachRepository,
      friendsController: _friendsDashboardController,
      onNavigateToWorkouts: () => _selectTab(1),
      onNavigateToFriends: () => _selectTab(4),
    ),
    1 => const WorkoutHomeScreen(),
    2 => const LibraryScreen(),
    3 => HealthScreen(onOpenCoach: _openCoach),
    4 => FriendsHomeScreen(
      displayName: _dashboardController.snapshot.displayName,
    ),
    _ => const SizedBox.shrink(),
  };

  void _openCoach(BuildContext context) {
    final coachContext = _coachContextProvider.context;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoachScreen(
          contextSnapshot: coachContext,
          repository: _coachRepository,
        ),
      ),
    );
  }

  void _handleCoachNotification() {
    final route = CoachNudgeService.routeRequests.value;
    if (route == null || !mounted) return;
    CoachNudgeService.routeRequests.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (route == CoachCopy.weeklyReviewRoute) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WeeklyReviewScreen(
              contextSnapshot: _coachContextProvider.context,
              repository: _coachRepository,
            ),
          ),
        );
      } else {
        _openCoach(context);
      }
    });
  }

  Widget _screenLayer(int index, Widget? screen) {
    final isSelected = index == _selectedIndex;
    return Positioned.fill(
      key: ValueKey('tab-layer-$index'),
      child: Offstage(
        offstage: !isSelected,
        child: TickerMode(
          enabled: isSelected,
          child: IgnorePointer(
            ignoring: !isSelected,
            child: isSelected && !_reduceMotion
                ? FadeTransition(
                    opacity: _tabFade,
                    child: screen ?? const SizedBox.shrink(),
                  )
                : screen ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _screens[_selectedIndex] ??= _screenFor(_selectedIndex);
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              gradient: RadialGradient(
                center: const Alignment(0, -1.1),
                radius: 1.25,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  Theme.of(context).colorScheme.surface,
                ],
                stops: const [0, 0.7],
              ),
            ),
          ),
          for (var index = 0; index < _screens.length; index++)
            _screenLayer(index, _screens[index]),
          AnimatedBuilder(
            animation: _friendsDashboardController,
            builder: (context, _) => Positioned(
              left: ForgeMotion.navHorizontalInset,
              right: ForgeMotion.navHorizontalInset,
              bottom: safeBottom,
              child: GlassNavBar(
                items: [
                  ..._items.take(4),
                  FloatingNavItem(
                    label: _items[4].label,
                    icon: _items[4].icon,
                    selectedIcon: _items[4].selectedIcon,
                    badgeCount:
                        _friendsDashboardController.incomingRequestCount,
                  ),
                ],
                selectedIndex: _selectedIndex,
                onTap: _selectTab,
                reduceMotion: _reduceMotion,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
