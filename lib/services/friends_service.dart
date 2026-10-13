import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromUsername,
    required this.fromDisplayName,
    required this.createdAt,
    this.counterpartyUsername,
    this.counterpartyDisplayName,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String fromUsername;
  final String fromDisplayName;
  final DateTime? createdAt;
  final String? counterpartyUsername;
  final String? counterpartyDisplayName;

  factory FriendRequest.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final createdAt = data['createdAt'];
    return FriendRequest(
      id: document.id,
      fromUid: data['fromUid'] as String,
      toUid: data['toUid'] as String,
      fromUsername: data['fromUsername'] as String,
      fromDisplayName: data['fromDisplayName'] as String,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      counterpartyUsername: data['fromUsername'] as String,
      counterpartyDisplayName: data['fromDisplayName'] as String,
    );
  }

  FriendRequest withCounterparty({
    required String username,
    required String displayName,
  }) => FriendRequest(
    id: id,
    fromUid: fromUid,
    toUid: toUid,
    fromUsername: fromUsername,
    fromDisplayName: fromDisplayName,
    createdAt: createdAt,
    counterpartyUsername: username,
    counterpartyDisplayName: displayName,
  );
}

class FriendSummary {
  const FriendSummary({
    required this.uid,
    required this.username,
    required this.displayName,
  });

  final String uid;
  final String username;
  final String displayName;
}

class FriendServiceException implements Exception {
  const FriendServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FriendsService {
  FriendsService({required this.uid, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final RegExp _friendCodePattern = RegExp(r'^[A-Z0-9]{6}$');

  final String uid;
  final FirebaseFirestore _firestore;

  static String pairIdFor(String firstUid, String secondUid) =>
      ([firstUid, secondUid]..sort()).join('_');

  Stream<List<FriendRequest>> incomingRequests() => _firestore
      .collection('friendRequests')
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map(_mapRequests);

  Stream<List<FriendRequest>> outgoingRequests() => _firestore
      .collection('friendRequests')
      .where('fromUid', isEqualTo: uid)
      .snapshots()
      .asyncMap((snapshot) async {
        final requests = _mapRequests(snapshot);
        return Future.wait(
          requests.map((request) async {
            final recipientSnapshot = await _firestore
                .collection('users')
                .doc(request.toUid)
                .get();
            final recipient = recipientSnapshot.data();
            final username = recipient?['username'];
            final displayName = recipient?['displayName'];
            return request.withCounterparty(
              username: username is String ? username : 'friend',
              displayName: displayName is String && displayName.isNotEmpty
                  ? displayName
                  : 'Friend',
            );
          }),
        );
      });

  List<FriendRequest> _mapRequests(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final requests = snapshot.docs.map(FriendRequest.fromDocument).toList();
    requests.sort(
      (first, second) =>
          (second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              ),
    );
    return requests;
  }

  Future<String> sendRequestByCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (!_friendCodePattern.hasMatch(normalizedCode)) {
      throw const FriendServiceException(
        'Enter a valid 6-character friend code.',
      );
    }

    final codeRef = _firestore.collection('friendCodes').doc(normalizedCode);
    final senderRef = _firestore.collection('users').doc(uid);
    late final DocumentSnapshot<Map<String, dynamic>> codeSnapshot;
    try {
      codeSnapshot = await codeRef.get(const GetOptions(source: Source.server));
    } on FirebaseException catch (error, stackTrace) {
      _logFirebaseError('Friend code lookup failed', error, stackTrace);
      rethrow;
    }
    final targetUid = codeSnapshot.data()?['uid'];
    if (!codeSnapshot.exists || targetUid is! String || targetUid.isEmpty) {
      throw const FriendServiceException('That friend code was not found.');
    }
    if (targetUid == uid) {
      throw const FriendServiceException("That's your friend code.");
    }

    final pairId = pairIdFor(uid, targetUid);
    final friendshipRef = _firestore.collection('friendships').doc(pairId);
    final outgoingRef = _firestore
        .collection('friendRequests')
        .doc('${uid}_$targetUid');
    final incomingRef = _firestore
        .collection('friendRequests')
        .doc('${targetUid}_$uid');

    late final String result;
    try {
      result = await _firestore.runTransaction<String>((transaction) async {
        final senderSnapshot = await transaction.get(senderRef);
        final friendshipSnapshot = await transaction.get(friendshipRef);
        final outgoingSnapshot = await transaction.get(outgoingRef);
        final incomingSnapshot = await transaction.get(incomingRef);

        if (!senderSnapshot.exists) {
          throw const FriendServiceException(
            'Create your friends profile before adding friends.',
          );
        }
        if (friendshipSnapshot.exists) {
          throw const FriendServiceException("You're already friends.");
        }
        if (outgoingSnapshot.exists) {
          throw const FriendServiceException(
            'A friend request is already pending.',
          );
        }

        final sender = senderSnapshot.data()!;
        final senderUsername = sender['username'];
        final senderDisplayName = sender['displayName'];
        if (senderUsername is! String || senderDisplayName is! String) {
          throw const FriendServiceException(
            'Your friends profile is incomplete. Try again later.',
          );
        }

        if (incomingSnapshot.exists) {
          final incoming = incomingSnapshot.data()!;
          final incomingUsername = incoming['fromUsername'];
          if (incomingUsername is! String) {
            throw const FriendServiceException(
              'The incoming friend request is invalid.',
            );
          }
          final friendshipData = <String, dynamic>{
            'pairId': pairId,
            'members': [uid, targetUid],
            'usernames': {uid: senderUsername, targetUid: incomingUsername},
            'createdAt': FieldValue.serverTimestamp(),
          };
          transaction
            ..set(friendshipRef, friendshipData)
            ..delete(incomingRef);
          return 'accepted';
        }

        transaction.set(outgoingRef, {
          'fromUid': uid,
          'toUid': targetUid,
          'fromUsername': senderUsername,
          'fromDisplayName': senderDisplayName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return 'sent';
      });
    } on FirebaseException catch (error, stackTrace) {
      _logFirebaseError('Friend request send failed', error, stackTrace);
      rethrow;
    }

    return result == 'accepted'
        ? 'You’re friends now. Their request was accepted.'
        : 'Friend request sent.';
  }

  Future<void> acceptRequest(FriendRequest request) async {
    if (request.toUid != uid) {
      throw const FriendServiceException(
        'You can only accept requests sent to you.',
      );
    }
    final currentUserRef = _firestore.collection('users').doc(uid);
    final currentUserSnapshot = await currentUserRef.get(
      const GetOptions(source: Source.server),
    );
    final ownUsername = currentUserSnapshot.data()?['username'];
    if (!currentUserSnapshot.exists || ownUsername is! String) {
      throw const FriendServiceException(
        'Your friends profile is unavailable. Try again later.',
      );
    }

    final pairId = pairIdFor(uid, request.fromUid);
    final batch = _firestore.batch();
    batch
      ..set(_firestore.collection('friendships').doc(pairId), {
        'pairId': pairId,
        'members': [uid, request.fromUid],
        'usernames': {uid: ownUsername, request.fromUid: request.fromUsername},
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..delete(_firestore.collection('friendRequests').doc(request.id));
    await batch.commit();
  }

  Future<void> declineRequest(FriendRequest request) =>
      _deleteRequest(request, expectedIncoming: true);

  Future<void> cancelRequest(FriendRequest request) =>
      _deleteRequest(request, expectedIncoming: false);

  Future<void> _deleteRequest(
    FriendRequest request, {
    required bool expectedIncoming,
  }) async {
    final expectedUid = expectedIncoming ? request.toUid : request.fromUid;
    if (expectedUid != uid) {
      throw const FriendServiceException('You cannot change this request.');
    }
    await _firestore.collection('friendRequests').doc(request.id).delete();
  }

  Stream<List<FriendSummary>> friends() => _firestore
      .collection('friendships')
      .where('members', arrayContains: uid)
      .snapshots()
      .asyncMap((snapshot) async {
        final summaries = await Future.wait(
          snapshot.docs.map((document) async {
            final data = document.data();
            final members = data['members'];
            final usernames = data['usernames'];
            if (members is! List || usernames is! Map) {
              throw const FormatException('Invalid friendship document.');
            }
            final friendUid = members
                .whereType<String>()
                .where((memberUid) => memberUid != uid)
                .firstOrNull;
            if (friendUid == null) {
              throw const FormatException('Friendship is missing its member.');
            }
            final username = usernames[friendUid];
            if (username is! String) {
              throw const FormatException('Friendship is missing a username.');
            }
            var displayName = username;
            try {
              final userSnapshot = await _firestore
                  .collection('users')
                  .doc(friendUid)
                  .get();
              final profileDisplayName = userSnapshot.data()?['displayName'];
              if (profileDisplayName is String &&
                  profileDisplayName.isNotEmpty) {
                displayName = profileDisplayName;
              }
            } on FirebaseException catch (error, stackTrace) {
              _logFirebaseError(
                'Friend display name lookup failed for $friendUid',
                error,
                stackTrace,
              );
            } catch (error, stackTrace) {
              debugPrint(
                'Friend display name lookup failed for $friendUid: '
                '$error\n$stackTrace',
              );
            }
            return FriendSummary(
              uid: friendUid,
              username: username,
              displayName: displayName,
            );
          }),
        );
        summaries.sort(
          (first, second) => first.displayName.toLowerCase().compareTo(
            second.displayName.toLowerCase(),
          ),
        );
        return summaries;
      });

  Future<void> removeFriend(String friendUid) async {
    if (friendUid == uid) {
      throw const FriendServiceException('You cannot remove yourself.');
    }
    await _firestore
        .collection('friendships')
        .doc(pairIdFor(uid, friendUid))
        .delete();
  }

  void _logFirebaseError(
    String action,
    FirebaseException error,
    StackTrace stackTrace,
  ) {
    debugPrint('$action: ${error.code}: ${error.message}\n$stackTrace');
  }
}
