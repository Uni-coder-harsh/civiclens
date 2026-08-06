import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../database/app_database.dart';
import 'infrastructure_api.dart';
import 'mock_infrastructure_api.dart';
import 'remote_infrastructure_api.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final apiClientProvider = Provider<InfrastructureApi>((ref) {
  return AppConfig.useMockApi
      ? MockInfrastructureApi()
      : RemoteInfrastructureApi(dio: ref.watch(dioProvider));
});
