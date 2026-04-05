import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

// ---------- Provider ----------
final alumnosAdminProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, search) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/students/', queryParameters: {
    'page': 1,
    'size': 50,
    if (search.isNotEmpty) 'search': search,
  });
  return (resp.data['data'] as List).cast<Map<String, dynamic>>();
});

// ---------- Screen ----------
class AlumnosAdminScreen extends ConsumerStatefulWidget {
  const AlumnosAdminScreen({super.key});

  @override
  ConsumerState<AlumnosAdminScreen> createState() => _AlumnosAdminScreenState();
}

class _AlumnosAdminScreenState extends ConsumerState<AlumnosAdminScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alumnosAsync = ref.watch(alumnosAdminProvider(_search));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de alumnos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o matrícula',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add_outlined),
        onPressed: () => _showForm(context, null),
      ),
      body: alumnosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              TextButton(
                onPressed: () => ref.invalidate(alumnosAdminProvider(_search)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (alumnos) {
          if (alumnos.isEmpty) {
            return Center(
              child: Text(_search.isEmpty
                  ? 'Sin alumnos registrados'
                  : 'Sin resultados para "$_search"'),
            );
          }
          return ListView.separated(
            itemCount: alumnos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = alumnos[i];
              final nombre = '${a['nombre'] ?? ''} ${a['apellido_paterno'] ?? ''}'.trim();
              final matricula = a['matricula'] as String? ?? '';
              return ListTile(
                leading: CircleAvatar(
                  child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?'),
                ),
                title: Text(nombre.isEmpty ? '(Sin nombre)' : nombre),
                subtitle: matricula.isNotEmpty ? Text('Mat: $matricula') : null,
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showForm(context, a),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showForm(
      BuildContext context, Map<String, dynamic>? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _AlumnoDialog(existing: existing, ref: ref),
    );
    if (saved == true) ref.invalidate(alumnosAdminProvider(_search));
  }
}

// ---------- Dialog ----------
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
    _matriculaCtrl = TextEditingController(text: e?['matricula'] as String? ?? '');
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
    setState(() { _saving = true; _error = null; });
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
        await dio.patch('/api/v1/students/${widget.existing!['id']}', data: body);
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
              decoration: InputDecoration(
                labelText: 'Nombre(s) *',
                border: const OutlineInputBorder(),
                errorText: _isEdit ? null : null,
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
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
