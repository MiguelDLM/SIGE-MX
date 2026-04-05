import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

// ---------- Model ----------
class Materia {
  final String id;
  final String nombre;
  final String? clave;
  final int? horasSemana;
  final int? grado;
  final bool activo;

  const Materia({
    required this.id,
    required this.nombre,
    this.clave,
    this.horasSemana,
    this.grado,
    this.activo = true,
  });

  factory Materia.fromJson(Map<String, dynamic> j) => Materia(
        id: j['id'] as String,
        nombre: j['nombre'] as String? ?? '',
        clave: j['clave'] as String?,
        horasSemana: j['horas_semana'] as int?,
        grado: j['grado'] as int?,
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
          // Group by grado for display
          final byGrado = <int?, List<Materia>>{};
          for (final m in active) {
            byGrado.putIfAbsent(m.grado, () => []).add(m);
          }
          final sortedGrados = byGrado.keys.toList()
            ..sort((a, b) => (a ?? 99).compareTo(b ?? 99));

          return ListView(
            children: [
              for (final grado in sortedGrados) ...[
                _GradoHeader(grado: grado),
                ...byGrado[grado]!.map(
                  (m) => ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.book_outlined, size: 18)),
                    title: Text(m.nombre),
                    subtitle: Text([
                      if (m.clave != null) m.clave!,
                      if (m.horasSemana != null) '${m.horasSemana}h/sem',
                    ].join(' · ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showForm(context, ref, m),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _confirmDelete(context, ref, m),
                        ),
                      ],
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

  Future<void> _showForm(
      BuildContext context, WidgetRef ref, Materia? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      // Use dialogContext — NOT the outer context — for Navigator.pop
      builder: (dialogCtx) => _MateriaDialog(
        existing: existing,
        ref: ref,
        dialogCtx: dialogCtx,
      ),
    );
    if (saved == true) ref.invalidate(materiasProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Materia m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Desactivar materia?'),
        content: Text('Se desactivará "${m.nombre}".'),
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

// ---------- Grado header ----------
class _GradoHeader extends StatelessWidget {
  final int? grado;
  const _GradoHeader({required this.grado});

  @override
  Widget build(BuildContext context) {
    final label = grado == null ? 'Sin grado específico' : 'Grado $grado°';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ---------- Dialog as StatefulWidget para controlar su propio contexto ----------
class _MateriaDialog extends StatefulWidget {
  final Materia? existing;
  final WidgetRef ref;
  final BuildContext dialogCtx;

  const _MateriaDialog({
    required this.ref,
    required this.dialogCtx,
    this.existing,
  });

  @override
  State<_MateriaDialog> createState() => _MateriaDialogState();
}

class _MateriaDialogState extends State<_MateriaDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _claveCtrl;
  int? _horas;
  int? _grado;
  bool _saving = false;
  String? _error;

  static const _maxGrado = 6;

  @override
  void initState() {
    super.initState();
    _nombreCtrl =
        TextEditingController(text: widget.existing?.nombre ?? '');
    _claveCtrl =
        TextEditingController(text: widget.existing?.clave ?? '');
    _horas = widget.existing?.horasSemana;
    _grado = widget.existing?.grado;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _claveCtrl.dispose();
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
        if (_claveCtrl.text.trim().isNotEmpty) 'clave': _claveCtrl.text.trim(),
        if (_horas != null) 'horas_semana': _horas,
        'grado': _grado,
      };
      if (widget.existing == null) {
        await dio.post('/api/v1/subjects/', data: body);
      } else {
        await dio.patch('/api/v1/subjects/${widget.existing!.id}', data: body);
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
      title: Text(widget.existing == null ? 'Nueva materia' : 'Editar materia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nombre *',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _claveCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Clave (ej. MAT1)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Grado dropdown
            DropdownButtonFormField<int?>(
              value: _grado,
              decoration: const InputDecoration(
                labelText: 'Grado',
                border: OutlineInputBorder(),
                helperText: 'Grado escolar al que pertenece esta materia',
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sin grado específico'),
                ),
                for (int g = 1; g <= _maxGrado; g++)
                  DropdownMenuItem<int?>(
                    value: g,
                    child: Text('$g° grado'),
                  ),
              ],
              onChanged: (v) => setState(() => _grado = v),
            ),
            const SizedBox(height: 12),
            // Horas/semana dropdown
            DropdownButtonFormField<int?>(
              value: _horas,
              decoration: const InputDecoration(
                labelText: 'Horas por semana',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('—')),
                for (int h = 1; h <= 10; h++)
                  DropdownMenuItem<int?>(
                      value: h, child: Text('$h ${h == 1 ? 'hora' : 'horas'}')),
              ],
              onChanged: (v) => setState(() => _horas = v),
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
