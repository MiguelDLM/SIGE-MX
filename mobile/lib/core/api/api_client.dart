import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_config.dart';
import 'auth_interceptor.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final serverUrl = ref.watch(serverUrlProvider);
  final baseUrl = serverUrl ?? 'http://10.0.2.2:8000';

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final interceptor = ref.read(authInterceptorProvider);
  dio.interceptors.add(interceptor);
  return dio;
});
