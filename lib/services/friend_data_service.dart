import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SharedCategoryData {
  const SharedCategoryData({
    required this.shared,
    required this.days,
    this.errorCode,
    this.errorMessage,
  });

  final bool shared;
  final Map<DateTime, Map<String, dynamic>> days;
  final String? errorCode;
  final String? errorMessage;

  Map<String, dynamic>? dataFor(DateTime day) =>
      days[DateTime(day.year, day.month, day.day)];
}

class FriendSharedData {
  const FriendSharedData({
    required this.workouts,
    required this.food,
    required this.health,
    required this.body,
    required this.lastSynced,
  });

  final SharedCategoryData workouts;
  final SharedCategoryData food;
  final SharedCategoryData health;
  final SharedCategoryData body;
  final DateTime? lastSynced;

  SharedCategoryData category(String name) => switch (name) {
    'workouts' => workouts,
    'food' => food,
    'health' => health,
    'body' => body,
    _ => throw ArgumentError.value(name, 'name', 'Unknown shared category'),
  };

  bool get hasNetworkError => [
    workouts,
    food,
    health,
    body,
  ].any((value) => value.errorCode == 'unavailable');
}

class FriendDataLoadException implements Exception {
  const FriendDataLoadException(this.code, this.message, this.stackTrace);

  final String code;
  final String? message;
  final StackTrace stackTrace;

  @override
  String toString() => 'Friend data load failed ($code): $message';
}

class FriendDataService {
  FriendDataService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const categories = ['workouts', 'food', 'health', 'body'];
  final FirebaseFirestore _firestore;

  Future<FriendSharedData> fetchForFriend(String friendUid) async {
    final sharingDoc = await _getSharingSettings(friendUid);
    final flags = sharingDoc?.data() ?? const <String, dynamic>{};
    final results = await Future.wait(
      categories.map(
        (category) =>
            _fetchCategory(friendUid, category, flags[category] == true),
      ),
    );

    DateTime? lastSynced;
    for (final category in results) {
      for (final dayData in category.days.values) {
        final timestamp = dayData['updatedAt'];
        final date = timestamp is Timestamp ? timestamp.toDate() : null;
        if (date != null && (lastSynced == null || date.isAfter(lastSynced))) {
          lastSynced = date;
        }
      }
    }

    return FriendSharedData(
      workouts: results[0],
      food: results[1],
      health: results[2],
      body: results[3],
      lastSynced: lastSynced,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getSharingSettings(
    String friendUid,
  ) async {
    try {
      return await _firestore.collection('sharing').doc(friendUid).get();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Friend sharing settings load failed: '
        '${error.code}: ${error.message}\n$stackTrace',
      );
      throw FriendDataLoadException(error.code, error.message, stackTrace);
    }
  }

  Future<SharedCategoryData> _fetchCategory(
    String friendUid,
    String category,
    bool enabled,
  ) async {
    if (!enabled) {
      return const SharedCategoryData(shared: false, days: {});
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
    final days = <DateTime, Map<String, dynamic>>{};
    try {
      final snapshots = await Future.wait(
        dates.map(
          (date) => _firestore
              .collection('userData')
              .doc(friendUid)
              .collection(category)
              .doc(_dayId(date))
              .get(),
        ),
      );
      for (var index = 0; index < snapshots.length; index++) {
        final snapshot = snapshots[index];
        if (snapshot.exists) days[dates[index]] = snapshot.data()!;
      }
      return SharedCategoryData(shared: true, days: days);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Friend $category data load failed: '
        '${error.code}: ${error.message}\n$stackTrace',
      );
      if (error.code == 'permission-denied') {
        return const SharedCategoryData(shared: false, days: {});
      }
      return SharedCategoryData(
        shared: true,
        days: days,
        errorCode: error.code,
        errorMessage: error.message,
      );
    } catch (error, stackTrace) {
      debugPrint('Friend $category data load failed: $error\n$stackTrace');
      return SharedCategoryData(
        shared: true,
        days: days,
        errorCode: 'unknown',
        errorMessage: error.toString(),
      );
    }
  }

  static String dayId(DateTime day) => _dayId(day);

  static String _dayId(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
