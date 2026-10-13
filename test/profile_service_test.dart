import 'package:flutter_test/flutter_test.dart';
import 'package:forge/services/profile_service.dart';

void main() {
  group('ProfileService username helpers', () {
    test('validates lowercase usernames from 3 to 16 characters', () {
      expect(ProfileService.isValidUsername('forge_user'), isTrue);
      expect(ProfileService.isValidUsername('abc'), isTrue);
      expect(ProfileService.isValidUsername('a1_'), isTrue);
      expect(ProfileService.isValidUsername('ab'), isFalse);
      expect(ProfileService.isValidUsername('Ausername'), isFalse);
      expect(ProfileService.isValidUsername('name-here'), isFalse);
      expect(
        ProfileService.isValidUsername('username_is_way_too_long'),
        isFalse,
      );
    });

    test('suggests a normalized username from the saved display name', () {
      expect(
        ProfileService.usernameSuggestionFromDisplayName('Alex Smith'),
        'alex_smith',
      );
      expect(
        ProfileService.usernameSuggestionFromDisplayName('Jo'),
        'forge_user',
      );
      expect(
        ProfileService.usernameSuggestionFromDisplayName('ABCDEFGHIJKLMNOPQRS'),
        'abcdefghijklmnop',
      );
    });
  });
}
