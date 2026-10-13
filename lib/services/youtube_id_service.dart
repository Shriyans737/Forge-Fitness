import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef AssetStringLoader = Future<String> Function(String assetPath);

class YoutubeIdService {
  YoutubeIdService({AssetStringLoader? assetLoader})
      : _assetLoader = assetLoader ?? rootBundle.loadString;

  static final YoutubeIdService instance = YoutubeIdService();

  static const _assetPath = 'assets/data/youtube_ids.json';
  static final _validId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  final AssetStringLoader _assetLoader;
  Future<void>? _loadFuture;
  Map<String, String> _ids = const {};

  Future<void> load() => _loadFuture ??= _loadIds();

  String? idFor(String exerciseId) {
    final id = _ids[exerciseId];
    if (id == null) {
      if (_loadFuture != null) {
        debugPrint('No YouTube tutorial ID for exercise "$exerciseId".');
      }
      return null;
    }
    if (!_validId.hasMatch(id)) {
      debugPrint('Ignoring invalid YouTube tutorial ID for "$exerciseId".');
      return null;
    }
    return id;
  }

  Future<void> _loadIds() async {
    try {
      final jsonString = await _assetLoader(_assetPath);
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        _ids = const {};
        debugPrint('YouTube ID asset must contain a JSON object.');
        return;
      }

      final validIds = <String, String>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is String && _validId.hasMatch(value)) {
          validIds[entry.key] = value;
        } else {
          debugPrint(
            'Ignoring invalid YouTube tutorial ID for "${entry.key}".',
          );
        }
      }
      _ids = Map<String, String>.unmodifiable(validIds);
    } catch (error, stackTrace) {
      _ids = const {};
      debugPrint('Could not load or parse YouTube ID asset: $error\n$stackTrace');
    }
  }
}
