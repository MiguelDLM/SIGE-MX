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

// ---------- Constants ----------
const _turnos = ['Matutino', 'Vespertino', 'Nocturno'];

const _niveles = ['Preescolar', 'Primaria', 'Secundaria', 'Preparatoria'];

/// Max grado por nivel
const _maxGradoPorNivel = {
  'Preescolar': 3,
  'Primaria': 6,
  'Secundaria': 3,
  'Preparatoria': 3,
};

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
                leading: const CircleAvatar(
                    child: Icon(Icons.group_outlined)),
                title: Text(g.nombre),
                subtitle: Text([
                  if (g.nivel != null) g.nivel!,
                  if (g.grado != null) '${g.grado}°',
                  if (g.seccion != null) 'Sec. ${g.seccion}',
                  if (g.turno != null) g.turno!,
                ].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.people_outline),
                      tooltip: 'Alumnos',
                      onPressed: () => context.push(
                          '/admin/grupos/${g.id}/alumnos',
                          extra: g),
                    ),
                    IconButton(
                      icon: const Icon(Icons.schedule),
                      tooltip: 'Horario',
                      onPressed: () => context.push(
                          '/admin/grupos/${g.id}/horario',
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) =>
          _GrupoDialog(existing: existing, ref: ref),
    );
    if (saved == true) ref.invalidate(gruposProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Grupo g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Desactivar grupo?'),
        content: Text('Se desactivará "${g.nombre}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
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

// ---------- Dialog as StatefulWidget ----------
class _GrupoDialog extends StatefulWidget {
  final Grupo? existing;
  final WidgetRef ref;

  const _GrupoDialog({required this.ref, this.existing});

  @override
  State<_GrupoDialog> createState() => _GrupoDialogState();
}

class _GrupoDialogState extends State<_GrupoDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _seccionCtrl;
  String? _nivel;
  int? _grado;
  String? _turno;
  bool _saving = false;
  String? _error;

  int get _maxGrado => _maxGradoPorNivel[_nivel] ?? 6;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _nombreCtrl = TextEditingController(text: g?.nombre ?? '');
    _seccionCtrl = TextEditingController(text: g?.seccion ?? '');
    _nivel = g?.nivel;
    _grado = g?.grado;
    _turno = g?.turno;
    // Clamp grado if nivel changes
    if (_grado != null && _grado! > _maxGrado) _grado = null;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _seccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre es requerido');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = widget.ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'nombre': nombre,
        if (_seccionCtrl.text.trim().isNotEmpty)
          'seccion': _seccionCtrl.text.trim().toUpperCase(),
        if (_nivel != null) 'nivel': _nivel,
        if (_grado != null) 'grado': _grado,
        if (_turno != null) 'turno': _turno,
      };
      if (widget.existing == null) {
        await dio.post('/api/v1/groups/', data: body);
      } else {
        await dio.patch('/api/v1/groups/${widget.existing!.id}', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo grupo' : 'Editar grupo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre del grupo *',
                border: const OutlineInputBorder(),
                hintText: 'ej. 2°A',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            // Nivel
            DropdownButtonFormField<String?>(
              value: _nivel,
              decoration: const InputDecoration(
                labelText: 'Nivel educativo',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('—')),
                ..._niveles.map((n) =>
                    DropdownMenuItem<String?>(value: n, child: Text(n))),
              ],
              onChanged: (v) => setState(() {
                _nivel = v;
                _grado = null; // reset grado when nivel changes
              }),
            ),
            const SizedBox(height: 12),
            // Grado (dinámico según nivel)
            DropdownButtonFormField<int?>(
              value: _grado,
              decoration: const InputDecoration(
                labelText: 'Grado',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                for (int g = 1; g <= _maxGrado; g++)
                  DropdownMenuItem<int?>(value: g, child: Text('$g°')),
              ],
              onChanged: (v) => setState(() => _grado = v),
            ),
            const SizedBox(height: 12),
            // Sección
            TextField(
              controller: _seccionCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 5,
              decoration: const InputDecoration(
                labelText: 'Sección',
                border: OutlineInputBorder(),
                hintText: 'A, B, C…',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            // Turno
            DropdownButtonFormField<String?>(
              value: _turno,
              decoration: const InputDecoration(
                labelText: 'Turno',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('—')),
                ..._turnos.map((t) =>
                    DropdownMenuItem<String?>(value: t, child: Text(t))),
              ],
              onChanged: (v) => setState(() => _turno = v),
            ),
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
