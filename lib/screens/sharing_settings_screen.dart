import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/share_sync_service.dart';

class SharingSettingsScreen extends StatefulWidget {
  const SharingSettingsScreen({super.key});

  @override
  State<SharingSettingsScreen> createState() => _SharingSettingsScreenState();
}

class _SharingSettingsScreenState extends State<SharingSettingsScreen> {
  final ShareSyncService _syncService = ShareSyncService.instance;
  Timer? _lastSyncedTimer;
  bool _busy = false;

  static const _sharingDetails = <String, ({String title, String details})>{
    'workouts': (
      title: 'Share workouts?',
      details:
          'Friends can see each workout’s name, strength-training label, '
          'duration, total volume and reps, targeted muscles, exercise names, '
          'and each set’s reps and weight.',
    ),
    'food': (
      title: 'Share food logs?',
      details:
          'Friends can see daily calorie, protein, carbohydrate and fat totals, '
          'your saved nutrition goals, and each logged food’s name and calories.',
    ),
    'health': (
      title: 'Share Health data?',
      details:
          'Friends can see daily steps, active calories, sleep hours, resting '
          'and average heart rate, and watch workouts with sport, duration and '
          'calories. This includes data read from HealthKit or Health Connect.',
    ),
    'body': (
      title: 'Share body log?',
      details:
          'Friends can see your logged body weight and measurements for each '
          'day you recorded them.',
    ),
  };

  @override
  void initState() {
    super.initState();
    _lastSyncedTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _lastSyncedTimer?.cancel();
    super.dispose();
  }

  Future<bool> _confirmEnable(String category) async {
    final info = _sharingDetails[category]!;
    final explicitConfirm = category == 'health' || category == 'body';
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(info.title),
            content: Text(info.details),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(explicitConfirm ? 'I understand' : 'Share'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _setCategory(String category, bool enabled) async {
    final settings = Hive.box<dynamic>('settings');
    if (enabled && settings.get('sharingConfirmed_$category') != true) {
      if (!await _confirmEnable(category) || !mounted) return;
      await settings.put('sharingConfirmed_$category', true);
    }
    if (mounted) setState(() => _busy = true);
    try {
      await _syncService.setCategory(category, enabled);
    } catch (error, stackTrace) {
      debugPrint('Sharing preference update failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this sharing setting.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    unawaited(_syncService.sync(manual: true));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sync started. Firestore will queue updates while offline.',
        ),
      ),
    );
  }

  Future<void> _stopSharing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop sharing and delete my shared data?'),
        content: const Text(
          'This turns off all sharing and deletes your uploaded workout, food, '
          'health, and body-log data from Forge. Your local Hive data will not '
          'be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Stop sharing and delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await _syncService.stopSharingAndDelete();
    if (mounted) setState(() => _busy = false);
  }

  String _lastSyncedText(Object? value) {
    final date = switch (value) {
      DateTime dateTime => dateTime,
      _ => null,
    };
    if (date == null) return 'Not synced yet';
    final age = DateTime.now().difference(date);
    if (age.isNegative || age.inSeconds < 60) return 'Last synced just now';
    if (age.inMinutes < 60) {
      return 'Last synced ${age.inMinutes} '
          '${age.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (age.inHours < 24) {
      return 'Last synced ${age.inHours} ${age.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    return 'Last synced ${age.inDays} ${age.inDays == 1 ? 'day' : 'days'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Hive.box<dynamic>('settings');
    return Scaffold(
      appBar: AppBar(title: const Text('Sharing')),
      body: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: settings.listenable(),
        builder: (context, box, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Choose what friends can see. Sharing is off until you turn on a category.',
            ),
            const SizedBox(height: 12),
            for (final category in ShareSyncService.categories)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_label(category)),
                value:
                    box.get(ShareSyncService.localSettingKey(category)) == true,
                onChanged: _busy
                    ? null
                    : (enabled) => unawaited(_setCategory(category, enabled)),
              ),
            const Divider(height: 28),
            Text(
              _lastSyncedText(box.get('sharingLastSyncedAt')),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _syncNow,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              label: const Text('Sync now'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _stopSharing,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Stop sharing and delete my shared data'),
            ),
            const SizedBox(height: 8),
            Text(
              'Only the most recent 7 days are shared. Your local data remains '
              'available on this device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _label(String category) => switch (category) {
    'workouts' => 'Workouts',
    'food' => 'Food',
    'health' => 'Health (HealthKit / Health Connect)',
    'body' => 'Body log (weight and measurements)',
    _ => category,
  };
}
