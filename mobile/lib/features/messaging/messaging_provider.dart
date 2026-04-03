import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/message.dart';
import '../../shared/models/user_summary.dart';

final inboxProvider = FutureProvider<List<Message>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/messages/inbox');
  return (resp.data['data'] as List)
      .map((j) => Message.fromJson(j as Map<String, dynamic>))
      .toList();
});

final sentProvider = FutureProvider<List<Message>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/messages/sent');
  return (resp.data['data'] as List)
      .map((j) => Message.fromJson(j as Map<String, dynamic>))
      .toList();
});

final usersProvider = FutureProvider.family<List<UserSummary>, String?>(
    (ref, role) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get(
    '/api/v1/users/',
    queryParameters: role != null ? {'role': role} : null,
  );
  return (resp.data['data'] as List)
      .map((j) => UserSummary.fromJson(j as Map<String, dynamic>))
      .toList();
});

final unreadCountProvider = Provider<int>((ref) {
  final inbox = ref.watch(inboxProvider);
  return inbox.valueOrNull?.where((m) => !m.read).length ?? 0;
});
