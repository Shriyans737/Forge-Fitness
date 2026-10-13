const String kGeminiApiKey = String.fromEnvironment(
  'FORGE_GEMINI_API_KEY',
  defaultValue: '',
);

const String kGeminiModelName = 'gemini-3.6-flash';

enum GeminiApiKeySource {
  savedKey('saved key'),
  compiledDefault('compiled default'),
  none('none');

  const GeminiApiKeySource(this.label);

  final String label;
}

class GeminiApiKeyResolution {
  const GeminiApiKeyResolution({required this.key, required this.source});

  final String? key;
  final GeminiApiKeySource source;
}

GeminiApiKeyResolution resolveGeminiApiKey({
  required Object? savedValue,
  required String compiledDefault,
}) {
  final savedKey = savedValue is String ? savedValue.trim() : null;
  if (savedKey != null && savedKey.isNotEmpty) {
    return GeminiApiKeyResolution(
      key: savedKey,
      source: GeminiApiKeySource.savedKey,
    );
  }

  final fallbackKey = compiledDefault.trim();
  if (fallbackKey.isNotEmpty) {
    return GeminiApiKeyResolution(
      key: fallbackKey,
      source: GeminiApiKeySource.compiledDefault,
    );
  }

  return const GeminiApiKeyResolution(
    key: null,
    source: GeminiApiKeySource.none,
  );
}
