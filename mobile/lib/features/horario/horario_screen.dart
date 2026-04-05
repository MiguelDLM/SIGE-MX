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
  if (auth is! AuthAuthenticated) return (entries: <HorarioEntry>[], fromCache: false);

  final cacheKey = 'schedule_${auth.userId}';
  final box = Hive.box<String>('settings');
  final connectivity = await Connectivity().checkConnectivity();
  final hasNetwork = connectivity != ConnectivityResult.none;

  if (hasNetwork) {
    try {
      final dio = ref.read(apiClientProvider);
      final resp = await dio.get('/api/v1/horarios/mi-horario');
      final entries = (resp.data['data'] as List)
          .map((j) => HorarioEntry.fromJson(j as Map<String, dynamic>))
          .toList();
      await box.put(cacheKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
      return (entries: entries, fromCache: false);
    } catch (_) {}
  }

  final cached = box.get(cacheKey);
  if (cached != null) {
    final list = (jsonDecode(cached) as List)
        .map((j) => HorarioEntry.fromJson(j as Map<String, dynamic>))
        .toList();
    return (entries: list, fromCache: true);
  }
  return (entries: <HorarioEntry>[], fromCache: false);
});

// ---------- Screen ----------
class MiHorarioScreen extends ConsumerWidget {
  const MiHorarioScreen({super.key});

  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(miHorarioProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario Escolar'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(miHorarioProvider)),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (result) {
          if (result.entries.isEmpty) {
            return const Center(child: Text('Sin clases programadas'));
          }

          // Modern table-like view
          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              if (result.fromCache)
                const Card(
                  color: Colors.amberAccent,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Modo offline: mostrando datos guardados', textAlign: TextAlign.center),
                  ),
                ),
              for (int d = 0; d < 6; d++) ...[
                _buildDaySection(context, d, result.entries.where((e) => e.diaSemana == d).toList()),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDaySection(BuildContext context, int dayIdx, List<HorarioEntry> dayEntries) {
    if (dayEntries.isEmpty) return const SizedBox.shrink();
    dayEntries.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Text(
            _dias[dayIdx].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
        for (final entry in dayEntries)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            margin: const EdgeInsets.only(bottom: 8),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 80,
                    decoration: BoxDecoration(
                      color: _colorForSubject(entry.subjectId).withOpacity(0.1),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(entry.horaInicio.substring(0, 5), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const Icon(Icons.arrow_downward, size: 12, color: Colors.grey),
                        Text(entry.horaFin.substring(0, 5), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(entry.subjectNombre ?? 'Materia', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              if (entry.aula != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: Text('Aula: ${entry.aula}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(entry.teacherNombre ?? 'Docente', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                          if (entry.groupNombre != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Grupo: ${entry.groupNombre}', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: _colorForSubject(entry.subjectId),
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _colorForSubject(String id) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    return colors[id.hashCode.abs() % colors.length];
  }
}
