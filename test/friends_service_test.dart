import 'package:flutter_test/flutter_test.dart';
import 'package:forge/services/friends_service.dart';

void main() {
  group('FriendsService', () {
    test('pairIdFor sorts UIDs before joining them', () {
      expect(FriendsService.pairIdFor('uid-z', 'uid-a'), 'uid-a_uid-z');
      expect(FriendsService.pairIdFor('uid-a', 'uid-z'), 'uid-a_uid-z');
    });
  });
}
