/// API base URL. Override with:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);
