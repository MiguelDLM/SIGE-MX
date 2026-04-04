import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'grupos_screen.dart';

// ---------- Student in group model ----------
class AlumnoEnGrupo {
  final String id;
  final String nombre;
  final String? apellidoPaterno;
  final String? matricula;

  const AlumnoEnGrupo({
    required this.id,
    required this.nombre,
    this.apellidoPaterno,
    this.matricula,
  });

  factory AlumnoEnGrupo.fromJson(Map<String, dynamic> j) => AlumnoEnGrupo(
        id: j['id'] as String,
        nombre: j['nombre'] as String? ?? '',
        apellidoPaterno: j['apellido_paterno'] as String?,
        matricula: j['matricula'] as String?,
      );

  String get displayName =>
      [nombre, apellidoPaterno].where((s) => s != null && s.isNotEmpty).join(' ');
}

// ---------- Provider ----------
final alumnosEnGrupoProvider =
    FutureProvider.family<List<AlumnoEnGrupo>, String>((ref, groupId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/groups/$groupId/students');
  return (resp.data['data'] as List)
      .map((j) => AlumnoEnGrupo.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---------- Screen ----------
class GrupoDetailScreen extends ConsumerWidget {
  final Grupo grupo;
  const GrupoDetailScreen({super.key, required this.grupo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alumnosEnGrupoProvider(grupo.id));
    return Scaffold(
      appBar: AppBar(title: Text('Alumnos — ${grupo.nombre}')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Agregar alumno'),
        onPressed: () => _showAddStudent(context, ref),
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
                    ref.invalidate(alumnosEnGrupoProvider(grupo.id)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (alumnos) {
          if (alumnos.isEmpty) {
            return const Center(child: Text('Sin alumnos en este grupo'));
          }
          return ListView.separated(
            itemCount: alumnos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = alumnos[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(a.nombre.isNotEmpty ? a.nombre[0] : '?'),
                ),
                title: Text(a.displayName),
                subtitle:
                    a.matricula != null ? Text('Mat: ${a.matricula}') : null,
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  tooltip: 'Quitar del grupo',
                  onPressed: () => _removeStudent(context, ref, a),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddStudent(BuildContext context, WidgetRef ref) async {
    // Search for students by matricula or name
    final searchCtrl = TextEditingController();
    final results = ValueNotifier<List<Map<String, dynamic>>>([]);
    String? selectedStudentId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Agregar alumno al grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Buscar por nombre o matrícula',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      try {
                        final dio = ref.read(apiClientProvider);
                        final resp = await dio.get('/api/v1/students/',
                            queryParameters: {
                              'search': searchCtrl.text.trim()
                            });
                        final list = (resp.data['data'] as List)
                            .cast<Map<String, dynamic>>();
                        setState(() => results.value = list);
                      } catch (_) {}
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: results,
                builder: (_, list, __) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  return SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final s = list[i];
                        final sId = s['id'] as String;
                        final name =
                            '${s['nombre'] ?? ''} ${s['apellido_paterno'] ?? ''}'
                                .trim();
                        return RadioListTile<String>(
                          title: Text(name),
                          subtitle: Text(s['matricula'] as String? ?? ''),
                          value: sId,
                          groupValue: selectedStudentId,
                          onChanged: (v) =>
                              setState(() => selectedStudentId = v),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selectedStudentId == null
                  ? null
                  : () async {
                      try {
                        await ref.read(apiClientProvider).post(
                          '/api/v1/groups/${grupo.id}/students',
                          data: {'student_id': selectedStudentId},
                        );
                        Navigator.pop(ctx);
                        ref.invalidate(alumnosEnGrupoProvider(grupo.id));
                      } catch (e) {
                        Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeStudent(
      BuildContext context, WidgetRef ref, AlumnoEnGrupo a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Quitar alumno?'),
        content: Text('Se quitará a "${a.displayName}" del grupo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref
            .read(apiClientProvider)
            .delete('/api/v1/groups/${grupo.id}/students/${a.id}');
        ref.invalidate(alumnosEnGrupoProvider(grupo.id));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
