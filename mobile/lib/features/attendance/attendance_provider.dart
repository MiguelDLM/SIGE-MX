import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/models/group.dart';
import '../../shared/models/student.dart';

// Groups for the current docente
final teacherGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final authAsync = ref.watch(authNotifierProvider);
  final auth = authAsync.valueOrNull;
  if (auth is! AuthAuthenticated) return [];
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get(
    '/api/v1/groups/',
    queryParameters: {'teacher_id': auth.userId},
  );
  return (resp.data['data'] as List)
      .map((j) => Group.fromJson(j as Map<String, dynamic>))
      .toList();
});

// Students for a specific group
final groupStudentsProvider =
    FutureProvider.family<List<Student>, String>((ref, groupId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/groups/$groupId/students');
  return (resp.data['data'] as List)
      .map((j) => Student.fromJson(j as Map<String, dynamic>))
      .toList();
});

// Attendance records for a student (padre/alumno view)
final studentAttendanceProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, studentId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/attendance/student/$studentId');
  return (resp.data['data'] as List).cast<Map<String, dynamic>>();
});
