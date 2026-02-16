class Environment {
  /// Set via `flutter run --dart-define=API_URL=<url>`
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );
}
