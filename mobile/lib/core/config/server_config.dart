import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _kServerUrl = 'server_url';

final serverUrlProvider = StateNotifierProvider<ServerUrlNotifier, String?>((ref) {
  final box = Hive.box<String>('settings');
  return ServerUrlNotifier(box);
});

class ServerUrlNotifier extends StateNotifier<String?> {
  final Box<String> _box;

  ServerUrlNotifier(this._box) : super(_box.get(_kServerUrl));

  Future<void> setUrl(String url) async {
    final normalized =
        url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await _box.put(_kServerUrl, normalized);
    state = normalized;
  }

  Future<void> clearUrl() async {
    await _box.delete(_kServerUrl);
    state = null;
  }
}
