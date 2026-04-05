import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

// ---------- Provider ----------
final parentsAdminProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, search) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/users/', queryParameters: {
    'role': 'padre',
    if (search.isNotEmpty) 'search': search,
  });
  // The users endpoint returns a list of (user, roles) tuples or just user objects depending on implementation
  // Adjusting based on common patterns in this codebase
  return (resp.data['data'] as List).cast<Map<String, dynamic>>();
});

// ---------- Screen ----------
class ParentsAdminScreen extends ConsumerStatefulWidget {
  const ParentsAdminScreen({super.key});

  @override
  ConsumerState<ParentsAdminScreen> createState() => _ParentsAdminScreenState();
}

class _ParentsAdminScreenState extends ConsumerState<ParentsAdminScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentsAsync = ref.watch(parentsAdminProvider(_search));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Padres'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add_outlined),
        tooltip: 'Nuevo Padre',
        onPressed: () => _showForm(context, null),
      ),
      body: parentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (parents) {
          if (parents.isEmpty) return const Center(child: Text('Sin padres registrados'));
          return ListView.separated(
            itemCount: parents.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = parents[i];
              final nombre = '${p['nombre'] ?? ''} ${p['apellido_paterno'] ?? ''}'.trim();
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.parent_verifications)),
                title: Text(nombre),
                subtitle: Text(p['email'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.link),
                      tooltip: 'Vincular hijos',
                      onPressed: () => _showLinkHijos(context, p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showForm(context, p),
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

  Future<void> _showForm(BuildContext context, Map<String, dynamic>? existing) async {
    // This uses the UserFormScreen logic but could be a specialized dialog
    // For now, let's keep it simple with a dialog for CURP requirement
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ParentDialog(existing: existing, ref: ref),
    );
    if (saved == true) ref.invalidate(parentsAdminProvider(_search));
  }

  Future<void> _showLinkHijos(BuildContext context, Map<String, dynamic> parent) async {
    // Reusing logic from the student linking part but initiated from Parent
    await showDialog(
      context: context,
      builder: (ctx) => _LinkHijosDialog(parent: parent, ref: ref),
    );
  }
}

class _ParentDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final WidgetRef ref;
  const _ParentDialog({required this.ref, this.existing});

  @override
  State<_ParentDialog> createState() => _ParentDialogState();
}

class _ParentDialogState extends State<_ParentDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apPaternoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _curpCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombreCtrl = TextEditingController(text: e?['nombre'] ?? '');
    _apPaternoCtrl = TextEditingController(text: e?['apellido_paterno'] ?? '');
    _emailCtrl = TextEditingController(text: e?['email'] ?? '');
    _curpCtrl = TextEditingController(text: e?['curp'] ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apPaternoCtrl.dispose();
    _emailCtrl.dispose();
    _curpCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nombreCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _curpCtrl.text.isEmpty) {
      setState(() => _error = 'Nombre, Email y CURP son requeridos');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final dio = widget.ref.read(apiClientProvider);
      final body = {
        'nombre': _nombreCtrl.text.trim(),
        'apellido_paterno': _apPaternoCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'curp': _curpCtrl.text.trim().toUpperCase(),
        'roles': ['padre'],
      };
      if (widget.existing != null) {
        await dio.patch('/api/v1/users/${widget.existing!['id']}', data: body);
      } else {
        body['password'] = 'SAS12345'; // Default password
        await dio.post('/api/v1/users/', data: body);
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
      title: Text(widget.existing == null ? 'Nuevo Padre' : 'Editar Padre'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre(s) *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _apPaternoCtrl, decoration: const InputDecoration(labelText: 'Apellido Paterno', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _curpCtrl, decoration: const InputDecoration(labelText: 'CURP *', border: OutlineInputBorder())),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _LinkHijosDialog extends StatefulWidget {
  final Map<String, dynamic> parent;
  final WidgetRef ref;
  const _LinkHijosDialog({required this.parent, required this.ref});

  @override
  State<_LinkHijosDialog> createState() => _LinkHijosDialogState();
}

class _LinkHijosDialogState extends State<_LinkHijosDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Vincular hijo(s) a ${widget.parent['nombre']}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Buscar Alumno',
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _doSearch),
              ),
              onSubmitted: (_) => _doSearch(),
            ),
            const SizedBox(height: 8),
            if (_searching) const LinearProgressIndicator(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final s = _results[i];
                  return ListTile(
                    title: Text('${s['nombre']} ${s['apellido_paterno'] ?? ''}'),
                    subtitle: Text('Mat: ${s['matricula']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_link),
                      onPressed: () => _link(s),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }

  Future<void> _doSearch() async {
    setState(() => _searching = true);
    try {
      final dio = widget.ref.read(apiClientProvider);
      final resp = await dio.get('/api/v1/students/', queryParameters: {'search': _searchCtrl.text.trim()});
      setState(() {
        _results = (resp.data['data'] as List).cast<Map<String, dynamic>>();
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  Future<void> _link(Map<String, dynamic> student) async {
    try {
      final dio = widget.ref.read(apiClientProvider);
      await dio.post('/api/v1/students/${student['id']}/parents', data: {
        'user_id': widget.parent['id'],
        'parentesco': 'Padre/Madre'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vinculado con éxito')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
