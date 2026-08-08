import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';

import 'core/theme/app_theme.dart';

/// Root widget of the CivicLens application.
class CivicLensApp extends ConsumerWidget {
  const CivicLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    ThemeMode getThemeMode() {
      switch (themeMode) {
        case AppThemeMode.light:
          return ThemeMode.light;
        case AppThemeMode.dark:
        case AppThemeMode.field:
          return ThemeMode.dark;
        case AppThemeMode.system:
        default:
          return ThemeMode.system;
      }
    }

    ThemeData? getDarkTheme() {
      if (themeMode == AppThemeMode.field) {
        return AppTheme.field;
      }
      return AppTheme.dark;
    }

    return MaterialApp.router(
      title: 'CivicLens',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: getDarkTheme(),
      themeMode: getThemeMode(),
    );
  }
}
