/// Build-time configuration.
///
/// The Gemini API key is injected when the app is compiled, for example:
///
///   flutter build apk --release --dart-define=GEMINI_API_KEY=...
///
/// The CI workflow passes it from the `GEMINI_API_KEY` repository secret, so
/// the key never appears in the source code. If no key is provided at build
/// time the app falls back to the first-launch screen where the user can paste
/// their own key.
class AppConfig {
  const AppConfig._();

  /// Key baked into the build (empty when not provided).
  static const String builtInApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Default model. The `-latest` alias always points at the current version,
  /// so it keeps working as Google retires older model names.
  static const String defaultModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-flash-latest',
  );
}
