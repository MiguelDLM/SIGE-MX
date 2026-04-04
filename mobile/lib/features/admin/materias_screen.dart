import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

// ---------- Model ----------
class Materia {
  final String id;
  final String nombre;
  final String? clave;
  final int? horasSemana;
  final bool activo;

  const Materia({
    required this.id,
    required this.nombre,
    this.clave,
    this.horasSemana,
    this.activo = true,
  });

  factory Materia.fromJson(Map<String, dynamic> j) => Materia(
        id: j['id'] as String,
        nombre: j['nombre'] as String? ?? '',
        clave: j['clave'] as String?,
        horasSemana: j['horas_semana'] as int?,
        activo: j['activo'] as bool? ?? true,
      );
}

// ---------- Provider ----------
final materiasProvider = FutureProvider<List<Materia>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/subjects/');
  return (resp.data['data'] as List)
      .map((j) => Materia.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---------- Screen ----------
class AdminMateriasScreen extends ConsumerWidget {
  const AdminMateriasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(materiasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Materias')),
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
                onPressed: () => ref.invalidate(materiasProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (items) {
          final active = items.where((m) => m.activo).toList();
          if (active.isEmpty) {
            return const Center(child: Text('Sin materias registradas'));
          }
          return ListView.separated(
            itemCount: active.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = active[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.book_outlined)),
                title: Text(m.nombre),
                subtitle: m.clave != null ? Text(m.clave!) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showForm(context, ref, m),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(context, ref, m),
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
      BuildContext context, WidgetRef ref, Materia? existing) async {
    final nombreCtrl =
        TextEditingController(text: existing?.nombre ?? '');
    final claveCtrl = TextEditingController(text: existing?.clave ?? '');
    final horasCtrl = TextEditingController(
        text: existing?.horasSemana?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Nueva materia' : 'Editar materia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: claveCtrl,
              decoration: const InputDecoration(labelText: 'Clave'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: horasCtrl,
              decoration: const InputDecoration(labelText: 'Horas/semana'),
              keyboardType: TextInputType.number,
            ),
          ],
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
                if (claveCtrl.text.trim().isNotEmpty)
                  'clave': claveCtrl.text.trim(),
                if (horasCtrl.text.trim().isNotEmpty)
                  'horas_semana': int.tryParse(horasCtrl.text.trim()),
              };
              try {
                if (existing == null) {
                  await dio.post('/api/v1/subjects/', data: body);
                } else {
                  await dio.patch('/api/v1/subjects/${existing.id}',
                      data: body);
                }
                Navigator.pop(context, true);
              } catch (e) {
                Navigator.pop(context, false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true) ref.invalidate(materiasProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Materia m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Desactivar materia?'),
        content: Text('Se desactivará "${m.nombre}".'),
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
        await ref.read(apiClientProvider).delete('/api/v1/subjects/${m.id}');
        ref.invalidate(materiasProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
