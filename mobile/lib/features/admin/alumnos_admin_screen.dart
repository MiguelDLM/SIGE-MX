import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

// ---------- Provider ----------
final alumnosAdminProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, search) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/students/', queryParameters: {
    'page': 1,
    'size': 100,
    if (search.isNotEmpty) 'search': search,
  });
  return (resp.data['data'] as List).cast<Map<String, dynamic>>();
});

final groupsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/groups/');
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
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (alumnos) {
          if (alumnos.isEmpty) {
            return const Center(child: Text('Sin alumnos registrados'));
          }
          return ListView.separated(
            itemCount: alumnos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = alumnos[i];
              final nombre = '${a['nombre'] ?? ''} ${a['apellido_paterno'] ?? ''}'.trim();
              final matricula = a['matricula'] as String? ?? '';
              final status = a['status'] ?? 'activo';
              
              Color statusColor = Colors.green;
              if (status == 'inactivo') statusColor = Colors.grey;
              if (status == 'graduado') statusColor = Colors.blue;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Text(nombre.isNotEmpty ? nombre[0] : '?', style: TextStyle(color: statusColor)),
                ),
                title: Text(nombre),
                subtitle: Text('Mat: $matricula • ${status.toUpperCase()}'),
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

  Future<void> _showForm(BuildContext context, Map<String, dynamic>? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AlumnoDialog(existing: existing, ref: ref),
    );
    if (saved == true) ref.invalidate(alumnosAdminProvider(_search));
  }
}

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
  late final TextEditingController _emailCtrl;
  late final TextEditingController _curpCtrl;
  DateTime? _fechaNacimiento;
  String _status = 'activo';
  String? _selectedGroupId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _matriculaCtrl = TextEditingController(text: e?['matricula'] ?? '');
    _nombreCtrl = TextEditingController(text: e?['nombre'] ?? '');
    _apPaternoCtrl = TextEditingController(text: e?['apellido_paterno'] ?? '');
    _apMaternoCtrl = TextEditingController(text: e?['apellido_materno'] ?? '');
    _emailCtrl = TextEditingController(text: e?['email'] ?? '');
    _curpCtrl = TextEditingController(text: e?['curp'] ?? '');
    _status = e?['status'] ?? 'activo';
    _selectedGroupId = e?['current_group_id'];
    if (e?['fecha_nacimiento'] != null) {
      _fechaNacimiento = DateTime.parse(e!['fecha_nacimiento']);
    }
  }

  @override
  void dispose() {
    _matriculaCtrl.dispose();
    _nombreCtrl.dispose();
    _apPaternoCtrl.dispose();
    _apMaternoCtrl.dispose();
    _emailCtrl.dispose();
    _curpCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Nombre es requerido');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final dio = widget.ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'nombre': nombre,
        'apellido_paterno': _apPaternoCtrl.text.trim(),
        'apellido_materno': _apMaternoCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'curp': _curpCtrl.text.trim().toUpperCase(),
        'fecha_nacimiento': _fechaNacimiento?.toIso8601String().split('T')[0],
        'status': _status,
        'current_group_id': _selectedGroupId,
      };
      
      if (_isEdit) {
        await dio.patch('/api/v1/students/${widget.existing!['id']}', data: body);
      } else {
        body['matricula'] = _matriculaCtrl.text.trim();
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
    final groupsAsync = widget.ref.watch(groupsListProvider);

    return AlertDialog(
      title: Text(_isEdit ? 'Editar alumno' : 'Nuevo alumno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEdit) TextField(controller: _matriculaCtrl, decoration: const InputDecoration(labelText: 'Matrícula *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre(s) *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _apPaternoCtrl, decoration: const InputDecoration(labelText: 'Ap. Paterno', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _apMaternoCtrl, decoration: const InputDecoration(labelText: 'Ap. Materno', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _curpCtrl, decoration: const InputDecoration(labelText: 'CURP', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Estatus', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'activo', child: Text('ACTIVO')),
                DropdownMenuItem(value: 'inactivo', child: Text('INACTIVO')),
                DropdownMenuItem(value: 'graduado', child: Text('GRADUADO')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 12),
            groupsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error al cargar grupos'),
              data: (groups) => DropdownButtonFormField<String>(
                value: _selectedGroupId,
                decoration: const InputDecoration(labelText: 'Grupo Actual', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin grupo')),
                  ...groups.map((g) => DropdownMenuItem(value: g['id'] as String, child: Text(g['nombre'])))
                ],
                onChanged: (v) => setState(() => _selectedGroupId = v),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(_fechaNacimiento == null ? 'Fecha Nacimiento' : '${_fechaNacimiento!.toLocal()}'.split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime(2010), firstDate: DateTime(1950), lastDate: DateTime.now());
                if (d != null) setState(() => _fechaNacimiento = d);
              },
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
