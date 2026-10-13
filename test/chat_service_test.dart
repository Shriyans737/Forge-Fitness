import 'package:flutter_test/flutter_test.dart';
import 'package:forge/services/chat_service.dart';

void main() {
  group('ChatService.isUnread', () {
    final messageAt = DateTime(2026, 10, 11, 12);

    test('is unread when a newer message was sent by someone else', () {
      expect(
        ChatService.isUnread(
          lastMessageAt: messageAt,
          lastReadAt: messageAt.subtract(const Duration(seconds: 1)),
          lastSenderUid: 'friend',
          currentUid: 'me',
        ),
        isTrue,
      );
    });

    test('is read for my message or when read time is current', () {
      expect(
        ChatService.isUnread(
          lastMessageAt: messageAt,
          lastReadAt: messageAt,
          lastSenderUid: 'friend',
          currentUid: 'me',
        ),
        isFalse,
      );
      expect(
        ChatService.isUnread(
          lastMessageAt: messageAt,
          lastReadAt: null,
          lastSenderUid: 'me',
          currentUid: 'me',
        ),
        isFalse,
      );
    });
  });

  test('DM id uses the sorted friendship pair id', () {
    expect(ChatService.dmIdFor('z-user', 'a-user'), 'a-user_z-user');
    expect(ChatService.dmIdFor('a-user', 'z-user'), 'a-user_z-user');
  });
}
