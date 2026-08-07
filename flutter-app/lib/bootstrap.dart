import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/mock_infrastructure_api.dart';
import 'core/config/app_config.dart';

/// Bootstrap function — initialises the app, seeds mock data, returns a ProviderContainer.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate mock API to trigger seed data construction if in demo/mock mode.
  // The MockInfrastructureApi constructor calls _seedData() internally.
  if (AppConfig.useMockApi) {
    MockInfrastructureApi();
  }

  final container = ProviderContainer();
  return container;
}
