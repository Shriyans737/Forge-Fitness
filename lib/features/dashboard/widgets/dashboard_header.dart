import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../theme.dart';
import '../../../widgets/ui/health_sync_button.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.date,
    required this.streak,
    required this.displayName,
    required this.isSyncing,
    required this.onSync,
    required this.onSettings,
    this.onFriends,
    this.incomingRequestCount = 0,
    this.reduceMotion = false,
    super.key,
  });

  final DateTime date;
  final int streak;
  final String displayName;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onSettings;
  final VoidCallback? onFriends;
  final int incomingRequestCount;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final greeting = switch (date.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    final dateText =
        '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}';
    final name = displayName.trim().isEmpty ? 'there' : displayName.trim();
    final shortName = name.length > 20
        ? '${name.substring(0, 19)}…'
        : name;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: reduceMotion
                      ? Duration.zero
                      : ForgeMotion.cardEntry,
                  curve: ForgeMotion.easeOut,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * ForgeMotion.entryOffset),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hey $shortName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(height: 1.05, letterSpacing: -0.64),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$greeting · $dateText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: ForgeSpacing.xs),
              if (onFriends != null) ...[
                _FriendsButton(
                  count: incomingRequestCount,
                  onPressed: onFriends!,
                ),
                const SizedBox(width: ForgeSpacing.xxs),
              ],
              HealthSyncButton(isSyncing: isSyncing, onPressed: onSync),
              const SizedBox(width: ForgeSpacing.xxs),
              IconButton(
                tooltip: 'Settings',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 38,
                ),
                padding: EdgeInsets.zero,
                onPressed: onSettings,
                icon: const Icon(Icons.settings_rounded, size: 22),
              ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.xs),
          _StreakChip(
            streak: streak,
            reduceMotion: reduceMotion,
            tokens: tokens,
          ),
        ],
      ),
    );
  }

  static String _weekday(int value) => const [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][value];

  static String _month(int value) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][value];
}

class _FriendsButton extends StatelessWidget {
  const _FriendsButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Friends',
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 38, height: 38),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.people_alt_rounded, size: 21),
        if (count > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE64A53),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _StreakChip extends StatefulWidget {
  const _StreakChip({
    required this.streak,
    required this.reduceMotion,
    required this.tokens,
  });

  final int streak;
  final bool reduceMotion;
  final ForgeTokens tokens;

  @override
  State<_StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<_StreakChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: ForgeMotion.streakFlicker,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _flicker.repeat();
  }

  @override
  void didUpdateWidget(covariant _StreakChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      if (widget.reduceMotion) {
        _flicker.stop();
        _flicker.value = 0;
      } else {
        _flicker.repeat();
      }
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.tokens.surface,
        border: Border.all(color: widget.tokens.border),
        borderRadius: BorderRadius.circular(widget.tokens.pillRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ForgeSpacing.sm,
          vertical: ForgeSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _flicker,
              builder: (context, child) {
                final value = widget.reduceMotion ? 0.0 : _flicker.value;
                final angle = value < 0.3
                    ? -4 * (value / 0.3)
                    : value < 0.6
                    ? -4 + 7 * ((value - 0.3) / 0.3)
                    : 3 * (1 - (value - 0.6) / 0.4);
                final scaleY = value < 0.3
                    ? 1 + 0.18 * (value / 0.3)
                    : value < 0.6
                    ? 1.18 - 0.13 * ((value - 0.3) / 0.3)
                    : 1.05 - 0.05 * ((value - 0.6) / 0.4);
                return Transform.rotate(
                  angle: angle * math.pi / 180,
                  child: Transform.scale(
                    scaleX: widget.reduceMotion ? 1 : 0.96 + value * 0.04,
                    scaleY: scaleY,
                    child: child,
                  ),
                );
              },
              child: Icon(
                Icons.local_fire_department_rounded,
                color: const Color(0xFFF2A04E),
                size: 18,
              ),
            ),
            const SizedBox(width: ForgeSpacing.xxs),
            Text(
              '${widget.streak} day${widget.streak == 1 ? '' : 's'} streak',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 14,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
