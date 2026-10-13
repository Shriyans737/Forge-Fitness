import 'package:flutter/material.dart';

import '../../../services/health_service.dart';
import '../../../theme.dart';
import '../../../widgets/ui/shimmer_box.dart';
import 'dashboard_card.dart';

class DashboardHealthCard extends StatelessWidget {
  const DashboardHealthCard({
    required this.summary,
    required this.isLoading,
    required this.error,
    required this.hasPermissions,
    required this.lastSyncedAt,
    required this.onOpenHealth,
    super.key,
  });

  final HealthSummary? summary;
  final bool isLoading;
  final String? error;
  final bool hasPermissions;
  final DateTime? lastSyncedAt;
  final VoidCallback onOpenHealth;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return DashboardCard(
      onTap: onOpenHealth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('HEALTH', style: Theme.of(context).textTheme.labelLarge),
              ),
              Icon(Icons.favorite_rounded, color: tokens.error, size: 19),
            ],
          ),
          const SizedBox(height: ForgeSpacing.sm),
          if (isLoading && summary == null)
            Row(
              children: const [
                Expanded(child: ShimmerBox(width: double.infinity, height: 64)),
                SizedBox(width: ForgeSpacing.sm),
                Expanded(child: ShimmerBox(width: double.infinity, height: 64)),
                SizedBox(width: ForgeSpacing.sm),
                Expanded(child: ShimmerBox(width: double.infinity, height: 64)),
              ],
            )
          else if (!hasPermissions)
            Text(
              error ?? 'Connect Apple Health or Health Connect to see your daily stats.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
            )
          else if (summary?.hasAnyData != true) ...[
            Text(
              'No data found. Check Settings > Privacy > Health > Forge, or make sure your Watch/iPhone is actually recording.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: ForgeSpacing.xs),
            TextButton(
              onPressed: onOpenHealth,
              child: const Text('Open Health tab'),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _HealthMetric(
                    label: 'ACTIVE KCAL',
                    value: _number(summary?.activeCaloriesBurned, suffix: ''),
                    icon: Icons.local_fire_department_outlined,
                  ),
                ),
                Expanded(
                  child: _HealthMetric(
                    label: 'HEART RATE',
                    value: _number(summary?.latestHeartRate, suffix: ' bpm'),
                    icon: Icons.favorite_border_rounded,
                  ),
                ),
                Expanded(
                  child: _HealthMetric(
                    label: 'SLEEP',
                    value: _sleep(summary?.sleepAsleepMinutes),
                    icon: Icons.nightlight_outlined,
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: ForgeSpacing.xs),
              Text(
                error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.warning,
                    ),
              ),
            ],
          ],
          const SizedBox(height: ForgeSpacing.sm),
          if (lastSyncedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: ForgeSpacing.xs),
              child: Text(
                'Last synced: ${_relativeTime(lastSyncedAt!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ),
          Text(
            hasPermissions ? 'Open Health overview' : 'Set up health data',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.accentTeal,
                ),
          ),
        ],
      ),
    );
  }

  static String _number(double? value, {required String suffix}) =>
      value == null ? '—' : '${value.round()}$suffix';

  static String _sleep(double? minutes) {
    if (minutes == null) return '—';
    final hours = minutes ~/ 60;
    final remainder = (minutes % 60).round();
    return '${hours}h ${remainder}m';
  }

  static String _relativeTime(DateTime timestamp) {
    final elapsed = DateTime.now().difference(timestamp);
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24) {
      final hours = elapsed.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    final days = elapsed.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }
}

class _HealthMetric extends StatelessWidget {
  const _HealthMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tokens.accentTeal, size: 18),
        const SizedBox(height: ForgeSpacing.xxs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.textMuted,
              ),
        ),
        const SizedBox(height: ForgeSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}
