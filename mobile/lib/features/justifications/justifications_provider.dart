import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/models/justification.dart';
import '../../shared/models/student.dart';

final myStudentsProvider = FutureProvider<List<Student>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/students/my');
  return (resp.data['data'] as List)
      .map((j) => Student.fromJson(j as Map<String, dynamic>))
      .toList();
});

final justificationsProvider = FutureProvider<List<Justification>>((ref) async {
  final authAsync = ref.watch(authNotifierProvider);
  final auth = authAsync.valueOrNull;
  if (auth is! AuthAuthenticated) return [];

  final dio = ref.read(apiClientProvider);
  final endpoint =
      (auth.primaryRole == 'padre' || auth.primaryRole == 'alumno')
          ? '/api/v1/justifications/my'
          : '/api/v1/justifications/';

  final resp = await dio.get(endpoint);
  return (resp.data['data'] as List)
      .map((j) => Justification.fromJson(j as Map<String, dynamic>))
      .toList();
});
