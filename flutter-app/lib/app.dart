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

    ThemeData getTheme() {
      switch (themeMode) {
        case AppThemeMode.light:
          return AppTheme.light;
        case AppThemeMode.dark:
          return AppTheme.dark;
        case AppThemeMode.field:
          return AppTheme.field;
      }
    }

    return MaterialApp.router(
      title: 'CivicLens',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: getTheme(),
    );
  }
}
