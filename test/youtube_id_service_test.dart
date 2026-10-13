import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/services/youtube_id_service.dart';

void main() {
  group('YoutubeIdService', () {
    test('returns a valid ID for the exact exercise key', () async {
      const id = 'abcdefghijk';
      final service = _service('{"3_4_Sit-Up":"$id"}');

      await service.load();

      expect(service.idFor('3_4_Sit-Up'), id);
    });

    test('ignores IDs with invalid lengths or characters', () async {
      final service = _service('{"short":"abcdefghij","bad":"abcd!fghijk"}');

      await service.load();

      expect(service.idFor('short'), isNull);
      expect(service.idFor('bad'), isNull);
    });

    test('returns null when the exercise key is absent', () async {
      final service = _service('{}');

      await service.load();

      expect(service.idFor('missing'), isNull);
    });

    test('empty and malformed JSON do not throw', () async {
      for (final json in ['', '{malformed']) {
        final service = _service(json);

        await expectLater(service.load(), completes);
        expect(service.idFor('exercise'), isNull);
      }
    });

    test('a missing asset is treated as having no video IDs', () async {
      final service = YoutubeIdService(
        assetLoader: (_) async => throw FlutterError('Asset not found'),
      );

      await expectLater(service.load(), completes);
      expect(service.idFor('exercise'), isNull);
    });

    test('loads the asset once', () async {
      var loadCount = 0;
      final service = YoutubeIdService(
        assetLoader: (_) async {
          loadCount++;
          return '{}';
        },
      );

      await Future.wait([service.load(), service.load()]);

      expect(loadCount, 1);
    });
  });
}

YoutubeIdService _service(String json) =>
    YoutubeIdService(assetLoader: (_) async => json);
