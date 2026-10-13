import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'friends_service.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.type,
    required this.memberUids,
    required this.memberNames,
    required this.creatorUid,
    required this.name,
    required this.lastMessage,
    required this.lastSenderUid,
    required this.lastMessageAt,
    required this.lastRead,
    this.createdAt,
    this.exists = true,
  });

  final String id;
  final String type;
  final List<String> memberUids;
  final Map<String, String> memberNames;
  final String creatorUid;
  final String? name;
  final String? lastMessage;
  final String? lastSenderUid;
  final DateTime? lastMessageAt;
  final Map<String, DateTime> lastRead;
  final DateTime? createdAt;
  final bool exists;

  bool get isGroup => type == 'group';

  bool isUnreadFor(String uid) {
    return ChatService.isUnread(
      lastMessageAt: lastMessageAt,
      lastReadAt: lastRead[uid],
      lastSenderUid: lastSenderUid,
      currentUid: uid,
    );
  }

  String titleFor(String uid) {
    if (isGroup) return name ?? 'Group chat';
    final otherUid = memberUids.firstWhere(
      (memberUid) => memberUid != uid,
      orElse: () => '',
    );
    final username = memberNames[otherUid];
    return username == null ? 'Chat' : '@$username';
  }

  factory ChatConversation.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) throw StateError('Conversation ${document.id} is empty.');
    final lastMessageAt = data['lastMessageAt'];
    final createdAt = data['createdAt'];
    final lastRead = data['lastRead'] as Map? ?? const {};
    return ChatConversation(
      id: document.id,
      type: data['type'] as String? ?? 'dm',
      memberUids: (data['memberUids'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      memberNames: {
        for (final entry in (data['memberNames'] as Map? ?? const {}).entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      },
      creatorUid: data['creatorUid'] as String? ?? '',
      name: data['name'] as String?,
      lastMessage: data['lastMessage'] as String?,
      lastSenderUid: data['lastSenderUid'] as String?,
      lastMessageAt: lastMessageAt is Timestamp ? lastMessageAt.toDate() : null,
      lastRead: {
        for (final entry in lastRead.entries)
          if (entry.key is String && entry.value is Timestamp)
            entry.key as String: (entry.value as Timestamp).toDate(),
      },
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  static ChatConversation directMessage({
    required String currentUid,
    required String currentUsername,
    required FriendSummary friend,
  }) {
    final names = <String, String>{
      currentUid: currentUsername,
      friend.uid: friend.username,
    };
    return ChatConversation(
      id: dmIdFor(currentUid, friend.uid),
      type: 'dm',
      memberUids: [currentUid, friend.uid]..sort(),
      memberNames: names,
      creatorUid: currentUid,
      name: null,
      lastMessage: null,
      lastSenderUid: null,
      lastMessageAt: null,
      lastRead: const {},
      exists: false,
    );
  }

  static String dmIdFor(String firstUid, String secondUid) =>
      FriendsService.pairIdFor(firstUid, secondUid);
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.cursor,
  });

  final String id;
  final String senderUid;
  final String senderName;
  final String text;
  final DateTime? createdAt;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;

  factory ChatMessage.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final createdAt = data['createdAt'];
    return ChatMessage(
      id: document.id,
      senderUid: data['senderUid'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'friend',
      text: data['text'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      cursor: document,
    );
  }
}

class ChatNotFriendException implements Exception {
  const ChatNotFriendException();

  @override
  String toString() => "You can't message this person";
}

class ChatService {
  ChatService({
    required this.uid,
    required this.username,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final String username;
  final FirebaseFirestore _db;

  static String dmIdFor(String firstUid, String secondUid) =>
      ChatConversation.dmIdFor(firstUid, secondUid);

  static bool isUnread({
    required DateTime? lastMessageAt,
    required DateTime? lastReadAt,
    required String? lastSenderUid,
    required String currentUid,
  }) {
    if (lastMessageAt == null || lastSenderUid == currentUid) return false;
    return lastReadAt == null || lastMessageAt.isAfter(lastReadAt);
  }

  Stream<List<ChatConversation>> conversations() => _db
      .collection('conversations')
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .asyncMap((snapshot) async {
        final blocked = await _db
            .collection('blocks')
            .doc(uid)
            .collection('blocked')
            .get();
        final blockedUids = blocked.docs.map((doc) => doc.id).toSet();
        final conversations = snapshot.docs
            .map(ChatConversation.fromDocument)
            .where((conversation) {
              if (conversation.isGroup) return true;
              final other = conversation.memberUids.firstWhere(
                (memberUid) => memberUid != uid,
                orElse: () => '',
              );
              return !blockedUids.contains(other);
            })
            .toList();
        conversations.sort(
          (a, b) => (b.lastMessageAt ?? b.createdAt ?? DateTime(1970))
              .compareTo(a.lastMessageAt ?? a.createdAt ?? DateTime(1970)),
        );
        return conversations;
      });

  Stream<int> unreadCount() => conversations().map(
    (items) => items
        .where((item) => item.isUnreadFor(uid) && !isMuted(item.id))
        .length,
  );

  Stream<Map<String, String>> blockedUsers() => _db
      .collection('blocks')
      .doc(uid)
      .collection('blocked')
      .snapshots()
      .map(
        (snapshot) => {
          for (final document in snapshot.docs)
            document.id: document.data()['username'] as String? ?? 'friend',
        },
      );

  bool isMuted(String conversationId) {
    final settings = Hive.box<dynamic>('settings');
    final stored = settings.get('mutedConversationIds');
    return stored is List &&
        stored.whereType<String>().contains(conversationId);
  }

  Future<void> setMuted(String conversationId, bool muted) async {
    final settings = Hive.box<dynamic>('settings');
    final stored = settings.get('mutedConversationIds');
    final ids = stored is List
        ? stored.whereType<String>().toSet()
        : <String>{};
    if (muted) {
      ids.add(conversationId);
    } else {
      ids.remove(conversationId);
    }
    await settings.put('mutedConversationIds', ids.toList(growable: false));
  }

  Future<void> blockUser({
    required String otherUid,
    required String otherUsername,
  }) async {
    if (otherUid == uid) throw ArgumentError('You cannot block yourself.');
    await _db
        .collection('blocks')
        .doc(uid)
        .collection('blocked')
        .doc(otherUid)
        .set({
          'createdAt': FieldValue.serverTimestamp(),
          'username': otherUsername,
        });
    try {
      if (await isStillFriend(otherUid)) {
        await FriendsService(uid: uid, firestore: _db).removeFriend(otherUid);
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Block succeeded but friendship removal failed for $otherUid '
        '(${error.code}): ${error.message}\n$stackTrace',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Block succeeded but friendship removal failed for $otherUid: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> unblockUser(String otherUid) => _db
      .collection('blocks')
      .doc(uid)
      .collection('blocked')
      .doc(otherUid)
      .delete();

  Future<void> reportMessage({
    required String reportedUid,
    required String conversationId,
    required String messageId,
    required String messageText,
    required String reason,
    String note = '',
  }) async {
    const reasons = {'Spam', 'Harassment', 'Inappropriate content', 'Other'};
    final cleanedText = messageText.length <= 1000
        ? messageText
        : messageText.substring(0, 1000);
    final cleanedNote = note.trim();
    if (!reasons.contains(reason)) {
      throw ArgumentError.value(reason, 'reason', 'Invalid report reason.');
    }
    if (cleanedNote.length > 300) {
      throw ArgumentError.value(note, 'note', 'Report note exceeds 300 chars.');
    }
    await _db.collection('reports').add({
      'reporterUid': uid,
      'reportedUid': reportedUid,
      'conversationId': conversationId,
      'messageId': messageId,
      'messageText': cleanedText,
      'reason': reason,
      'note': cleanedNote,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteOwnMessage(
    ChatConversation conversation,
    ChatMessage message,
  ) async {
    if (message.senderUid != uid) {
      throw StateError('You can only delete your own messages.');
    }
    final conversationRef = _db
        .collection('conversations')
        .doc(conversation.id);
    final messagesRef = conversationRef.collection('messages');
    final latest = await messagesRef
        .orderBy('createdAt', descending: true)
        .limit(2)
        .get();
    final isLast = latest.docs.isNotEmpty && latest.docs.first.id == message.id;
    final batch = _db.batch()..delete(messagesRef.doc(message.id));
    if (isLast) {
      final previous = latest.docs.length > 1
          ? ChatMessage.fromDocument(latest.docs[1])
          : null;
      batch.update(conversationRef, {
        'lastMessage': previous == null
            ? 'Message deleted'
            : (previous.text.length <= 80
                  ? previous.text
                  : '${previous.text.substring(0, 79)}…'),
        'lastSenderUid': previous?.senderUid ?? uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }
    try {
      await batch.commit();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Delete chat message failed: conversation=${conversation.id}; '
        'message=${message.id}; code=${error.code}; '
        'message=${error.message}\n$stackTrace',
      );
      rethrow;
    }
  }

  Stream<ChatConversation?> watchConversation(String conversationId) => _db
      .collection('conversations')
      .doc(conversationId)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.exists ? ChatConversation.fromDocument(snapshot) : null,
      );

  Stream<List<ChatMessage>> latestMessages(String conversationId) => _db
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(ChatMessage.fromDocument)
            .toList()
            .reversed
            .toList(growable: false),
      );

  Future<List<ChatMessage>> loadOlder(
    String conversationId,
    ChatMessage oldest,
  ) async {
    final cursor = oldest.cursor;
    if (cursor == null) return const [];
    final snapshot = await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(cursor)
        .limit(30)
        .get();
    return snapshot.docs
        .map(ChatMessage.fromDocument)
        .toList()
        .reversed
        .toList(growable: false);
  }

  Future<bool> isStillFriend(String friendUid) async {
    if (friendUid == uid) return false;
    final pairId = FriendsService.pairIdFor(uid, friendUid);
    final friendship = await _db.collection('friendships').doc(pairId).get();
    return friendship.exists &&
        ((friendship.data()?['members'] as List?)?.contains(uid) ?? false) &&
        ((friendship.data()?['members'] as List?)?.contains(friendUid) ??
            false);
  }

  Future<ChatConversation> createGroup({
    required String name,
    required List<FriendSummary> friends,
  }) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty || cleanedName.length > 40) {
      throw const FormatException('Group name must be 1–40 characters.');
    }
    if (friends.length < 2 || friends.length > 19) {
      throw const FormatException('Choose 2–19 friends for a group.');
    }
    final members = <String>{uid, ...friends.map((friend) => friend.uid)};
    if (members.length < 3 || members.length > 20) {
      throw const FormatException('Choose 2–19 different friends.');
    }
    final reference = _db.collection('conversations').doc();
    final names = <String, String>{
      uid: username,
      for (final friend in friends) friend.uid: friend.username,
    };
    final now = FieldValue.serverTimestamp();
    await reference.set({
      'type': 'group',
      'memberUids': members.toList()..sort(),
      'memberNames': names,
      'name': cleanedName,
      'creatorUid': uid,
      'lastMessage': '',
      'lastSenderUid': uid,
      'lastMessageAt': now,
      'lastRead': {uid: now},
      'createdAt': now,
    });
    return ChatConversation(
      id: reference.id,
      type: 'group',
      memberUids: members.toList(growable: false),
      memberNames: names,
      creatorUid: uid,
      name: cleanedName,
      lastMessage: '',
      lastSenderUid: uid,
      lastMessageAt: DateTime.now(),
      lastRead: {uid: DateTime.now()},
      createdAt: DateTime.now(),
    );
  }

  Future<void> sendMessage(
    ChatConversation conversation,
    String rawText,
  ) async {
    final text = rawText.trim();
    if (text.isEmpty) return;
    if (text.length > 1000) {
      throw const FormatException('Messages can be up to 1000 characters.');
    }
    final otherUid = conversation.isGroup
        ? null
        : conversation.memberUids.firstWhere(
            (memberUid) => memberUid != uid,
            orElse: () => '',
          );
    if (otherUid == null || otherUid.isEmpty) {
      throw const ChatNotFriendException();
    }
    if (!await isStillFriend(otherUid)) throw const ChatNotFriendException();

    final conversationRef = _db
        .collection('conversations')
        .doc(conversation.id);
    final existingConversation = conversation.isGroup
        ? null
        : await conversationRef.get();
    final currentConversation = existingConversation?.exists == true
        ? ChatConversation.fromDocument(existingConversation!)
        : conversation;
    final messageRef = conversationRef.collection('messages').doc();
    final batch = _db.batch();
    final preview = text.length <= 80 ? text : '${text.substring(0, 79)}…';
    final messageTime = FieldValue.serverTimestamp();
    if (!currentConversation.exists) {
      batch.set(conversationRef, {
        'type': 'dm',
        'memberUids': currentConversation.memberUids,
        'memberNames': currentConversation.memberNames,
        'creatorUid': uid,
        'lastMessage': preview,
        'lastSenderUid': uid,
        'lastMessageAt': messageTime,
        'lastRead': {uid: messageTime},
        'createdAt': messageTime,
      });
    } else {
      batch.update(conversationRef, {
        'lastMessage': preview,
        'lastSenderUid': uid,
        'lastMessageAt': messageTime,
        'lastRead.$uid': messageTime,
      });
    }
    batch.set(messageRef, {
      'senderUid': uid,
      'senderName': username,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Chat send failed: writes=conversation:${conversationRef.path}, '
        'message:${messageRef.path}; code=${error.code}; '
        'message=${error.message}\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> markRead(ChatConversation conversation) async {
    if (!conversation.exists) return;
    try {
      await _db.collection('conversations').doc(conversation.id).update({
        'lastRead.$uid': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Chat read receipt update failed: document=conversations/'
        '${conversation.id}; code=${error.code}; message=${error.message}\n'
        '$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> addMembers(
    ChatConversation conversation,
    List<FriendSummary> friends,
  ) async {
    if (!conversation.isGroup || conversation.creatorUid != uid) {
      throw StateError('Only the group creator can add members.');
    }
    final additions = friends
        .where((friend) => !conversation.memberUids.contains(friend.uid))
        .toList();
    if (conversation.memberUids.length + additions.length > 20) {
      throw const FormatException('Groups can have up to 20 members.');
    }
    if (additions.isEmpty) return;
    final reference = _db.collection('conversations').doc(conversation.id);
    for (final friend in additions) {
      await reference.update({
        'memberUids': FieldValue.arrayUnion([friend.uid]),
        'memberNames.${friend.uid}': friend.username,
      });
    }
  }

  Future<void> leaveGroup(ChatConversation conversation) async {
    if (!conversation.isGroup) return;
    await _db.collection('conversations').doc(conversation.id).update({
      'memberUids': FieldValue.arrayRemove([uid]),
      'memberNames': {
        for (final entry in conversation.memberNames.entries)
          if (entry.key != uid) entry.key: entry.value,
      },
    });
  }
}
