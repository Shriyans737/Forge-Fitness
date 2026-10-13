import 'package:flutter/material.dart';

import '../../../services/friend_data_service.dart';
import '../../../services/friends_dashboard_controller.dart';
import '../../../services/friends_service.dart';
import '../../../theme.dart';
import 'dashboard_card.dart';

class DashboardFriendsCard extends StatelessWidget {
  const DashboardFriendsCard({
    required this.controller,
    required this.onSeeAll,
    required this.onOpenFriend,
    super.key,
  });

  final FriendsDashboardController controller;
  final VoidCallback onSeeAll;
  final ValueChanged<FriendSummary> onOpenFriend;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final friends = controller.friends;
    if (friends.isEmpty) {
      return DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, tokens),
            const SizedBox(height: ForgeSpacing.sm),
            Text(
              'Your Forge crew starts here.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ForgeSpacing.xxs),
            Text(
              'Add friends to see the progress they choose to share.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: ForgeSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSeeAll,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add friends'),
              ),
            ),
          ],
        ),
      );
    }

    final visibleFriends = friends.take(5).toList(growable: false);
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, tokens),
          const SizedBox(height: ForgeSpacing.sm),
          SizedBox(
            height: 38,
            child: Row(
              children: [
                for (var index = 0; index < visibleFriends.length; index++)
                  Align(
                    widthFactor: 0.82,
                    child: _avatar(
                      context,
                      visibleFriends[index],
                      index,
                      tokens,
                    ),
                  ),
                if (friends.length > visibleFriends.length)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _moreChip(
                      context,
                      friends.length - visibleFriends.length,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ForgeSpacing.xs),
          for (final friend in visibleFriends) ...[
            _FriendProgressRow(
              friend: friend,
              data: controller.dataFor(friend.uid),
              onTap: () => onOpenFriend(friend),
            ),
            if (friend != visibleFriends.last)
              Divider(height: ForgeSpacing.md, color: tokens.border),
          ],
          const SizedBox(height: ForgeSpacing.xxs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onSeeAll,
              child: const Text('See all'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ForgeTokens tokens) => Row(
    children: [
      Expanded(
        child: Text('FRIENDS', style: Theme.of(context).textTheme.labelLarge),
      ),
      Icon(Icons.people_alt_rounded, color: tokens.accentTeal, size: 19),
    ],
  );

  Widget _avatar(
    BuildContext context,
    FriendSummary friend,
    int index,
    ForgeTokens tokens,
  ) => Tooltip(
    message: friend.displayName,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () => onOpenFriend(friend),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: index.isEven ? tokens.surfaceVariant : tokens.surface,
        foregroundColor: tokens.accentTeal,
        child: Text(
          friend.displayName.isEmpty
              ? '?'
              : friend.displayName.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    ),
  );

  Widget _moreChip(BuildContext context, int count) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.pillRadius),
      ),
      child: Text('+$count', style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _FriendProgressRow extends StatelessWidget {
  const _FriendProgressRow({
    required this.friend,
    required this.data,
    required this.onTap,
  });

  final FriendSummary friend;
  final Future<FriendSharedData>? data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.controlRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ForgeSpacing.xxs),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                friend.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: ForgeSpacing.xs),
            Expanded(
              flex: 3,
              child: data == null
                  ? _metricStates(context, tokens, null)
                  : FutureBuilder<FriendSharedData>(
                      future: data,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done ||
                            snapshot.data == null) {
                          if (snapshot.hasError) {
                            return _metricStates(
                              context,
                              tokens,
                              null,
                              unavailable: true,
                            );
                          }
                          return _metricStates(context, tokens, null);
                        }
                        return _metricStates(context, tokens, snapshot.data);
                      },
                    ),
            ),
            Icon(Icons.chevron_right_rounded, color: tokens.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _metricStates(
    BuildContext context,
    ForgeTokens tokens,
    FriendSharedData? sharedData, {
    bool unavailable = false,
  }) {
    final today = DateTime.now();
    final key = DateTime(today.year, today.month, today.day);
    String value(String categoryName, String field, String suffix) {
      if (unavailable) return 'Unavailable';
      if (sharedData == null) return 'Loading';
      final category = sharedData.category(categoryName);
      if (!category.shared) return 'Private';
      if (category.errorCode != null) return 'Unavailable';
      final day = category.dataFor(key);
      if (day == null) return 'No data';
      final totals = day['dailyTotals'];
      final raw = categoryName == 'workouts' && totals is Map
          ? totals[field]
          : day[field];
      if (raw is! num) return 'No data';
      final number = raw.toDouble();
      final formatted = number == number.roundToDouble()
          ? number.round().toString()
          : number.toStringAsFixed(1);
      return '$formatted$suffix';
    }

    return Wrap(
      spacing: 5,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        _metricPill(context, tokens, 'kcal', value('food', 'calories', '')),
        _metricPill(context, tokens, 'steps', value('health', 'steps', '')),
        _metricPill(
          context,
          tokens,
          'vol',
          value('workouts', 'totalVolume', ''),
        ),
      ],
    );
  }

  Widget _metricPill(
    BuildContext context,
    ForgeTokens tokens,
    String label,
    String value,
  ) {
    final isPrivate = value == 'Private';
    final isEmpty = value == 'No data';
    final isUnavailable = value == 'Unavailable';
    final isLoading = value == 'Loading';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrivate)
            Icon(Icons.lock_outline_rounded, size: 10, color: tokens.textMuted),
          Text(
            isPrivate ? '$label · Private' : '$label · $value',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isEmpty || isUnavailable || isLoading
                  ? tokens.textMuted
                  : null,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
