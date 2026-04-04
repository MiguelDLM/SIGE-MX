import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/user_summary.dart';

final usersAdminProvider = FutureProvider<List<UserSummary>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/users/');
  return (resp.data['data'] as List)
      .map((j) => UserSummary.fromJson(j as Map<String, dynamic>))
      .toList();
});
