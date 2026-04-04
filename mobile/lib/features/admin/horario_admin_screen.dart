import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../horario/horario_screen.dart';
import 'grupos_screen.dart';
import 'materias_screen.dart';

// Provider for group horario (admin view)
final grupoHorarioProvider =
    FutureProvider.family<List<HorarioEntry>, String>((ref, groupId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/horarios/grupo/$groupId');
  return (resp.data['data'] as List)
      .map((j) => HorarioEntry.fromJson(j as Map<String, dynamic>))
      .toList();
});

class AdminHorarioScreen extends ConsumerWidget {
  final Grupo grupo;
  const AdminHorarioScreen({super.key, required this.grupo});

  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(grupoHorarioProvider(grupo.id));
    return Scaffold(
      appBar: AppBar(title: Text('Horario — ${grupo.nombre}')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddEntry(context, ref),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(grupoHorarioProvider(grupo.id)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('Sin clases registradas'));
          }
          final byDay = <int, List<HorarioEntry>>{};
          for (final e in entries) {
            byDay.putIfAbsent(e.diaSemana, () => []).add(e);
          }
          final sortedDays = byDay.keys.toList()..sort();
          return ListView(
            children: [
              for (final day in sortedDays) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    day < _dias.length ? _dias[day] : 'Día $day',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ...byDay[day]!.map(
                  (e) => ListTile(
                    title: Text(e.subjectNombre ?? e.subjectId),
                    subtitle: Text(
                        '${e.horaInicio.substring(0, 5)}–${e.horaFin.substring(0, 5)}'
                        '${e.aula != null ? ' · ${e.aula}' : ''}'
                        '${e.teacherNombre != null ? '\n${e.teacherNombre}' : ''}'),
                    isThreeLine: e.teacherNombre != null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () => _deleteEntry(context, ref, e),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddEntry(BuildContext context, WidgetRef ref) async {
    // Load subjects and teachers
    final dio = ref.read(apiClientProvider);
    List<Materia> materias = [];
    List<Map<String, dynamic>> maestros = [];
    try {
      final ms = await dio.get('/api/v1/subjects/');
      materias = (ms.data['data'] as List)
          .map((j) => Materia.fromJson(j as Map<String, dynamic>))
          .where((m) => m.activo)
          .toList();
      final ts = await dio.get('/api/v1/teachers/');
      maestros = (ts.data['data'] as List).cast<Map<String, dynamic>>();
    } catch (_) {}

    if (!context.mounted) return;

    String? selectedMateria;
    String? selectedMaestro;
    int selectedDia = 0;
    final inicioCtrl = TextEditingController(text: '08:00');
    final finCtrl = TextEditingController(text: '09:00');
    final aulaCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Agregar clase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMateria,
                  decoration: const InputDecoration(labelText: 'Materia'),
                  items: materias
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.nombre),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => selectedMateria = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedMaestro,
                  decoration: const InputDecoration(labelText: 'Maestro'),
                  items: maestros
                      .map((m) {
                        final name =
                            '${m['nombre'] ?? ''} ${m['apellido_paterno'] ?? ''}'
                                .trim();
                        return DropdownMenuItem(
                          value: m['id'] as String,
                          child: Text(name),
                        );
                      })
                      .toList(),
                  onChanged: (v) => setState(() => selectedMaestro = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedDia,
                  decoration: const InputDecoration(labelText: 'Día'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Lunes')),
                    DropdownMenuItem(value: 1, child: Text('Martes')),
                    DropdownMenuItem(value: 2, child: Text('Miércoles')),
                    DropdownMenuItem(value: 3, child: Text('Jueves')),
                    DropdownMenuItem(value: 4, child: Text('Viernes')),
                  ],
                  onChanged: (v) => setState(() => selectedDia = v ?? 0),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: inicioCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Inicio (HH:MM)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: finCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Fin (HH:MM)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: aulaCtrl,
                  decoration: const InputDecoration(labelText: 'Aula'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: (selectedMateria == null || selectedMaestro == null)
                  ? null
                  : () async {
                      try {
                        await ref.read(apiClientProvider).post(
                          '/api/v1/horarios/',
                          data: {
                            'group_id': grupo.id,
                            'subject_id': selectedMateria,
                            'teacher_id': selectedMaestro,
                            'dia_semana': selectedDia,
                            'hora_inicio': inicioCtrl.text.trim(),
                            'hora_fin': finCtrl.text.trim(),
                            if (aulaCtrl.text.trim().isNotEmpty)
                              'aula': aulaCtrl.text.trim(),
                          },
                        );
                        Navigator.pop(ctx, true);
                      } catch (e) {
                        Navigator.pop(ctx, false);
                      }
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) ref.invalidate(grupoHorarioProvider(grupo.id));
  }

  Future<void> _deleteEntry(
      BuildContext context, WidgetRef ref, HorarioEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar clase?'),
        content: Text(
            '${e.subjectNombre ?? e.subjectId} — ${e.horaInicio.substring(0, 5)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref
            .read(apiClientProvider)
            .delete('/api/v1/horarios/${e.id}');
        ref.invalidate(grupoHorarioProvider(grupo.id));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
