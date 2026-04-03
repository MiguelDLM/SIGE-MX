import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/event.dart';

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/events/');
  return (resp.data['data'] as List)
      .map((j) => Event.fromJson(j as Map<String, dynamic>))
      .toList();
});
