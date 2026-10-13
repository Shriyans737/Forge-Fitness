import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../coach_copy.dart';
import 'coach_engine.dart';
import 'coach_repository.dart';

enum CoachNudgeType {
  eveningProtein,
  missedWorkout,
  bedtimeWindDown,
  weeklyReview,
  streakAtRisk,
}

class CoachNudgeService {
  CoachNudgeService._();

  static final CoachNudgeService instance = CoachNudgeService._();
  static final ValueNotifier<String?> routeRequests = ValueNotifier(null);
  static const _ids = <CoachNudgeType, int>{
    CoachNudgeType.eveningProtein: 8401,
    CoachNudgeType.missedWorkout: 8402,
    CoachNudgeType.bedtimeWindDown: 8403,
    CoachNudgeType.weeklyReview: 8404,
    CoachNudgeType.streakAtRisk: 8405,
  };

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _lastScheduleSignature;

  Future<bool> requestPermission() async {
    await _initialize();
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> rescheduleIfChanged(
    CoachContext context,
    CoachRepository repository,
  ) async {
    final settings = Hive.box<dynamic>('settings');
    if (settings.get('coachNudgesEnabled') != true) {
      if (_initialized) await _cancelAll();
      _lastScheduleSignature = null;
      return;
    }
    if (!await Permission.notification.isGranted) {
      if (_initialized) await _cancelAll();
      _lastScheduleSignature = null;
      return;
    }
    final signature = _signature(context, settings, repository);
    if (signature == _lastScheduleSignature) return;
    _lastScheduleSignature = signature;
    await _initialize();
    final now = context.now;
    final history = _dailyHistory(settings, now);
    final alreadyScheduled = history.toSet();
    final available = _candidates(context);
    final eligibleTypes = <CoachNudgeType>{
      for (final item in available)
        if (settings.get('coachNudge${item.type.name}') != false) item.type,
    };
    for (final entry in _ids.entries) {
      if (!eligibleTypes.contains(entry.key)) {
        await _plugin.cancel(id: entry.value);
      }
    }
    var scheduledToday = alreadyScheduled.length;
    for (final candidate in available) {
      if (settings.get('coachNudge${candidate.type.name}') == false) {
        await _plugin.cancel(id: _ids[candidate.type]!);
        continue;
      }
      final shownAt = repository.shownTimestamps()[candidate.insightId];
      if (shownAt != null && _sameDay(shownAt, now)) {
        await _plugin.cancel(id: _ids[candidate.type]!);
        continue;
      }
      if (repository.wasDismissed(candidate.insightId, now)) {
        await _plugin.cancel(id: _ids[candidate.type]!);
        continue;
      }
      final alreadyCounted = alreadyScheduled.contains(candidate.type.name);
      if (!alreadyCounted && scheduledToday >= 2) continue;
      final scheduledAt = _outsideQuietHours(
        _nextTime(now, candidate.hour, candidate.minute),
        settings,
      );
      if (!_sameDay(scheduledAt, now)) {
        await _plugin.cancel(id: _ids[candidate.type]!);
        continue;
      }
      await _plugin.zonedSchedule(
        id: _ids[candidate.type]!,
        title: CoachCopy.coachBrand,
        body: candidate.body,
        scheduledDate: timezone.TZDateTime.from(scheduledAt, timezone.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            CoachCopy.notificationChannel,
            CoachCopy.notificationChannelName,
            channelDescription: CoachCopy.notificationChannelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: candidate.route,
      );
      if (!alreadyCounted) {
        history.add(candidate.type.name);
        alreadyScheduled.add(candidate.type.name);
        scheduledToday++;
      }
    }
    await settings.put(_historyKey(now), history);
  }

  Future<void> cancelAll() async {
    _lastScheduleSignature = null;
    if (_initialized) await _cancelAll();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    final currentTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(currentTimezone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: IOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) routeRequests.value = payload;
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true && payload != null) {
      routeRequests.value = payload;
    }
    _initialized = true;
  }

  Future<void> _cancelAll() async {
    for (final id in _ids.values) {
      await _plugin.cancel(id: id);
    }
  }

  List<_NudgeCandidate> _candidates(CoachContext context) {
    final insights = const CoachEngine().generate(context);
    final proteinGap = insights
        .where((item) => item.id == 'protein-gap' || item.id == 'calorie-gap')
        .firstOrNull;
    final lastWorkout = context.workouts
        .map((item) => item.date)
        .fold<DateTime?>(null, (latest, date) {
          if (latest == null || date.isAfter(latest)) return date;
          return latest;
        });
    final sleepDebt = insights
        .where((item) => item.id == 'sleep-debt')
        .firstOrNull;
    final bedtimeMinutes =
        ((context.bedtimeMinutes ?? 22 * 60) - 60 + 1440) % 1440;
    final workedToday = context.workouts.any(
      (item) => _sameDay(item.date, context.now),
    );
    final result = <_NudgeCandidate>[];
    if (proteinGap != null && context.now.hour >= 17) {
      result.add(
        _NudgeCandidate(
          type: CoachNudgeType.eveningProtein,
          insightId: proteinGap.id,
          body: proteinGap.body,
          hour: 19,
          minute: 0,
          route: CoachCopy.tabCoachScreen,
        ),
      );
    }
    if (lastWorkout != null &&
        context.now.difference(lastWorkout) >= const Duration(days: 3)) {
      result.add(
        _NudgeCandidate(
          type: CoachNudgeType.missedWorkout,
          insightId: 'missed-workout',
          body: CoachCopy.missedWorkoutNudge,
          hour: 17,
          minute: 30,
          route: CoachCopy.tabCoachScreen,
        ),
      );
    }
    if (sleepDebt != null) {
      result.add(
        _NudgeCandidate(
          type: CoachNudgeType.bedtimeWindDown,
          insightId: 'sleep-debt',
          body: CoachCopy.windDownNudge,
          hour: bedtimeMinutes ~/ 60,
          minute: bedtimeMinutes % 60,
          route: CoachCopy.tabCoachScreen,
        ),
      );
    }
    if (context.now.weekday == DateTime.sunday) {
      result.add(
        const _NudgeCandidate(
          type: CoachNudgeType.weeklyReview,
          insightId: 'weekly-review',
          body: CoachCopy.weeklyReviewNudge,
          hour: 18,
          minute: 0,
          route: CoachCopy.weeklyReviewRoute,
        ),
      );
    }
    if (context.trainingStreakDays > 0 && !workedToday) {
      result.add(
        const _NudgeCandidate(
          type: CoachNudgeType.streakAtRisk,
          insightId: 'streak-risk',
          body: CoachCopy.streakRiskNudge,
          hour: 19,
          minute: 30,
          route: CoachCopy.tabCoachScreen,
        ),
      );
    }
    return result;
  }

  static List<String> _dailyHistory(Box<dynamic> settings, DateTime now) {
    final value = settings.get(_historyKey(now));
    return value is List
        ? value.whereType<String>().toList(growable: true)
        : <String>[];
  }

  static String _historyKey(DateTime date) =>
      '${CoachCopy.notificationHistoryPrefix}:${date.year}-${date.month}-${date.day}';

  static DateTime _nextTime(DateTime now, int hour, int minute) {
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static DateTime _outsideQuietHours(DateTime time, Box<dynamic> settings) {
    final start = _settingInt(settings, 'coachQuietStartMinutes', 22 * 60);
    final end = _settingInt(settings, 'coachQuietEndMinutes', 8 * 60);
    final minute = time.hour * 60 + time.minute;
    final isQuiet = start > end
        ? minute >= start || minute < end
        : minute >= start && minute < end;
    if (!isQuiet) return time;
    final endDate = DateTime(
      time.year,
      time.month,
      time.day,
      end ~/ 60,
      end % 60,
    );
    return minute >= start ? endDate.add(const Duration(days: 1)) : endDate;
  }

  static int _settingInt(Box<dynamic> settings, String key, int fallback) {
    final value = settings.get(key);
    return value is num ? value.toInt().clamp(0, 1439) : fallback;
  }

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  String _signature(
    CoachContext context,
    Box<dynamic> settings,
    CoachRepository repository,
  ) {
    final candidates = _candidates(context).map(
      (item) =>
          '${item.type.name}:${item.insightId}:${item.hour}:${item.minute}:'
          '${item.body}:${repository.shownTimestamps()[item.insightId]}:'
          '${repository.wasDismissed(item.insightId, context.now)}',
    );
    final toggles = CoachNudgeType.values.map(
      (type) => '${type.name}:${settings.get('coachNudge${type.name}') != false}',
    );
    return [
      '${context.now.year}-${context.now.month}-${context.now.day}',
      ...candidates,
      ...toggles,
      'quiet:${settings.get('coachQuietStartMinutes')}:'
          '${settings.get('coachQuietEndMinutes')}',
    ].join('|');
  }
}

class _NudgeCandidate {
  const _NudgeCandidate({
    required this.type,
    required this.insightId,
    required this.body,
    required this.hour,
    required this.minute,
    required this.route,
  });

  final CoachNudgeType type;
  final String insightId;
  final String body;
  final int hour;
  final int minute;
  final String route;
}
