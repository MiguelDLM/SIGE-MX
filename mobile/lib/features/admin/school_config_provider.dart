import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

class SchoolConfig {
  final String? nombre;
  final String? cct;
  final String? turno;
  final String? direccion;

  const SchoolConfig({this.nombre, this.cct, this.turno, this.direccion});

  factory SchoolConfig.fromJson(Map<String, dynamic> json) => SchoolConfig(
        nombre: json['nombre'] as String?,
        cct: json['cct'] as String?,
        turno: json['turno'] as String?,
        direccion: json['direccion'] as String?,
      );
}

final schoolConfigProvider = FutureProvider<SchoolConfig>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/config/');
  return SchoolConfig.fromJson(resp.data['data'] as Map<String, dynamic>);
});
