import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';

// ---------- Model ----------
class Grupo {
  final String id;
  final String nombre;
  final int? grado;
  final String? seccion;
  final String? nivel;
  final String? turno;
  final String? cicloId;
  final bool activo;

  const Grupo({
    required this.id,
    required this.nombre,
    this.grado,
    this.seccion,
    this.nivel,
    this.turno,
    this.cicloId,
    this.activo = true,
  });

  factory Grupo.fromJson(Map<String, dynamic> j) => Grupo(
        id: j['id'] as String,
        nombre: j['nombre'] as String? ?? '',
        grado: j['grado'] as int?,
        seccion: j['seccion'] as String?,
        nivel: j['nivel'] as String?,
        turno: j['turno'] as String?,
        cicloId: j['ciclo_id'] as String?,
        activo: j['activo'] as bool? ?? true,
      );
}

// ---------- Provider ----------
final gruposProvider = FutureProvider<List<Grupo>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/groups/');
  return (resp.data['data'] as List)
      .map((j) => Grupo.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---------- Screen ----------
class AdminGruposScreen extends ConsumerWidget {
  const AdminGruposScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gruposProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Grupos')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(context, ref, null),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              TextButton(
                onPressed: () => ref.invalidate(gruposProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (items) {
          final active = items.where((g) => g.activo).toList();
          if (active.isEmpty) {
            return const Center(child: Text('Sin grupos registrados'));
          }
          return ListView.separated(
            itemCount: active.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final g = active[i];
              return ListTile(
                leading:
                    const CircleAvatar(child: Icon(Icons.group_outlined)),
                title: Text(g.nombre),
                subtitle: Text([
                  if (g.nivel != null) g.nivel!,
                  if (g.turno != null) g.turno!,
                ].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.people_outline),
                      tooltip: 'Alumnos',
                      onPressed: () =>
                          context.push('/admin/grupos/${g.id}/alumnos',
                              extra: g),
                    ),
                    IconButton(
                      icon: const Icon(Icons.schedule),
                      tooltip: 'Horario',
                      onPressed: () =>
                          context.push('/admin/grupos/${g.id}/horario',
                              extra: g),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showForm(context, ref, g),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () => _confirmDelete(context, ref, g),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showForm(
      BuildContext context, WidgetRef ref, Grupo? existing) async {
    final nombreCtrl =
        TextEditingController(text: existing?.nombre ?? '');
    final gradoCtrl =
        TextEditingController(text: existing?.grado?.toString() ?? '');
    final seccionCtrl =
        TextEditingController(text: existing?.seccion ?? '');
    final nivelCtrl =
        TextEditingController(text: existing?.nivel ?? '');
    final turnoCtrl =
        TextEditingController(text: existing?.turno ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Nuevo grupo' : 'Editar grupo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gradoCtrl,
                decoration: const InputDecoration(labelText: 'Grado'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: seccionCtrl,
                decoration: const InputDecoration(labelText: 'Sección (A, B…)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nivelCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nivel (primaria, secundaria…)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: turnoCtrl,
                decoration:
                    const InputDecoration(labelText: 'Turno (matutino…)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              if (nombre.isEmpty) return;
              final dio = ref.read(apiClientProvider);
              final body = {
                'nombre': nombre,
                if (gradoCtrl.text.trim().isNotEmpty)
                  'grado': int.tryParse(gradoCtrl.text.trim()),
                if (seccionCtrl.text.trim().isNotEmpty)
                  'seccion': seccionCtrl.text.trim(),
                if (nivelCtrl.text.trim().isNotEmpty)
                  'nivel': nivelCtrl.text.trim(),
                if (turnoCtrl.text.trim().isNotEmpty)
                  'turno': turnoCtrl.text.trim(),
              };
              try {
                if (existing == null) {
                  await dio.post('/api/v1/groups/', data: body);
                } else {
                  await dio.patch('/api/v1/groups/${existing.id}', data: body);
                }
                Navigator.pop(context, true);
              } catch (e) {
                Navigator.pop(context, false);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true) ref.invalidate(gruposProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Grupo g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Desactivar grupo?'),
        content: Text('Se desactivará "${g.nombre}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(apiClientProvider).delete('/api/v1/groups/${g.id}');
        ref.invalidate(gruposProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
