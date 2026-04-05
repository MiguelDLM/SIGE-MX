import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/auth_interceptor.dart';
import '../storage/secure_storage.dart';
import 'auth_state.dart';

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState> {
  String? lastEmail;
  String? lastPassword;

  @override
  Future<AuthState> build() async {
    ref.read(authInterceptorProvider).onLogout = _handleLogout;
    return _init();
  }

  Future<AuthState> _init() async {
    final storage = ref.read(secureStorageProvider);
    final accessToken = await storage.getAccessToken();
    if (accessToken == null) return const AuthUnauthenticated();
    try {
      final refreshToken = await storage.getRefreshToken();
      final dio = ref.read(apiClientProvider);
      final response = await dio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      await storage.saveTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      return _parseToken(data['access_token'] as String);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Refresh token is invalid/expired — force re-login
        await storage.clearTokens();
        return const AuthUnauthenticated();
      }
      // Network or server error: keep the stored token and stay logged in
      return _parseToken(accessToken);
    } catch (_) {
      // Unexpected error (e.g. parse failure): keep token, don't log out
      return _parseToken(accessToken);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(apiClientProvider);
      final storage = ref.read(secureStorageProvider);
      final response = await dio.post(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      await storage.saveTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      lastEmail = email;
      lastPassword = password;
      state = AsyncData(_parseToken(data['access_token'] as String));
    } catch (e, st) {
      state = const AsyncData(AuthUnauthenticated());
      throw e;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken =
          await ref.read(secureStorageProvider).getRefreshToken();
      await ref.read(apiClientProvider).post(
        '/api/v1/auth/logout',
        data: {'refresh_token': refreshToken ?? ''},
      );
    } catch (_) {}
    await ref.read(secureStorageProvider).clearTokens();
    lastEmail = null;
    lastPassword = null;
    state = const AsyncData(AuthUnauthenticated());
  }

  void _handleLogout() {
    ref.read(secureStorageProvider).clearTokens();
    lastEmail = null;
    lastPassword = null;
    state = const AsyncData(AuthUnauthenticated());
  }

  static AuthState _parseToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return const AuthUnauthenticated();
    final padded = base64Url.normalize(parts[1]);
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
    final userId = payload['sub'] as String? ?? '';
    final roles = (payload['roles'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final mustChange = payload['must_change_password'] as bool? ?? false;
    return AuthAuthenticated(
      userId: userId,
      roles: roles,
      primaryRole: roles.isNotEmpty ? roles.first : '',
      mustChangePassword: mustChange,
    );
  }
}
