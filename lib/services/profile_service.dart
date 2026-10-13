import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.friendCode,
    required this.createdAt,
  });

  final String uid;
  final String username;
  final String displayName;
  final String friendCode;
  final DateTime? createdAt;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return UserProfile(
      uid: uid,
      username: data['username'] as String,
      displayName: data['displayName'] as String,
      friendCode: data['friendCode'] as String,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

class UsernameTakenException implements Exception {
  const UsernameTakenException();

  @override
  String toString() => 'That username is already taken.';
}

class ProfileAlreadyExistsException implements Exception {
  const ProfileAlreadyExistsException();
}

class FriendCodeCollisionException implements Exception {
  const FriendCodeCollisionException();
}

class ProfileService {
  ProfileService({this.firestore});

  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9_]{3,16}$');
  static const _friendCodeCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore? firestore;
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
  final Random _random = Random.secure();

  static bool isValidUsername(String username) =>
      _usernamePattern.hasMatch(username);

  static String usernameSuggestionFromDisplayName(String displayName) {
    final suggestion = displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (suggestion.length < 3) return 'forge_user';
    return suggestion.substring(0, min(suggestion.length, 16));
  }

  Future<UserProfile?> getProfile(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    return snapshot.exists && data != null
        ? UserProfile.fromMap(uid, data)
        : null;
  }

  Future<bool> isUsernameAvailable(String uid, String username) async {
    if (!isValidUsername(username)) return false;
    final snapshot = await _db
        .collection('usernames')
        .doc(username)
        .get(const GetOptions(source: Source.server));
    return !snapshot.exists || snapshot.data()?['uid'] == uid;
  }

  Future<UserProfile> createProfile({
    required String uid,
    required String username,
    required String displayName,
  }) async {
    if (!isValidUsername(username)) {
      throw ArgumentError.value(username, 'username', 'Invalid username.');
    }

    final userRef = _db.collection('users').doc(uid);
    final usernameRef = _db.collection('usernames').doc(username);
    for (var attempt = 0; attempt < 5; attempt++) {
      final friendCode = _newFriendCode();
      final friendCodeRef = _db.collection('friendCodes').doc(friendCode);
      try {
        return await _db.runTransaction((transaction) async {
          final userSnapshot = await transaction.get(userRef);
          final usernameSnapshot = await transaction.get(usernameRef);
          final friendCodeSnapshot = await transaction.get(friendCodeRef);

          if (userSnapshot.exists) {
            throw const ProfileAlreadyExistsException();
          }
          if (usernameSnapshot.exists) {
            throw const UsernameTakenException();
          }
          if (friendCodeSnapshot.exists) {
            throw const FriendCodeCollisionException();
          }

          final cleanedDisplayName = displayName.trim();
          final profileData = <String, dynamic>{
            'username': username,
            'displayName': cleanedDisplayName.isEmpty
                ? username
                : cleanedDisplayName,
            'friendCode': friendCode,
            'createdAt': FieldValue.serverTimestamp(),
          };
          transaction
            ..set(userRef, profileData)
            ..set(usernameRef, {'uid': uid})
            ..set(friendCodeRef, {'uid': uid});

          return UserProfile(
            uid: uid,
            username: username,
            displayName: cleanedDisplayName.isEmpty
                ? username
                : cleanedDisplayName,
            friendCode: friendCode,
            createdAt: null,
          );
        });
      } on FriendCodeCollisionException {
        if (attempt == 4) rethrow;
      }
    }
    throw StateError('Could not allocate a unique friend code.');
  }

  String _newFriendCode() => List.generate(
    6,
    (_) => _friendCodeCharacters[_random.nextInt(_friendCodeCharacters.length)],
  ).join();
}
