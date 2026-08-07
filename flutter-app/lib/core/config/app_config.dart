enum AuthBackend { mock, firebase }

abstract class AppConfig {
      static const AuthBackend authBackend = AuthBackend.mock;
      

      static const bool useMockApi = false;
  static const bool isDemoBuild = false; // Set false for production builds
  
  // Set to true for local development, false to use your deployed Railway backend
  static const bool useLocalBackend = false;
  
  static const String localApiBaseUrl = 'http://localhost:8000';
  static const String remoteApiBaseUrl = 'https://civiclens-production-5fbb.up.railway.app'; 
  
  static String get apiBaseUrl => useLocalBackend ? localApiBaseUrl : remoteApiBaseUrl;
  static const String appName = 'CivicLens';
  static const String appVersion = '1.0.0';
    }
