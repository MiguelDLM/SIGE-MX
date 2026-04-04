import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';

// ---------- Model ----------
class HorarioEntry {
  final String id;
  final String groupId;
  final String subjectId;
  final String teacherId;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;
  final String? aula;
  final String? subjectNombre;
  final String? teacherNombre;
  final String? groupNombre;

  const HorarioEntry({
    required this.id,
    required this.groupId,
    required this.subjectId,
    required this.teacherId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    this.aula,
    this.subjectNombre,
    this.teacherNombre,
    this.groupNombre,
  });

  factory HorarioEntry.fromJson(Map<String, dynamic> j) => HorarioEntry(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        subjectId: j['subject_id'] as String,
        teacherId: j['teacher_id'] as String,
        diaSemana: j['dia_semana'] as int,
        horaInicio: j['hora_inicio'] as String,
        horaFin: j['hora_fin'] as String,
        aula: j['aula'] as String?,
        subjectNombre: j['subject_nombre'] as String?,
        teacherNombre: j['teacher_nombre'] as String?,
        groupNombre: j['group_nombre'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'dia_semana': diaSemana,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'aula': aula,
        'subject_nombre': subjectNombre,
        'teacher_nombre': teacherNombre,
        'group_nombre': groupNombre,
      };
}

// ---------- Provider ----------
final miHorarioProvider =
    FutureProvider<({List<HorarioEntry> entries, bool fromCache})>((ref) async {
  final authAsync = ref.watch(authNotifierProvider);
  final auth = authAsync.valueOrNull;
  if (auth is! AuthAuthenticated) {
    return (entries: <HorarioEntry>[], fromCache: false);
  }

  final cacheKey = 'schedule_${auth.userId}';
  final box = Hive.box<String>('settings');

  // Check connectivity
  final connectivity = await Connectivity().checkConnectivity();
  final hasNetwork = connectivity != ConnectivityResult.none;

  if (hasNetwork) {
    try {
      final dio = ref.read(apiClientProvider);
      final resp = await dio.get('/api/v1/horarios/mi-horario');
      final entries = (resp.data['data'] as List)
          .map((j) => HorarioEntry.fromJson(j as Map<String, dynamic>))
          .toList();
      // Cache result
      await box.put(cacheKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
      return (entries: entries, fromCache: false);
    } catch (_) {
      // Fall through to cache
    }
  }

  // Try cache
  final cached = box.get(cacheKey);
  if (cached != null) {
    final list = (jsonDecode(cached) as List)
        .map((j) => HorarioEntry.fromJson(j as Map<String, dynamic>))
        .toList();
    return (entries: list, fromCache: true);
  }

  return (entries: <HorarioEntry>[], fromCache: !hasNetwork);
});

// ---------- Screen ----------
class MiHorarioScreen extends ConsumerWidget {
  const MiHorarioScreen({super.key});

  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(miHorarioProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Horario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(miHorarioProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              TextButton(
                onPressed: () => ref.invalidate(miHorarioProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (result) {
          final entries = result.entries;
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Sin horario asignado'),
                  if (result.fromCache)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _OfflineBadge(),
                    ),
                ],
              ),
            );
          }

          // Group by dia_semana
          final byDay = <int, List<HorarioEntry>>{};
          for (final e in entries) {
            byDay.putIfAbsent(e.diaSemana, () => []).add(e);
          }
          final sortedDays = byDay.keys.toList()..sort();

          return Column(
            children: [
              if (result.fromCache)
                const ColoredBox(
                  color: Color(0xFFFFF3CD),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Sin conexión — mostrando horario guardado',
                            style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    for (final day in sortedDays) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          day < _dias.length ? _dias[day] : 'Día $day',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...byDay[day]!.map(
                        (e) => Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _colorForSubject(e.subjectId),
                              child: Text(
                                (e.subjectNombre ?? 'M')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(e.subjectNombre ?? e.subjectId),
                            subtitle: Text([
                              '${e.horaInicio.substring(0, 5)} – ${e.horaFin.substring(0, 5)}',
                              if (e.teacherNombre != null) e.teacherNombre!,
                              if (e.aula != null) 'Aula: ${e.aula}',
                            ].join(' · ')),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _colorForSubject(String id) {
    final colors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.purple.shade600,
      Colors.orange.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
      Colors.indigo.shade600,
    ];
    return colors[id.hashCode % colors.length];
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off, size: 14, color: Colors.orange),
        SizedBox(width: 4),
        Text('Modo sin conexión',
            style: TextStyle(color: Colors.orange, fontSize: 12)),
      ],
    );
  }
}
