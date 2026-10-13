import 'package:flutter_test/flutter_test.dart';
import 'package:forge/services/gemini_api_key_resolver.dart';

void main() {
  test('saved key is trimmed and takes precedence', () {
    final result = resolveGeminiApiKey(
      savedValue: '  saved-key  ',
      compiledDefault: 'compiled-key',
    );

    expect(result.key, 'saved-key');
    expect(result.source, GeminiApiKeySource.savedKey);
  });

  test('blank saved key falls back to the compiled default', () {
    final result = resolveGeminiApiKey(
      savedValue: '  ',
      compiledDefault: ' compiled-key ',
    );

    expect(result.key, 'compiled-key');
    expect(result.source, GeminiApiKeySource.compiledDefault);
  });

  test('missing or non-string values resolve to none without fallback', () {
    final missing = resolveGeminiApiKey(
      savedValue: null,
      compiledDefault: ' ',
    );
    final nonString = resolveGeminiApiKey(
      savedValue: 123,
      compiledDefault: '',
    );

    expect(missing.key, isNull);
    expect(missing.source, GeminiApiKeySource.none);
    expect(nonString.key, isNull);
    expect(nonString.source, GeminiApiKeySource.none);
  });
}