import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/evaluation.dart';
import '../../shared/models/grade.dart';

// Evaluations for a group (docente)
final groupEvaluationsProvider =
    FutureProvider.family<List<Evaluation>, String>((ref, groupId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get(
    '/api/v1/grades/evaluations/',
    queryParameters: {'group_id': groupId},
  );
  return (resp.data['data'] as List)
      .map((j) => Evaluation.fromJson(j as Map<String, dynamic>))
      .toList();
});

// Grades for a student
final studentGradesProvider =
    FutureProvider.family<List<Grade>, String>((ref, studentId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/grades/student/$studentId');
  return (resp.data['data'] as List)
      .map((j) => Grade.fromJson(j as Map<String, dynamic>))
      .toList();
});
