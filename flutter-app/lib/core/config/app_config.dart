import 'dart:io';
import 'package:flutter/foundation.dart';

enum AuthBackend { mock, firebase }

abstract class AppConfig {
  static const AuthBackend authBackend = AuthBackend.mock;
  static const bool useMockApi = false;
  static const bool isDemoBuild = false; // Set false for production builds
  
  static const bool useLocalBackend = true;
  
  static String get localApiBaseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
  
  static const String remoteApiBaseUrl = 'https://civiclens-production-5fbb.up.railway.app'; 
  
  static String get apiBaseUrl => useLocalBackend ? localApiBaseUrl : remoteApiBaseUrl;
  static const String appName = 'CivicLens';
  static const String appVersion = '1.0.0';
}
