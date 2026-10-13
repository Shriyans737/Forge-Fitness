import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'friends_service.dart';

enum ChallengeMetric {
  workouts,
  volume,
  steps,
  activeDays;

  String get firestoreValue => switch (this) {
    workouts => 'workouts',
    volume => 'volume',
    steps => 'steps',
    activeDays => 'activeDays',
  };

  String get label => switch (this) {
    workouts => 'Workouts completed',
    volume => 'Total workout volume',
    steps => 'Steps',
    activeDays => 'Active days',
  };

  String get unit => switch (this) {
    workouts => 'workouts',
    volume => 'kg',
    steps => 'steps',
    activeDays => 'days',
  };

  IconData get icon => switch (this) {
    workouts => Icons.fitness_center_rounded,
    volume => Icons.monitor_weight_outlined,
    steps => Icons.directions_walk_rounded,
    activeDays => Icons.local_fire_department_rounded,
  };

  static ChallengeMetric? parse(Object? value) {
    for (final metric in values) {
      if (metric.firestoreValue == value) return metric;
    }
    return null;
  }
}

class FitnessChallenge {
  const FitnessChallenge({
    required this.id,
    required this.name,
    required this.metric,
    required this.startDate,
    required this.endDate,
    required this.creatorUid,
    required this.memberUids,
    required this.memberNames,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String name;
  final ChallengeMetric metric;
  final DateTime startDate;
  final DateTime endDate;
  final String creatorUid;
  final List<String> memberUids;
  final Map<String, String> memberNames;
  final String status;
  final DateTime? createdAt;

  bool get hasEnded =>
      status == 'ended' || !DateTime.now().isBefore(endDate.toLocal());

  bool isActiveAt(DateTime now) =>
      status == 'active' &&
      !now.isBefore(startDate.toLocal()) &&
      now.isBefore(endDate.toLocal());

  factory FitnessChallenge.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) throw StateError('Challenge ${snapshot.id} has no data.');
    final metric = ChallengeMetric.parse(data['metric']);
    if (metric == null) {
      throw FormatException('Unknown challenge metric: ${data['metric']}');
    }
    return FitnessChallenge(
      id: snapshot.id,
      name: data['name'] as String? ?? 'Challenge',
      metric: metric,
      startDate: _date(data['startDate'], 'startDate'),
      endDate: _date(data['endDate'], 'endDate'),
      creatorUid: data['creatorUid'] as String? ?? '',
      memberUids: (data['memberUids'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      memberNames: {
        for (final entry in (data['memberNames'] as Map? ?? const {}).entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      },
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static DateTime _date(Object? value, String field) {
    if (value is Timestamp) return value.toDate();
    throw FormatException('Challenge $field must be a Firestore timestamp.');
  }
}

class ChallengeInvite {
  const ChallengeInvite({
    required this.id,
    required this.challengeId,
    required this.challengeName,
    required this.fromUid,
    required this.fromUsername,
    required this.toUid,
    this.createdAt,
  });

  final String id;
  final String challengeId;
  final String challengeName;
  final String fromUid;
  final String fromUsername;
  final String toUid;
  final DateTime? createdAt;

  factory ChallengeInvite.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final createdAt = data['createdAt'];
    return ChallengeInvite(
      id: snapshot.id,
      challengeId: data['challengeId'] as String,
      challengeName: data['challengeName'] as String,
      fromUid: data['fromUid'] as String,
      fromUsername: data['fromUsername'] as String,
      toUid: data['toUid'] as String,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

class ChallengeScoreEntry {
  const ChallengeScoreEntry({
    required this.uid,
    required this.username,
    required this.score,
    required this.perDay,
    this.updatedAt,
    this.rank = 0,
  });

  final String uid;
  final String username;
  final double score;
  final Map<String, double> perDay;
  final DateTime? updatedAt;
  final int rank;

  factory ChallengeScoreEntry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final score = data['score'];
    final perDay = data['perDay'] as Map? ?? const {};
    final updatedAt = data['updatedAt'];
    return ChallengeScoreEntry(
      uid: snapshot.id,
      username: data['username'] as String? ?? 'friend',
      score: score is num ? score.toDouble() : 0,
      perDay: {
        for (final entry in perDay.entries)
          if (entry.key is String && entry.value is num)
            entry.key as String: (entry.value as num).toDouble(),
      },
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}

class ChallengeService {
  ChallengeService({
    required this.uid,
    required this.username,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  static const allowedMetrics = [
    'workouts',
    'volume',
    'steps',
    'activeDays',
  ];

  final String uid;
  final String username;
  final FirebaseFirestore _db;

  Stream<List<FitnessChallenge>> myChallenges() => _db
      .collection('challenges')
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((snapshot) {
        final challenges = snapshot.docs
            .map(FitnessChallenge.fromDocument)
            .toList();
        challenges.sort((a, b) => a.endDate.compareTo(b.endDate));
        return challenges;
      });

  Stream<List<ChallengeInvite>> invites() => _db
      .collection('challengeInvites')
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        final invites = snapshot.docs.map(ChallengeInvite.fromDocument).toList();
        invites.sort(
          (a, b) => (a.createdAt ?? DateTime(1970)).compareTo(
            b.createdAt ?? DateTime(1970),
          ),
        );
        return invites;
      });

  Stream<FitnessChallenge?> watchChallenge(String id) => _db
      .collection('challenges')
      .doc(id)
      .snapshots()
      .map((snapshot) => snapshot.exists ? FitnessChallenge.fromDocument(snapshot) : null);

  Stream<List<ChallengeScoreEntry>> watchScores(String challengeId) => _db
      .collection('challenges')
      .doc(challengeId)
      .collection('scores')
      .snapshots()
      .map((snapshot) => rankScores(snapshot.docs.map(ChallengeScoreEntry.fromDocument)));

  Future<String> createChallenge({
    required String name,
    required ChallengeMetric metric,
    required DateTime startDate,
    required DateTime endDate,
    required List<FriendSummary> invitees,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 40) {
      throw const FormatException('Challenge name must be 1–40 characters.');
    }
    if (invitees.isEmpty) {
      throw const FormatException('Choose at least one friend to invite.');
    }
    final start = _localDay(startDate);
    final end = _localDay(endDate);
    final length = end.difference(start).inDays;
    if (length <= 0 || length > 60) {
      throw const FormatException('Choose a duration between 1 and 60 days.');
    }
    final challengeRef = _db.collection('challenges').doc();
    final batch = _db.batch();
    batch.set(challengeRef, {
      'name': normalizedName,
      'metric': metric.firestoreValue,
      'startDate': Timestamp.fromDate(start.toUtc()),
      'endDate': Timestamp.fromDate(end.toUtc()),
      'creatorUid': uid,
      'memberUids': [uid],
      'memberNames': {uid: username},
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    final scoreRef = challengeRef.collection('scores').doc(uid);
    batch.set(scoreRef, {
      'score': 0,
      'perDay': const <String, num>{},
      'username': username,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final invitee in invitees) {
      batch.set(
        _db.collection('challengeInvites').doc('${challengeRef.id}_${invitee.uid}'),
        {
          'challengeId': challengeRef.id,
          'challengeName': normalizedName,
          'fromUid': uid,
          'fromUsername': username,
          'toUid': invitee.uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }
    final inviteIds = invitees
        .map((invitee) => '${challengeRef.id}_${invitee.uid}')
        .join(', ');
    try {
      await batch.commit();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Challenge create Firestore write failed: '
        'write=batch.commit; challenge=${challengeRef.id}; '
        'initialScore=${scoreRef.path}; inviteIds=[$inviteIds]; '
        'code=${error.code}; message=${error.message}\n$stackTrace',
      );
      rethrow;
    }
    return challengeRef.id;
  }

  Future<void> acceptInvite(ChallengeInvite invite) async {
    if (invite.toUid != uid) {
      throw StateError('This invite is not addressed to you.');
    }
    final challengeRef = _db.collection('challenges').doc(invite.challengeId);
    final inviteRef = _db.collection('challengeInvites').doc(invite.id);
    final batch = _db.batch();
    batch.update(challengeRef, {
      'memberUids': FieldValue.arrayUnion([uid]),
      'memberNames.$uid': username,
    });
    batch.set(challengeRef.collection('scores').doc(uid), {
      'score': 0,
      'perDay': const <String, num>{},
      'username': username,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(inviteRef);
    await batch.commit();
  }

  Future<void> declineInvite(ChallengeInvite invite) =>
      _db.collection('challengeInvites').doc(invite.id).delete();

  Future<void> inviteMore(
    FitnessChallenge challenge,
    List<FriendSummary> invitees,
  ) async {
    if (!challenge.memberUids.contains(uid)) {
      throw StateError('Only challenge members can invite friends.');
    }
    final batch = _db.batch();
    for (final invitee in invitees) {
      if (challenge.memberUids.contains(invitee.uid)) continue;
      batch.set(
        _db.collection('challengeInvites').doc('${challenge.id}_${invitee.uid}'),
        {
          'challengeId': challenge.id,
          'challengeName': challenge.name,
          'fromUid': uid,
          'fromUsername': username,
          'toUid': invitee.uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  Future<void> leaveChallenge(FitnessChallenge challenge) async {
    final batch = _db.batch();
    batch.update(_db.collection('challenges').doc(challenge.id), {
      'memberUids': FieldValue.arrayRemove([uid]),
      'memberNames.$uid': FieldValue.delete(),
    });
    batch.delete(
      _db
          .collection('challenges')
          .doc(challenge.id)
          .collection('scores')
          .doc(uid),
    );
    await batch.commit();
  }

  Future<void> endChallenge(FitnessChallenge challenge) =>
      _db.collection('challenges').doc(challenge.id).update({'status': 'ended'});

  Future<void> deleteChallenge(FitnessChallenge challenge) async {
    final ref = _db.collection('challenges').doc(challenge.id);
    final batch = _db.batch();
    batch.delete(ref.collection('scores').doc(uid));
    final invites = await _db
        .collection('challengeInvites')
        .where('fromUid', isEqualTo: uid)
        .get();
    for (final invite in invites.docs) {
      if (invite.data()['challengeId'] == challenge.id) {
        batch.delete(invite.reference);
      }
    }
    batch.delete(ref);
    await batch.commit();
  }

  static List<ChallengeScoreEntry> rankScores(
    Iterable<ChallengeScoreEntry> entries,
  ) {
    final sorted = entries.toList()
      ..sort((a, b) {
        final scoreOrder = b.score.compareTo(a.score);
        return scoreOrder != 0
            ? scoreOrder
            : a.username.toLowerCase().compareTo(b.username.toLowerCase());
      });
    var rank = 0;
    double? previousScore;
    return [
      for (var index = 0; index < sorted.length; index++)
        (() {
          if (previousScore != sorted[index].score) rank = index + 1;
          previousScore = sorted[index].score;
          final item = sorted[index];
          return ChallengeScoreEntry(
            uid: item.uid,
            username: item.username,
            score: item.score,
            perDay: item.perDay,
            updatedAt: item.updatedAt,
            rank: rank,
          );
        })(),
    ];
  }

  static String dayId(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime _localDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
