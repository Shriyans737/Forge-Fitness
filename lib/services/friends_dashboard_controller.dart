import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'friend_data_service.dart';
import 'friends_service.dart';

class FriendsDashboardController extends ChangeNotifier {
  factory FriendsDashboardController({
    Future<String> Function()? loadUid,
    Stream<List<FriendRequest>> Function(String uid)? incomingRequests,
    Stream<List<FriendSummary>> Function(String uid)? friends,
    Future<FriendSharedData> Function(String uid)? loadFriendData,
  }) => FriendsDashboardController._(
    loadUid: loadUid ?? AuthService().signInAnonymouslyIfNeeded,
    incomingRequests: incomingRequests,
    friendsStream: friends,
    loadFriendData: loadFriendData ?? _loadDefaultFriendData,
  );

  FriendsDashboardController._({
    required this._loadUid,
    this.incomingRequests,
    this.friendsStream,
    required this._loadFriendData,
  });

  static Future<FriendSharedData> _loadDefaultFriendData(String uid) =>
      FriendDataService().fetchForFriend(uid);

  final Future<String> Function() _loadUid;
  final Stream<List<FriendRequest>> Function(String uid)? incomingRequests;
  final Stream<List<FriendSummary>> Function(String uid)? friendsStream;
  final Future<FriendSharedData> Function(String uid) _loadFriendData;
  final Map<String, Future<FriendSharedData>> _friendData = {};
  StreamSubscription<List<FriendRequest>>? _requestsSubscription;
  StreamSubscription<List<FriendSummary>>? _friendsSubscription;
  Future<void>? _startFuture;

  List<FriendSummary> _friends = const [];
  int _incomingRequestCount = 0;

  List<FriendSummary> get friends => _friends;
  int get incomingRequestCount => _incomingRequestCount;
  int get additionalFriendCount =>
      _friends.length > 5 ? _friends.length - 5 : 0;

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    try {
      final uid = await _loadUid();
      final service = incomingRequests == null || friendsStream == null
          ? FriendsService(uid: uid)
          : null;
      _requestsSubscription =
          (incomingRequests?.call(uid) ?? service!.incomingRequests()).listen(
            (requests) {
              _incomingRequestCount = requests.length;
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (error is FirebaseException && error.code == 'unavailable') {
                _incomingRequestCount = 0;
                notifyListeners();
                return;
              } else if (error is FirebaseException) {
                debugPrint(
                  'Friends request badge stream failed (${error.code}): '
                  '${error.message}\n$stackTrace',
                );
              } else {
                debugPrint(
                  'Friends request badge stream failed: $error\n$stackTrace',
                );
              }
              _incomingRequestCount = 0;
              notifyListeners();
            },
          );
      _friendsSubscription =
          (friendsStream?.call(uid) ?? service!.friends()).listen(
            (friends) {
              _friends = friends;
              for (final friend in friends.take(5)) {
                _friendData.putIfAbsent(
                  friend.uid,
                  () => _loadFriendData(friend.uid),
                );
              }
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (error is FirebaseException) {
                debugPrint(
                  'Friends dashboard stream failed (${error.code}): '
                  '${error.message}\n$stackTrace',
                );
              } else {
                debugPrint(
                  'Friends dashboard stream failed: $error\n$stackTrace',
                );
              }
              _friends = const [];
              notifyListeners();
            },
          );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Friends dashboard initialization failed (${error.code}): '
        '${error.message}\n$stackTrace',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Friends dashboard initialization failed: $error\n$stackTrace',
      );
    }
  }

  Future<FriendSharedData>? dataFor(String friendUid) => _friendData[friendUid];

  @override
  void dispose() {
    unawaited(_requestsSubscription?.cancel());
    unawaited(_friendsSubscription?.cancel());
    super.dispose();
  }
}
