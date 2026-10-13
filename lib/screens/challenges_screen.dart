import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/dashboard/widgets/dashboard_card.dart';
import '../services/challenge_score_service.dart';
import '../services/challenge_service.dart';
import '../services/friends_service.dart';
import '../services/health_service.dart';
import '../theme.dart';

class ChallengesTab extends StatefulWidget {
  const ChallengesTab({
    required this.uid,
    required this.username,
    required this.friendsService,
    super.key,
  });

  final String uid;
  final String username;
  final FriendsService friendsService;

  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab> {
  late final ChallengeService _service = ChallengeService(
    uid: widget.uid,
    username: widget.username,
  );
  int _inviteCount = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChallengeInvite>>(
      stream: _service.invites(),
      builder: (context, inviteSnapshot) {
        final invites = inviteSnapshot.data ?? const <ChallengeInvite>[];
        _inviteCount = invites.length;
        return StreamBuilder<List<FitnessChallenge>>(
          stream: _service.myChallenges(),
          builder: (context, challengeSnapshot) {
            final challenges =
                challengeSnapshot.data ?? const <FitnessChallenge>[];
            final active = challenges.where((item) => !item.hasEnded).toList();
            final completed = challenges.where((item) => item.hasEnded).toList()
              ..sort((a, b) => b.endDate.compareTo(a.endDate));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Challenges',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (inviteSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !inviteSnapshot.hasData)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_inviteCount > 0)
                        _RedBadge(count: _inviteCount),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ChallengeScoreService.instance.recomputeAndUpload(
                        manual: true,
                      );
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                      children: [
                        if (inviteSnapshot.hasError)
                          _errorState(context, inviteSnapshot.error!)
                        else ...[
                          _sectionTitle(context, 'Invites', invites.length),
                          if (inviteSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !inviteSnapshot.hasData)
                            const _ChallengeSkeleton()
                          else if (invites.isEmpty)
                            const _InlineEmpty('No challenge invites.')
                          else
                            for (final invite in invites)
                              _inviteCard(context, invite),
                        ],
                        const SizedBox(height: 18),
                        if (challengeSnapshot.hasError)
                          _errorState(context, challengeSnapshot.error!)
                        else ...[
                          _sectionTitle(context, 'Active', active.length),
                          if (challengeSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !challengeSnapshot.hasData)
                            const _ChallengeSkeleton()
                          else if (active.isEmpty && invites.isEmpty)
                            _emptyChallenges(context)
                          else if (active.isEmpty)
                            const _InlineEmpty('No active challenges yet.')
                          else
                            for (final challenge in active)
                              _challengeCard(context, challenge),
                          const SizedBox(height: 18),
                          _sectionTitle(context, 'Completed', completed.length),
                          if (completed.isEmpty)
                            const _InlineEmpty(
                              'Finished challenges appear here.',
                            )
                          else
                            for (final challenge in completed)
                              _challengeCard(context, challenge),
                        ],
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openCreate(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create challenge'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _inviteCard(BuildContext context, ChallengeInvite invite) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invite.challengeName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '@${invite.fromUsername} invited you',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 10),
          const Text(
            'Joining shares only your score in this challenge.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _runAction(context, () async {
                  await _service.acceptInvite(invite);
                  unawaited(
                    ChallengeScoreService.instance.recomputeAndUpload(
                      manual: true,
                      onlyChallengeId: invite.challengeId,
                    ),
                  );
                }),
                child: const Text('Accept'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _runAction(context, () => _service.declineInvite(invite)),
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _challengeCard(
    BuildContext context,
    FitnessChallenge challenge,
  ) => StreamBuilder<List<ChallengeScoreEntry>>(
    stream: _service.watchScores(challenge.id),
    builder: (context, snapshot) {
      final entries = snapshot.data ?? const <ChallengeScoreEntry>[];
      ChallengeScoreEntry? mine;
      for (final entry in entries) {
        if (entry.uid == widget.uid) mine = entry;
      }
      final daysLeft = challenge.endDate
          .toLocal()
          .difference(DateTime.now())
          .inDays
          .clamp(0, 60);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DashboardCard(
          onTap: () => _openDetail(context, challenge),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    challenge.metric.icon,
                    color: Theme.of(context)
                        .extension<ForgeTokens>()!
                        .accentTeal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      challenge.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    challenge.hasEnded ? 'Ended' : '$daysLeft days left',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${challenge.memberUids.length} participants · '
                '${challenge.metric.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                mine == null
                    ? 'Your score is loading…'
                    : 'Your rank ${_ordinal(mine.rank)} · '
                          '${_formatScore(mine.score)} ${challenge.metric.unit}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _emptyChallenges(BuildContext context) => DashboardCard(
    child: Column(
      children: [
        Icon(
          Icons.emoji_events_outlined,
          size: 34,
          color: Theme.of(context).extension<ForgeTokens>()!.accentTeal,
        ),
        const SizedBox(height: 10),
        Text(
          'Make a friendly challenge.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Compete on workouts, volume, active days or steps.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _openCreate(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create challenge'),
        ),
      ],
    ),
  );

  Future<void> _openCreate(BuildContext context) async {
    final friends = await widget.friendsService.friends().first;
    if (!context.mounted) return;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a friend before creating a challenge.'),
        ),
      );
      return;
    }
    final challengeId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => CreateChallengeScreen(
          service: _service,
          friends: friends,
          requestHealthPermissions: HealthService().requestPermissions,
        ),
      ),
    );
    if (challengeId != null) {
      unawaited(
        ChallengeScoreService.instance.recomputeAndUpload(
          manual: true,
          onlyChallengeId: challengeId,
        ),
      );
    }
  }

  void _openDetail(BuildContext context, FitnessChallenge challenge) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/friends/challenge-detail'),
        builder: (_) => ChallengeDetailScreen(
          service: _service,
          challenge: challenge,
          friendsStream: widget.friendsService.friends(),
          currentUid: widget.uid,
        ),
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Challenge action failed (${error.code}): ${error.message}\n$stackTrace',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_firebaseMessage(error))));
      }
    } catch (error, stackTrace) {
      debugPrint('Challenge action failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kDebugMode ? '$error' : 'Could not update challenge.',
            ),
          ),
        );
      }
    }
  }

  Widget _sectionTitle(BuildContext context, String title, int count) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (count > 0) _RedBadge(count: count),
          ],
        ),
      );

  Widget _errorState(BuildContext context, Object error) {
    final code = error is FirebaseException ? error.code : 'unknown';
    final text = code == 'unavailable'
        ? 'Challenges are unavailable offline. Pull to retry.'
        : kDebugMode
        ? 'Could not load challenges ($code): $error'
        : 'Could not load challenges. Please try again.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({
    required this.service,
    required this.friends,
    required this.requestHealthPermissions,
    super.key,
  });

  final ChallengeService service;
  final List<FriendSummary> friends;
  final Future<bool> Function() requestHealthPermissions;

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selectedFriends = {};
  ChallengeMetric _metric = ChallengeMetric.workouts;
  int _days = 7;
  bool _startsTomorrow = false;
  DateTime? _customEnd;
  bool _healthAllowed = false;
  bool _requestingHealthPermission = false;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectMetric(ChallengeMetric metric) async {
    if (metric != ChallengeMetric.steps) {
      setState(() => _metric = metric);
      return;
    }
    if (_requestingHealthPermission) return;

    setState(() {
      _metric = ChallengeMetric.steps;
      _requestingHealthPermission = true;
    });
    var granted = false;
    try {
      granted = await widget.requestHealthPermissions();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Challenge Steps Health permission request failed: '
        'write=HealthService.requestPermissions; code=${error.code}; '
        'message=${error.message}\n$stackTrace',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Challenge Steps Health permission request failed: '
        'write=HealthService.requestPermissions; $error\n$stackTrace',
      );
    }
    if (!mounted) return;
    setState(() {
      _healthAllowed = granted;
      _requestingHealthPermission = false;
      if (!granted) _metric = ChallengeMetric.workouts;
    });
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Steps needs Health access')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create challenge')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          TextField(
            controller: _nameController,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Challenge name',
              hintText: 'Seven-day consistency',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Metric', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<ChallengeMetric>(
            initialValue: _metric,
            decoration: const InputDecoration(
              labelText: 'Challenge metric',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final metric in ChallengeMetric.values)
                DropdownMenuItem(
                  value: metric,
                  child: Row(
                    children: [
                      Icon(metric.icon, size: 20),
                      const SizedBox(width: 10),
                      Text(metric.label),
                    ],
                  ),
                ),
            ],
            onChanged: _requestingHealthPermission
                ? null
                : (value) {
                    if (value != null) unawaited(_selectMetric(value));
                  },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _requestingHealthPermission
                  ? 'Requesting Health access…'
                  : _healthAllowed
                  ? 'Steps uses this device’s health activity.'
                  : 'Selecting Steps will request Health access.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          Text('Duration', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (final duration in const [3, 7, 14, 30])
                ChoiceChip(
                  label: Text('$duration days'),
                  selected: _customEnd == null && _days == duration,
                  onSelected: (_) => setState(() {
                    _customEnd = null;
                    _days = duration;
                  }),
                ),
              ChoiceChip(
                label: const Text('Custom end'),
                selected: _customEnd != null,
                onSelected: (_) => _pickEndDate(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start tomorrow'),
            subtitle: const Text('Otherwise it starts today.'),
            value: _startsTomorrow,
            onChanged: (value) => setState(() => _startsTomorrow = value),
          ),
          const SizedBox(height: 10),
          Text(
            'Invite friends',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final friend in widget.friends)
            CheckboxListTile(
              value: _selectedFriends.contains(friend.uid),
              onChanged: (selected) => setState(() {
                if (selected == true) {
                  _selectedFriends.add(friend.uid);
                } else {
                  _selectedFriends.remove(friend.uid);
                }
              }),
              title: Text(friend.displayName),
              subtitle: Text('@${friend.username}'),
              secondary: CircleAvatar(
                child: Text(
                  friend.displayName.isEmpty
                      ? '?'
                      : friend.displayName.characters.first.toUpperCase(),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: _creating ? null : _create,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.emoji_events_rounded),
            label: const Text('Create and invite'),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickEndDate() async {
    final start = _startDay();
    final selected = await showDatePicker(
      context: context,
      initialDate: _customEnd ?? start.add(const Duration(days: 7)),
      firstDate: start.add(const Duration(days: 1)),
      lastDate: start.add(const Duration(days: 60)),
    );
    if (selected != null && mounted) {
      setState(
        () =>
            _customEnd = DateTime(selected.year, selected.month, selected.day),
      );
    }
  }

  DateTime _startDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _startsTomorrow ? today.add(const Duration(days: 1)) : today;
  }

  Future<void> _create() async {
    if (_selectedFriends.isEmpty) {
      setState(() => _error = 'Choose at least one friend to invite.');
      return;
    }
    final endDate = _customEnd ?? _startDay().add(Duration(days: _days));
    final startDate = _startDay();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create this challenge?'),
        content: const Text(
          'Participants will see each other’s score for this challenge only. '
          'They will not see your workouts, health details or other shared data. '
          'Joining a steps challenge uses each person’s own device health data, '
          'even if Health sharing is off.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final selected = widget.friends
          .where((friend) => _selectedFriends.contains(friend.uid))
          .toList();
      final id = await widget.service.createChallenge(
        name: _nameController.text,
        metric: _metric,
        startDate: startDate,
        endDate: endDate,
        invitees: selected,
      );
      if (mounted) Navigator.of(context).pop(id);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Challenge creation screen failed: '
        'write=ChallengeService.createChallenge; code=${error.code}; '
        'message=${error.message}\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _creating = false;
          _error = _firebaseMessage(error);
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Challenge creation failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _creating = false;
          _error = kDebugMode ? '$error' : 'Could not create this challenge.';
        });
      }
    }
  }
}

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({
    required this.service,
    required this.challenge,
    required this.friendsStream,
    required this.currentUid,
    super.key,
  });

  final ChallengeService service;
  final FitnessChallenge challenge;
  final Stream<List<FriendSummary>> friendsStream;
  final String currentUid;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      ChallengeScoreService.instance.recomputeAndUpload(
        manual: true,
        onlyChallengeId: widget.challenge.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Challenge'),
      actions: [
        PopupMenuButton<String>(
          onSelected: _onMenu,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'invite',
              child: Text('Invite more friends'),
            ),
            const PopupMenuItem(value: 'leave', child: Text('Leave challenge')),
            if (widget.challenge.creatorUid == widget.currentUid)
              const PopupMenuItem(value: 'end', child: Text('End challenge')),
            if (widget.challenge.creatorUid == widget.currentUid)
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete challenge'),
              ),
          ],
        ),
      ],
    ),
    body: StreamBuilder<FitnessChallenge?>(
      stream: widget.service.watchChallenge(widget.challenge.id),
      builder: (context, challengeSnapshot) {
        final challenge = challengeSnapshot.data ?? widget.challenge;
        if (challengeSnapshot.hasError) {
          return _detailError(context, challengeSnapshot.error!);
        }
        return RefreshIndicator(
          onRefresh: () => ChallengeScoreService.instance.recomputeAndUpload(
            manual: true,
            onlyChallengeId: challenge.id,
          ),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              DashboardCard(
                surfaceGradient: _tintGradient(
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(challenge.metric.icon, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            challenge.name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(challenge.metric.label),
                    const SizedBox(height: 4),
                    Text(
                      '${_shortDate(challenge.startDate)} – '
                      '${_shortDate(challenge.endDate.subtract(const Duration(days: 1)))}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      challenge.hasEnded
                          ? 'Challenge finished'
                          : '${challenge.endDate.toLocal().difference(DateTime.now()).inDays.clamp(0, 60)} days left',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      challenge.hasEnded ? 'Final results' : 'Leaderboard',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (challenge.hasEnded)
                    const Chip(label: Text('Challenge finished')),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<ChallengeScoreEntry>>(
                stream: widget.service.watchScores(challenge.id),
                builder: (context, scoreSnapshot) {
                  if (scoreSnapshot.hasError) {
                    return _detailError(context, scoreSnapshot.error!);
                  }
                  if (scoreSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !scoreSnapshot.hasData) {
                    return const _ChallengeSkeleton();
                  }
                  final entries =
                      scoreSnapshot.data ?? const <ChallengeScoreEntry>[];
                  if (entries.isEmpty) {
                    return const _InlineEmpty('Scores will appear here.');
                  }
                  final winner = entries.first;
                  return Column(
                    children: [
                      if (challenge.hasEnded)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DashboardCard(
                            child: Text(
                              '🏆 ${winner.username} finished first with '
                              '${_formatScore(winner.score)} '
                              '${challenge.metric.unit}.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      for (final entry in entries)
                        _leaderboardRow(
                          context,
                          challenge,
                          entry,
                          winner.score,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _leaderboardRow(
    BuildContext context,
    FitnessChallenge challenge,
    ChallengeScoreEntry entry,
    double leaderScore,
  ) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final isMe = entry.uid == widget.currentUid;
    final highlight = switch (entry.rank) {
      1 => const Color(0xFFFFD166),
      2 => const Color(0xFFBCC7D0),
      3 => const Color(0xFFCD8B55),
      _ => tokens.accentTeal,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DashboardCard(
        surfaceGradient: isMe
            ? _tintGradient(tokens.accentTeal.withValues(alpha: 0.10))
            : null,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${entry.rank}',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: highlight, fontWeight: FontWeight.w900),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: tokens.surfaceVariant,
              child: Text(
                entry.username.isEmpty
                    ? '?'
                    : entry.username.characters.first.toUpperCase(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${entry.username} · You' : entry.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: isMe ? FontWeight.w800 : null),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: leaderScore > 0
                          ? (entry.score / leaderScore).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 6,
                      backgroundColor: tokens.surfaceVariant,
                      color: highlight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${_formatScore(entry.score)} ${challenge.metric.unit}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(String action) async {
    final challenge = widget.challenge;
    switch (action) {
      case 'invite':
        await _inviteMore(challenge);
      case 'leave':
        if (await _confirm(
          'Leave challenge?',
          'Your score will be removed from the leaderboard.',
        )) {
          await _runDetailAction(widget.service.leaveChallenge(challenge));
          if (mounted) Navigator.of(context).pop();
        }
      case 'end':
        if (await _confirm(
          'End challenge?',
          'This will freeze the current scores.',
        )) {
          await _runDetailAction(widget.service.endChallenge(challenge));
        }
      case 'delete':
        if (await _confirm(
          'Delete challenge?',
          'This removes the challenge for every participant.',
        )) {
          await _runDetailAction(widget.service.deleteChallenge(challenge));
          if (mounted) Navigator.of(context).pop();
        }
    }
  }

  Future<void> _inviteMore(FitnessChallenge challenge) async {
    final friends = await widget.friendsStream.first;
    if (!mounted) return;
    final invitees = await showModalBottomSheet<List<FriendSummary>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FriendPickerSheet(
        friends: friends
            .where((friend) => !challenge.memberUids.contains(friend.uid))
            .toList(),
      ),
    );
    if (invitees == null || invitees.isEmpty) return;
    await _runDetailAction(widget.service.inviteMore(challenge, invitees));
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _runDetailAction(Future<void> action) async {
    try {
      await action;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Challenge action failed (${error.code}): ${error.message}\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_firebaseMessage(error))));
      }
    } catch (error, stackTrace) {
      debugPrint('Challenge action failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kDebugMode ? '$error' : 'Could not update challenge.',
            ),
          ),
        );
      }
    }
  }

  Widget _detailError(BuildContext context, Object error) {
    final code = error is FirebaseException ? error.code : 'unknown';
    final message = code == 'unavailable'
        ? 'Challenge data is unavailable offline.'
        : kDebugMode
        ? 'Could not load challenge data ($code): $error'
        : 'Could not load challenge data. Please try again.';
    debugPrint('Challenge detail stream failed ($code): $error');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class _FriendPickerSheet extends StatefulWidget {
  const _FriendPickerSheet({required this.friends});
  final List<FriendSummary> friends;

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Invite friends', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (widget.friends.isEmpty)
            const _InlineEmpty(
              'All your friends are already in this challenge.',
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final friend in widget.friends)
                    CheckboxListTile(
                      value: _selected.contains(friend.uid),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selected.add(friend.uid);
                        } else {
                          _selected.remove(friend.uid);
                        }
                      }),
                      title: Text(friend.displayName),
                      subtitle: Text('@${friend.username}'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              widget.friends
                  .where((friend) => _selected.contains(friend.uid))
                  .toList(),
            ),
            child: const Text('Send invites'),
          ),
        ],
      ),
    ),
  );
}

class _RedBadge extends StatelessWidget {
  const _RedBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFE64A53),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ChallengeSkeleton extends StatelessWidget {
  const _ChallengeSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      children: [
        for (var index = 0; index < 2; index++)
          Container(
            height: 94,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceVariant,
              borderRadius: BorderRadius.circular(tokens.cardRadius),
            ),
          ),
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).hintColor),
    ),
  );
}

String _firebaseMessage(FirebaseException error) {
  if (error.code == 'unavailable') {
    return 'Challenges are unavailable offline. Your local data is safe.';
  }
  return kDebugMode
      ? 'Challenge operation failed (${error.code}): ${error.message ?? 'No details'}'
      : 'Could not update the challenge. Please try again.';
}

String _formatScore(double score) => score == score.roundToDouble()
    ? score.round().toString()
    : score.toStringAsFixed(1);

String _ordinal(int rank) {
  if (rank % 100 >= 11 && rank % 100 <= 13) return '${rank}th';
  return switch (rank % 10) {
    1 => '${rank}st',
    2 => '${rank}nd',
    3 => '${rank}rd',
    _ => '${rank}th',
  };
}

String _shortDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

LinearGradient _tintGradient(Color color) =>
    LinearGradient(colors: [color, color]);
