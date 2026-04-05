import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../horario/horario_screen.dart';

// ---------- Model ----------
class TeacherModel {
  final String id;
  final String nombre;
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final String? especialidad;
  final String? numeroEmpleado;
  final String? email;
  final String? curp;
  final String? fechaNacimiento;

  const TeacherModel({
    required this.id,
    required this.nombre,
    this.apellidoPaterno,
    this.apellidoMaterno,
    this.especialidad,
    this.numeroEmpleado,
    this.email,
    this.curp,
    this.fechaNacimiento,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> j) => TeacherModel(
        id: j['id'] as String,
        nombre: j['nombre'] as String? ?? '',
        apellidoPaterno: j['apellido_paterno'] as String?,
        apellidoMaterno: j['apellido_materno'] as String?,
        especialidad: j['especialidad'] as String?,
        numeroEmpleado: j['numero_empleado'] as String?,
        email: j['email'] as String?,
        curp: j['curp'] as String?,
        fechaNacimiento: j['fecha_nacimiento'] as String?,
      );

  String get displayName =>
      [nombre, apellidoPaterno, apellidoMaterno].where((s) => s != null && s!.isNotEmpty).join(' ');
}

// ---------- Providers ----------
final maestrosAdminProvider = FutureProvider<List<TeacherModel>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/teachers/');
  return (resp.data['data'] as List)
      .map((j) => TeacherModel.fromJson(j as Map<String, dynamic>))
      .toList();
});

final maestroHorarioProvider =
    FutureProvider.family<List<HorarioEntry>, String>((ref, teacherId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/horarios/maestro/$teacherId');
  return (resp.data['data'] as List)
      .map((j) => HorarioEntry.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---------- Main Screen ----------
class MaestrosAdminScreen extends ConsumerWidget {
  const MaestrosAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(maestrosAdminProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de maestros')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add_outlined),
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
                onPressed: () => ref.invalidate(maestrosAdminProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (teachers) {
          if (teachers.isEmpty) {
            return const Center(child: Text('Sin maestros registrados'));
          }
          return ListView.separated(
            itemCount: teachers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = teachers[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(t.nombre.isNotEmpty ? t.nombre[0].toUpperCase() : '?'),
                ),
                title: Text(t.displayName),
                subtitle: Text([
                  if (t.especialidad != null) t.especialidad!,
                  if (t.numeroEmpleado != null) 'Emp: ${t.numeroEmpleado}',
                ].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_link_outlined),
                      tooltip: 'Asignar a grupo/materia',
                      onPressed: () => _showAssignmentForm(context, ref, t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.schedule_outlined),
                      tooltip: 'Ver horario',
                      onPressed: () => _showHorario(context, ref, t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showForm(context, ref, t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(context, ref, t),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, TeacherModel teacher) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar permanente?'),
        content: Text('Se eliminará al docente "${teacher.displayName}" y todos sus registros.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        final dio = ref.read(apiClientProvider);
        await dio.delete('/api/v1/teachers/${teacher.id}');
        ref.invalidate(maestrosAdminProvider);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showAssignmentForm(
      BuildContext context, WidgetRef ref, TeacherModel teacher) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) => _AssignTeacherDialog(teacher: teacher, ref: ref),
    );
    ref.invalidate(maestroHorarioProvider(teacher.id));
  }

  Future<void> _showForm(
      BuildContext context, WidgetRef ref, TeacherModel? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _MaestroDialog(existing: existing, ref: ref),
    );
    if (saved == true) ref.invalidate(maestrosAdminProvider);
  }

  Future<void> _showHorario(
      BuildContext context, WidgetRef ref, TeacherModel teacher) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) =>
          _MaestroHorarioDialog(teacher: teacher, ref: ref),
    );
  }
}

// ---------- Assignment Dialog ----------
class _AssignTeacherDialog extends StatefulWidget {
  final TeacherModel teacher;
  final WidgetRef ref;
  const _AssignTeacherDialog({required this.teacher, required this.ref});

  @override
  State<_AssignTeacherDialog> createState() => _AssignTeacherDialogState();
}

class _AssignTeacherDialogState extends State<_AssignTeacherDialog> {
  String? _selectedGroupId;
  String? _selectedSubjectId;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final dio = widget.ref.read(apiClientProvider);
      final resG = await dio.get('/api/v1/groups/');
      final resS = await dio.get('/api/v1/subjects/');
      if (mounted) {
        setState(() {
          _groups = (resG.data['data'] as List).cast<Map<String, dynamic>>();
          _subjects = (resS.data['data'] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al cargar datos: $e');
    }
  }

  Future<void> _save() async {
    if (_selectedGroupId == null || _selectedSubjectId == null) {
      setState(() => _error = 'Selecciona grupo y materia');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = widget.ref.read(apiClientProvider);
      await dio.post('/api/v1/groups/$_selectedGroupId/teachers', data: {
        'teacher_id': widget.teacher.id,
        'subject_id': _selectedSubjectId,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Asignar — ${widget.teacher.displayName}'),
      content: _loading
          ? const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Grupo',
                      border: OutlineInputBorder(),
                    ),
                    items: _groups
                        .map((g) => DropdownMenuItem(
                              value: g['id'] as String,
                              child: Text(g['nombre'] as String? ?? 'Sin nombre'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedGroupId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedSubjectId,
                    decoration: const InputDecoration(
                      labelText: 'Materia',
                      border: OutlineInputBorder(),
                    ),
                    items: _subjects
                        .map((s) => DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text(s['nombre'] as String? ?? 'Sin nombre'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSubjectId = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading || _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Asignar'),
        ),
      ],
    );
  }
}

// ---------- Horario Dialog ----------
class _MaestroHorarioDialog extends StatelessWidget {
  final TeacherModel teacher;
  final WidgetRef ref;
  const _MaestroHorarioDialog({required this.teacher, required this.ref});

  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(maestroHorarioProvider(teacher.id));
    return AlertDialog(
      title: Text('Horario — ${teacher.displayName}'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: async.when(
          loading: () =>
              const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: $e'),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin clases asignadas'),
              );
            }
            final byDay = <int, List<HorarioEntry>>{};
            for (final e in entries) {
              byDay.putIfAbsent(e.diaSemana, () => []).add(e);
            }
            final sortedDays = byDay.keys.toList()..sort();
            return ListView(
              shrinkWrap: true,
              children: [
                for (final day in sortedDays) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                    child: Text(
                      day < _dias.length ? _dias[day] : 'Día $day',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  ...byDay[day]!.map((e) => ListTile(
                        dense: true,
                        title: Text(e.subjectNombre ?? e.subjectId),
                        subtitle: Text(
                          '${e.horaInicio.substring(0, 5)}–${e.horaFin.substring(0, 5)}'
                          '${e.groupNombre != null ? ' · ${e.groupNombre}' : ''}'
                          '${e.aula != null ? ' · ${e.aula}' : ''}',
                        ),
                      )),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ---------- Create/Edit Dialog ----------
class _MaestroDialog extends StatefulWidget {
  final TeacherModel? existing;
  final WidgetRef ref;
  const _MaestroDialog({required this.ref, this.existing});

  @override
  State<_MaestroDialog> createState() => _MaestroDialogState();
}

class _MaestroDialogState extends State<_MaestroDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apPaternoCtrl;
  late final TextEditingController _apMaternoCtrl;
  late final TextEditingController _empleadoCtrl;
  late final TextEditingController _especialidadCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _curpCtrl;
  DateTime? _fechaNacimiento;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombreCtrl = TextEditingController(text: e?.nombre ?? '');
    _apPaternoCtrl = TextEditingController(text: e?.apellidoPaterno ?? '');
    _apMaternoCtrl = TextEditingController(text: e?.apellidoMaterno ?? '');
    _empleadoCtrl = TextEditingController(text: e?.numeroEmpleado ?? '');
    _especialidadCtrl = TextEditingController(text: e?.especialidad ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _curpCtrl = TextEditingController(text: e?.curp ?? '');
    if (e?.fechaNacimiento != null) {
      _fechaNacimiento = DateTime.parse(e!.fechaNacimiento!);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apPaternoCtrl.dispose();
    _apMaternoCtrl.dispose();
    _empleadoCtrl.dispose();
    _especialidadCtrl.dispose();
    _emailCtrl.dispose();
    _curpCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre es requerido');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final dio = widget.ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'nombre': nombre,
        'apellido_paterno': _apPaternoCtrl.text.trim(),
        'apellido_materno': _apMaternoCtrl.text.trim(),
        'especialidad': _especialidadCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'curp': _curpCtrl.text.trim().isEmpty ? null : _curpCtrl.text.trim().toUpperCase(),
        'fecha_nacimiento': _fechaNacimiento?.toIso8601String().split('T')[0],
      };
      
      if (_isEdit) {
        await dio.patch('/api/v1/teachers/${widget.existing!.id}', data: body);
      } else {
        body['numero_empleado'] = _empleadoCtrl.text.trim();
        await dio.post('/api/v1/teachers/', data: body);
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
      title: Text(_isEdit ? 'Editar maestro' : 'Nuevo maestro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              readOnly: _isEdit,
              decoration: InputDecoration(
                labelText: 'Nombre(s) *',
                border: const OutlineInputBorder(),
                errorText: _error,
                helperText: _isEdit ? 'El nombre no se puede editar' : null,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apPaternoCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Ap. Paterno',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _apMaternoCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Ap. Materno',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isEdit) ...[
              TextField(
                controller: _empleadoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número de empleado',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _curpCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'CURP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
                helperText: 'Se usará para el acceso al sistema',
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaNacimiento ?? DateTime(1990),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _fechaNacimiento = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de nacimiento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_fechaNacimiento == null
                    ? 'Seleccionar fecha'
                    : '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _especialidadCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Especialidad',
                border: OutlineInputBorder(),
                hintText: 'ej. Matemáticas, Física…',
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
