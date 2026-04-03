import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(ref.read(secureStorageProvider));
});

class AuthInterceptor extends QueuedInterceptorsWrapper {
  final SecureStorage _storage;
  void Function()? onLogout;

  AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) throw Exception('No refresh token');

      final refreshDio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
      final response = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      await _storage.saveTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      err.requestOptions.headers['Authorization'] =
          'Bearer ${data['access_token']}';
      final retried = await refreshDio.fetch(err.requestOptions);
      handler.resolve(retried);
    } catch (_) {
      onLogout?.call();
      handler.next(err);
    }
  }
}
