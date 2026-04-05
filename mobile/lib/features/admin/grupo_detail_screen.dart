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
    final searchCtrl = TextEditingController();
    final results = ValueNotifier<List<Map<String, dynamic>>>([]);
    String? selectedStudentId;

    Future<void> doSearch() async {
      try {
        final dio = ref.read(apiClientProvider);
        final resp = await dio.get('/api/v1/students/',
            queryParameters: {'search': searchCtrl.text.trim(), 'size': 20});
        final list = (resp.data['data'] as List).cast<Map<String, dynamic>>();
        results.value = list;
      } catch (_) {}
    }

    // Load initial list
    await doSearch();

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
                      await doSearch();
                      setState(() {}); // refresh to show results
                    },
                  ),
                ),
                onSubmitted: (_) async {
                  await doSearch();
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final created = await showDialog<bool>(
                    context: ctx,
                    builder: (dCtx) => _AlumnoDialog(ref: ref),
                  );
                  if (created == true) {
                    await doSearch();
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Crear nuevo alumno'),
              ),
              const Divider(),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: results,
                builder: (_, list, __) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('Sin resultados',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return SizedBox(
                    height: 250,
                    width: double.maxFinite,
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
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Quitar alumno?'),
        content: Text('Se quitará a "${a.displayName}" del grupo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
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

// Reusing AlumnoDialog from AlumnosAdminScreen
class _AlumnoDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final WidgetRef ref;
  const _AlumnoDialog({required this.ref, this.existing});

  @override
  State<_AlumnoDialog> createState() => _AlumnoDialogState();
}

class _AlumnoDialogState extends State<_AlumnoDialog> {
  late final TextEditingController _matriculaCtrl;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apPaternoCtrl;
  late final TextEditingController _apMaternoCtrl;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _matriculaCtrl =
        TextEditingController(text: e?['matricula'] as String? ?? '');
    _nombreCtrl = TextEditingController(text: e?['nombre'] as String? ?? '');
    _apPaternoCtrl =
        TextEditingController(text: e?['apellido_paterno'] as String? ?? '');
    _apMaternoCtrl =
        TextEditingController(text: e?['apellido_materno'] as String? ?? '');
  }

  @override
  void dispose() {
    _matriculaCtrl.dispose();
    _nombreCtrl.dispose();
    _apPaternoCtrl.dispose();
    _apMaternoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nombreCtrl.text.trim();
    final matricula = _matriculaCtrl.text.trim();
    if (nombre.isEmpty || (!_isEdit && matricula.isEmpty)) {
      setState(() => _error = 'Nombre y matrícula son requeridos');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = widget.ref.read(apiClientProvider);
      if (_isEdit) {
        final body = <String, dynamic>{
          'nombre': nombre,
          if (_apPaternoCtrl.text.trim().isNotEmpty)
            'apellido_paterno': _apPaternoCtrl.text.trim(),
          if (_apMaternoCtrl.text.trim().isNotEmpty)
            'apellido_materno': _apMaternoCtrl.text.trim(),
        };
        await dio.patch('/api/v1/students/${widget.existing!['id']}',
            data: body);
      } else {
        final body = <String, dynamic>{
          'matricula': matricula,
          'nombre': nombre,
          if (_apPaternoCtrl.text.trim().isNotEmpty)
            'apellido_paterno': _apPaternoCtrl.text.trim(),
          if (_apMaternoCtrl.text.trim().isNotEmpty)
            'apellido_materno': _apMaternoCtrl.text.trim(),
        };
        await dio.post('/api/v1/students/', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar alumno' : 'Nuevo alumno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEdit)
              TextField(
                controller: _matriculaCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Matrícula *',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            if (!_isEdit) const SizedBox(height: 12),
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre(s) *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apPaternoCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Apellido paterno',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apMaternoCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Apellido materno',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null && _isEdit) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
