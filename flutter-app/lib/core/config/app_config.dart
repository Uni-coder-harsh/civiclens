enum AuthBackend { mock, firebase }

abstract class AppConfig {
  static const AuthBackend authBackend = AuthBackend.mock;
  static const bool useMockApi = true;
  static const bool isDemoBuild = true; // Set false for production builds
  static const String apiBaseUrl = 'https://api.civiclens.gov.in';
  static const String appName = 'CivicLens';
  static const String appVersion = '1.0.0';
}
