import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/academic_cycle.dart';

final cyclesProvider = FutureProvider<List<AcademicCycle>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/academic-cycles/');
  return (resp.data['data'] as List)
      .map((j) => AcademicCycle.fromJson(j as Map<String, dynamic>))
      .toList();
});
