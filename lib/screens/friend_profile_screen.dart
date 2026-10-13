import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/dashboard/widgets/dashboard_card.dart';
import '../services/friend_data_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/friends_service.dart';
import '../services/profile_service.dart';
import '../theme.dart';
import 'chat_screen.dart';

class FriendProfileScreen extends StatefulWidget {
  const FriendProfileScreen({
    required this.friend,
    this.loadFriendData,
    super.key,
  });

  final FriendSummary friend;
  final Future<FriendSharedData> Function(String uid)? loadFriendData;

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final AuthService _authService = AuthService();
  bool _openingChat = false;
  bool _blockingFriend = false;
  late Future<FriendSharedData> _loadFuture;
  late Future<FriendSharedData> Function(String uid) _loadFriendData;
  late DateTime _selectedDay;
  late final List<DateTime> _days;
  late final ScrollController _dayStripController;

  @override
  void initState() {
    super.initState();
    _loadFriendData =
        widget.loadFriendData ?? FriendDataService().fetchForFriend;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDay = today;
    _dayStripController = ScrollController();
    _days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
    _loadFuture = _loadFriendData(widget.friend.uid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dayStripController.hasClients) {
        _dayStripController.jumpTo(
          _dayStripController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  void dispose() {
    _dayStripController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final nextLoad = _loadFriendData(widget.friend.uid);
    setState(() => _loadFuture = nextLoad);
    await nextLoad;
  }

  Future<void> _openChat() async {
    setState(() => _openingChat = true);
    try {
      final uid = await _authService.signInAnonymouslyIfNeeded();
      final profileSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final profileData = profileSnapshot.data();
      if (profileData == null) {
        throw StateError('Create your Friends profile before messaging.');
      }
      final profile = UserProfile.fromMap(uid, profileData);
      if (!mounted) return;
      final conversation = ChatConversation.directMessage(
        currentUid: uid,
        currentUsername: profile.username,
        friend: widget.friend,
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: '/chat',
            arguments: conversation.id,
          ),
          builder: (_) => ChatScreen(
            service: ChatService(uid: uid, username: profile.username),
            conversation: conversation,
          ),
        ),
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Opening friend chat failed (${error.code}): '
        '${error.message}\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kDebugMode
                  ? 'Could not open chat (${error.code}).'
                  : 'Could not open chat right now.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Opening friend chat failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kDebugMode ? '$error' : 'Could not open chat.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friend.displayName),
        actions: [
          IconButton(
            tooltip: 'Block friend',
            onPressed: _blockingFriend ? null : _confirmBlockFriend,
            icon: _blockingFriend
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.block_rounded),
          ),
          TextButton.icon(
            onPressed: _openingChat ? null : _openChat,
            icon: _openingChat
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Message'),
          ),
        ],
      ),
      body: FutureBuilder<FriendSharedData>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return _loadingBody();
          }
          if (snapshot.hasError) {
            return _loadError(snapshot.error!);
          }
          final data = snapshot.data;
          if (data == null) return _loadError('Friend data is unavailable.');
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                DashboardCard(
                  surfaceGradient: tokens.primaryGradient.withOpacity(0.10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: tokens.surfaceVariant,
                        foregroundColor: tokens.accentTeal,
                        child: Text(
                          widget.friend.displayName.isEmpty
                              ? '?'
                              : widget.friend.displayName.characters.first
                                    .toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.friend.displayName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '@${widget.friend.username}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _lastSynced(data.lastSynced),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: tokens.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.hasNetworkError) ...[
                  const SizedBox(height: 10),
                  _notice(
                    'Some shared data is unavailable offline. Pull to refresh '
                    'when connected.',
                    tokens.warning,
                  ),
                ],
                const SizedBox(height: 14),
                _trendCard(data),
                const SizedBox(height: 16),
                _daySelector(data),
                const SizedBox(height: 18),
                _workoutSection(data),
                const SizedBox(height: 12),
                _foodSection(data),
                const SizedBox(height: 12),
                _healthSection(data),
                const SizedBox(height: 12),
                _bodySection(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmBlockFriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
          'They will be removed from your friends, their direct chat will be '
          'hidden, and you will not receive their friend requests. In shared '
          'groups, their messages will be hidden unless you choose to show them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _blockingFriend = true);
    try {
      final uid = await _authService.signInAnonymouslyIfNeeded();
      final profile = await ProfileService().getProfile(uid);
      if (profile == null) {
        throw StateError('Create a Friends profile before blocking.');
      }
      await ChatService(uid: uid, username: profile.username).blockUser(
        otherUid: widget.friend.uid,
        otherUsername: widget.friend.username,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Blocking friend failed (${error.code}): ${error.message}\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kDebugMode
                  ? 'Could not block user (${error.code}).'
                  : 'Could not block user right now.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Blocking friend failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kDebugMode ? '$error' : 'Could not block user.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _blockingFriend = false);
    }
  }

  Widget _loadingBody() {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        for (var index = 0; index < 6; index++) ...[
          Container(
            height: index == 0 ? 88 : 116,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: tokens.surfaceVariant,
              borderRadius: BorderRadius.circular(tokens.cardRadius),
            ),
          ),
        ],
      ],
    );
  }

  Widget _loadError(Object error) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final isOffline =
        error is FriendDataLoadException && error.code == 'unavailable' ||
        error is FirebaseException && error.code == 'unavailable';
    final code = switch (error) {
      FriendDataLoadException loadError => loadError.code,
      FirebaseException firebaseError => firebaseError.code,
      _ => 'unknown',
    };
    final message = isOffline
        ? 'Can’t load shared data while offline. Pull to retry when connected.'
        : kDebugMode
        ? 'Couldn’t load shared data ($code): $error'
        : 'Couldn’t load shared data. Please try again.';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 72),
          Icon(
            isOffline ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
            size: 44,
            color: tokens.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: () => unawaited(_refresh()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendCard(FriendSharedData data) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7-DAY SNAPSHOT', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 14),
          _trendRow(
            'Steps',
            Icons.directions_walk_rounded,
            data.health,
            (map) => _asDouble(map['steps']),
            tokens.accentTeal,
          ),
          const SizedBox(height: 12),
          _trendRow(
            'Calories',
            Icons.local_fire_department_rounded,
            data.food,
            (map) => _asDouble(map['calories']),
            tokens.warning,
          ),
          const SizedBox(height: 12),
          _trendRow(
            'Workout volume',
            Icons.fitness_center_rounded,
            data.workouts,
            (map) => _asDouble(_map(map['dailyTotals'])?['totalVolume']),
            tokens.accentLime,
          ),
        ],
      ),
    );
  }

  Widget _trendRow(
    String label,
    IconData icon,
    SharedCategoryData category,
    double? Function(Map<String, dynamic>) getValue,
    Color color,
  ) {
    final values = _days
        .map((day) => category.dataFor(day))
        .map((day) => day == null ? null : getValue(day))
        .toList(growable: false);
    final maxValue = values.whereType<double>().fold<double>(
      0,
      (maximum, value) => value > maximum ? value : maximum,
    );
    return Row(
      children: [
        SizedBox(
          width: 102,
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final value in values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FractionallySizedBox(
                        heightFactor: value == null || maxValue <= 0
                            ? 0.08
                            : (value / maxValue).clamp(0.08, 1.0),
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: value == null
                                ? Theme.of(context).colorScheme.outline
                                      .withValues(alpha: 0.22)
                                : color.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _daySelector(FriendSharedData data) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DAY', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            controller: _dayStripController,
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = _days[index];
              final hasData = [
                data.workouts,
                data.food,
                data.health,
                data.body,
              ].any((category) => category.dataFor(day) != null);
              final selected = day == _selectedDay;
              return InkWell(
                borderRadius: BorderRadius.circular(tokens.pillRadius),
                onTap: () => setState(() => _selectedDay = day),
                child: Container(
                  key: ValueKey('friend-day-${FriendDataService.dayId(day)}'),
                  width: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.pillRadius),
                    gradient: selected ? tokens.primaryGradient : null,
                    color: selected ? null : tokens.surface,
                    border: Border.all(
                      color: selected ? Colors.transparent : tokens.border,
                    ),
                  ),
                  child: Opacity(
                    opacity: hasData ? 1 : 0.42,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day == _days.last ? 'Today' : _weekday(day),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: selected
                                    ? tokens.background
                                    : tokens.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? tokens.background
                                    : tokens.textPrimary,
                              ),
                        ),
                        if (hasData)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? tokens.background
                                  : tokens.accentTeal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _workoutSection(FriendSharedData data) {
    final category = data.workouts;
    final selectedData = category.dataFor(_selectedDay);
    return _categoryCard(
      'Workouts',
      Icons.fitness_center_rounded,
      category,
      child: selectedData == null
          ? const _NoDayData()
          : _workoutData(selectedData),
    );
  }

  Widget _workoutData(Map<String, dynamic> data) {
    final workouts = _asList(data['workouts']);
    if (workouts.isEmpty) return const _NoDayData();
    return Column(
      children: [
        for (final rawWorkout in workouts)
          if (_map(rawWorkout) case final workout?)
            _ExpandableWorkout(workout: workout),
        const SizedBox(height: 8),
        _pillMetrics([
          _metric(
            'Volume',
            _formatNumber(_map(data['dailyTotals'])?['totalVolume']),
          ),
          _metric(
            'Reps',
            _formatNumber(_map(data['dailyTotals'])?['totalReps']),
          ),
        ]),
      ],
    );
  }

  Widget _foodSection(FriendSharedData data) {
    final category = data.food;
    final selectedData = category.dataFor(_selectedDay);
    return _categoryCard(
      'Food',
      Icons.restaurant_rounded,
      category,
      child: selectedData == null
          ? const _NoDayData()
          : _foodData(selectedData),
    );
  }

  Widget _foodData(Map<String, dynamic> data) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final goals = _map(data['goals']);
    final calories = _asDouble(data['calories']);
    final calorieGoal = _asDouble(goals?['calories']);
    final foods = _asList(data['foods'])
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .toList();
    final meals = <String, List<Map<String, dynamic>>>{};
    for (final food in foods) {
      final meal = food['meal'] is String && (food['meal'] as String).isNotEmpty
          ? food['meal'] as String
          : 'Other';
      meals.putIfAbsent(meal, () => []).add(food);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              height: 72,
              width: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: calorieGoal != null && calorieGoal > 0
                        ? ((calories ?? 0) / calorieGoal).clamp(0.0, 1.0)
                        : 0,
                    strokeWidth: 7,
                    backgroundColor: tokens.surfaceVariant,
                    color: tokens.accentTeal,
                  ),
                  Text(
                    calories == null ? '—' : calories.round().toString(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                calorieGoal == null
                    ? 'Calories'
                    : '${_formatNumber(calories)} of '
                          '${_formatNumber(calorieGoal)} kcal',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _macroBar(
          'Protein',
          data['protein'],
          goals?['protein'],
          tokens.accentTeal,
        ),
        const SizedBox(height: 10),
        _macroBar('Carbs', data['carbs'], goals?['carbs'], tokens.accentLime),
        const SizedBox(height: 10),
        _macroBar('Fat', data['fat'], goals?['fat'], tokens.warning),
        if (meals.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final entry in meals.entries) ...[
            Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
            for (final food in entry.value)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_asString(food['name'], 'Food')),
                trailing: Text('${_formatNumber(food['calories'])} kcal'),
              ),
          ],
        ],
      ],
    );
  }

  Widget _macroBar(
    String label,
    Object? rawValue,
    Object? rawGoal,
    Color color,
  ) {
    final value = _asDouble(rawValue);
    final goal = _asDouble(rawGoal);
    return Row(
      children: [
        SizedBox(
          width: 66,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: goal != null && goal > 0
                ? ((value ?? 0) / goal).clamp(0.0, 1.0)
                : 0,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            color: color,
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: Text(
            '${_formatNumber(value)}g'
            '${goal == null ? '' : ' / ${_formatNumber(goal)}g'}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }

  Widget _healthSection(FriendSharedData data) {
    final category = data.health;
    final selectedData = category.dataFor(_selectedDay);
    return _categoryCard(
      'Health',
      Icons.favorite_rounded,
      category,
      child: selectedData == null
          ? const _NoDayData()
          : _healthData(selectedData),
    );
  }

  Widget _healthData(Map<String, dynamic> data) {
    final metrics = <Widget>[
      if (_asDouble(data['steps']) case final value?)
        _metric('Steps', _formatNumber(value)),
      if (_asDouble(data['activeCalories']) case final value?)
        _metric('Active kcal', _formatNumber(value)),
      if (_asDouble(data['sleepHours']) case final value?)
        _metric('Sleep', '${value.toStringAsFixed(1)} h'),
      if (_asDouble(data['restingHeartRate']) case final value?)
        _metric('Resting HR', '${value.round()} bpm'),
      if (_asDouble(data['averageHeartRate']) case final value?)
        _metric('Average HR', '${value.round()} bpm'),
    ];
    final workouts = _asList(data['workouts'])
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pillMetrics(metrics),
        if (workouts.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final workout in workouts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_sportIcon(workout['sport'])),
              title: Text(_asString(workout['sport'], 'Workout')),
              subtitle: Text(
                '${_formatNumber(workout['durationMinutes'])} min · '
                '${_formatNumber(workout['calories'])} kcal',
              ),
            ),
        ],
      ],
    );
  }

  Widget _bodySection(FriendSharedData data) {
    final category = data.body;
    final selectedData = category.dataFor(_selectedDay);
    return _categoryCard(
      'Body',
      Icons.monitor_weight_outlined,
      category,
      child: selectedData == null
          ? const _NoDayData()
          : _bodyData(selectedData),
    );
  }

  Widget _bodyData(Map<String, dynamic> data) {
    final measurements = _map(data['measurements']) ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_asDouble(data['weightKg']) case final weight?)
          Text(
            '${weight.toStringAsFixed(1)} kg',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        if (measurements.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: measurements.entries.map((entry) {
              final label = entry.key.isEmpty
                  ? entry.key
                  : '${entry.key[0].toUpperCase()}${entry.key.substring(1)}';
              return _pill('$label: ${_formatNumber(entry.value)} cm');
            }).toList(),
          ),
        ],
        if (data['weightKg'] == null && measurements.isEmpty)
          const _NoDayData(),
      ],
    );
  }

  Widget _categoryCard(
    String title,
    IconData icon,
    SharedCategoryData category, {
    required Widget child,
  }) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    if (!category.shared) {
      return DashboardCard(
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: tokens.textMuted, size: 18),
            const SizedBox(width: 9),
            Text(
              "$title isn't sharing this.",
              style: TextStyle(color: tokens.textSecondary),
            ),
          ],
        ),
      );
    }
    if (category.errorCode != null) {
      final isOffline = category.errorCode == 'unavailable';
      final text = isOffline
          ? 'Can’t load this shared category while offline.'
          : kDebugMode
          ? 'Couldn’t load $title (${category.errorCode}): '
                '${category.errorMessage ?? 'No details.'}'
          : 'Couldn’t load $title. Please try again.';
      return DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(title, icon),
            const SizedBox(height: 10),
            Text(text, style: TextStyle(color: tokens.textSecondary)),
          ],
        ),
      );
    }
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_cardHeader(title, icon), const SizedBox(height: 14), child],
      ),
    );
  }

  Widget _cardHeader(String title, IconData icon) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Icon(icon, color: tokens.accentTeal, size: 19),
      ],
    );
  }

  Widget _pillMetrics(List<Widget> items) =>
      Wrap(spacing: 8, runSpacing: 8, children: items);

  Widget _metric(String label, String value) => _pill('$label · $value');

  Widget _pill(String text) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.pillRadius),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Widget _notice(String text, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );

  String _lastSynced(DateTime? date) {
    if (date == null) return 'No shared data synced yet';
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inSeconds < 60) return 'Last synced just now';
    if (elapsed.inMinutes < 60) return 'Last synced ${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return 'Last synced ${elapsed.inHours}h ago';
    return 'Last synced ${elapsed.inDays}d ago';
  }

  String _weekday(DateTime date) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    return null;
  }

  static List<dynamic> _asList(Object? value) =>
      value is List ? value : const [];

  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  static String _asString(Object? value, String fallback) =>
      value is String && value.isNotEmpty ? value : fallback;

  static String _formatNumber(Object? value) {
    final number = _asDouble(value);
    if (number == null) return '—';
    return number == number.roundToDouble()
        ? number.round().toString()
        : number.toStringAsFixed(1);
  }

  static IconData _sportIcon(Object? sport) {
    final value = sport?.toString().toLowerCase() ?? '';
    if (value.contains('run')) return Icons.directions_run_rounded;
    if (value.contains('cycle') || value.contains('bike')) {
      return Icons.directions_bike_rounded;
    }
    if (value.contains('swim')) return Icons.pool_rounded;
    return Icons.fitness_center_rounded;
  }
}

class _NoDayData extends StatelessWidget {
  const _NoDayData();

  @override
  Widget build(BuildContext context) => Text(
    'No data for this day.',
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).hintColor),
  );
}

class _ExpandableWorkout extends StatelessWidget {
  const _ExpandableWorkout({required this.workout});

  final Map<String, dynamic> workout;

  @override
  Widget build(BuildContext context) {
    final exercises = _FriendProfileScreenState._asList(workout['exercises'])
        .map(_FriendProfileScreenState._map)
        .whereType<Map<String, dynamic>>()
        .toList();
    final muscles = _FriendProfileScreenState._asList(
      workout['musclesTargeted'],
    ).whereType<String>().toList();
    final icon = _FriendProfileScreenState._sportIcon(workout['sport']);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        _FriendProfileScreenState._asString(workout['name'], 'Workout'),
      ),
      subtitle: Text(
        '${_FriendProfileScreenState._formatNumber(workout['durationMinutes'])} min · '
        '${_FriendProfileScreenState._formatNumber(workout['totalVolume'])} volume · '
        '${_FriendProfileScreenState._formatNumber(workout['totalReps'])} reps',
      ),
      children: [
        if (muscles.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              children: muscles
                  .map(
                    (muscle) => Chip(
                      label: Text(muscle),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ),
        for (final exercise in exercises) _ExerciseDetails(exercise: exercise),
      ],
    );
  }
}

class _ExerciseDetails extends StatelessWidget {
  const _ExerciseDetails({required this.exercise});

  final Map<String, dynamic> exercise;

  @override
  Widget build(BuildContext context) {
    final sets = _FriendProfileScreenState._asList(exercise['sets']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            _FriendProfileScreenState._asString(exercise['name'], 'Exercise'),
          ),
        ),
        for (var index = 0; index < sets.length; index++)
          if (_FriendProfileScreenState._map(sets[index]) case final set?)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Set ${index + 1}: '
                  '${_FriendProfileScreenState._formatNumber(set['reps'])} reps '
                  '× ${_FriendProfileScreenState._formatNumber(set['weight'])} kg',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
      ],
    );
  }
}
