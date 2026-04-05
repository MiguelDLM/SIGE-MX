import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'grupos_screen.dart';

// ---------- Models ----------
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
      [nombre, apellidoPaterno].where((s) => s != null && s!.isNotEmpty).join(' ');
}

class HorarioEntry {
  final String id;
  final String subjectId;
  final String teacherId;
  final String? subjectNombre;
  final String? teacherNombre;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;
  final String? aula;

  const HorarioEntry({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    this.subjectNombre,
    this.teacherNombre,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    this.aula,
  });

  factory HorarioEntry.fromJson(Map<String, dynamic> j) => HorarioEntry(
        id: j['id'] as String,
        subjectId: j['subject_id'] as String,
        teacherId: j['teacher_id'] as String,
        subjectNombre: j['subject_nombre'] as String?,
        teacherNombre: j['teacher_nombre'] as String?,
        diaSemana: j['dia_semana'] as int,
        horaInicio: j['hora_inicio'] as String,
        horaFin: j['hora_fin'] as String,
        aula: j['aula'] as String?,
      );
}

// ---------- Providers ----------
final alumnosEnGrupoProvider =
    FutureProvider.family<List<AlumnoEnGrupo>, String>((ref, groupId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/groups/$groupId/students');
  return (resp.data['data'] as List)
      .map((j) => AlumnoEnGrupo.fromJson(j as Map<String, dynamic>))
      .toList();
});

final horarioGrupoProvider =
    FutureProvider.family<List<HorarioEntry>, String>((ref, groupId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/horarios/grupo/$groupId');
  return (resp.data['data'] as List)
      .map((j) => HorarioEntry.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---------- Screen ----------
class GrupoDetailScreen extends ConsumerStatefulWidget {
  final Grupo grupo;
  const GrupoDetailScreen({super.key, required this.grupo});

  @override
  ConsumerState<GrupoDetailScreen> createState() => _GrupoDetailScreenState();
}

class _GrupoDetailScreenState extends ConsumerState<GrupoDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupo.nombre),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Alumnos', icon: Icon(Icons.people_outline)),
            Tab(text: 'Horario', icon: Icon(Icons.schedule_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _AlumnosTab(groupId: widget.grupo.id),
          _HorarioTab(groupId: widget.grupo.id),
        ],
      ),
    );
  }
}

class _AlumnosTab extends ConsumerWidget {
  final String groupId;
  const _AlumnosTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alumnosEnGrupoProvider(groupId));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudent(context, ref),
        label: const Text('Añadir alumno'),
        icon: const Icon(Icons.person_add_outlined),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
                leading: CircleAvatar(child: Text(a.nombre[0])),
                title: Text(a.displayName),
                subtitle: Text(a.matricula ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
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
    // Reusing logic from the user's previously working code
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
                      setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: results,
                builder: (_, list, __) {
                  if (list.isEmpty) return const Text('Sin resultados');
                  return SizedBox(
                    height: 250,
                    width: double.maxFinite,
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final s = list[i];
                        return RadioListTile<String>(
                          title: Text('${s['nombre']} ${s['apellido_paterno'] ?? ''}'),
                          subtitle: Text(s['matricula'] ?? ''),
                          value: s['id'] as String,
                          groupValue: selectedStudentId,
                          onChanged: (v) => setState(() => selectedStudentId = v),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: selectedStudentId == null
                  ? null
                  : () async {
                      try {
                        await ref.read(apiClientProvider).post(
                          '/api/v1/groups/$groupId/students',
                          data: {'student_id': selectedStudentId},
                        );
                        Navigator.pop(ctx);
                        ref.invalidate(alumnosEnGrupoProvider(groupId));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeStudent(BuildContext context, WidgetRef ref, AlumnoEnGrupo a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar alumno?'),
        content: Text('Se quitará a ${a.displayName} del grupo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(apiClientProvider).delete('/api/v1/groups/$groupId/students/${a.id}');
        ref.invalidate(alumnosEnGrupoProvider(groupId));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _HorarioTab extends ConsumerWidget {
  final String groupId;
  const _HorarioTab({required this.groupId});

  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(horarioGrupoProvider(groupId));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHorario(context, ref),
        label: const Text('Añadir clase'),
        icon: const Icon(Icons.add_alarm_outlined),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('Sin clases programadas'));
          }
          final byDay = <int, List<HorarioEntry>>{};
          for (final e in entries) {
            byDay.putIfAbsent(e.diaSemana, () => []).add(e);
          }
          final sortedDays = byDay.keys.toList()..sort();

          return ListView.builder(
            itemCount: sortedDays.length,
            itemBuilder: (ctx, idx) {
              final day = sortedDays[idx];
              final dayEntries = byDay[day]!..sort((a, b) => xCompare(a.horaInicio, b.horaInicio));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(_dias[day], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                  ),
                  ...dayEntries.map((e) => ListTile(
                    title: Text(e.subjectNombre ?? 'Materia'),
                    subtitle: Text('${e.teacherNombre ?? 'Maestro'} • ${e.horaInicio.substring(0, 5)} - ${e.horaFin.substring(0, 5)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _deleteEntry(context, ref, e),
                    ),
                  )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  int xCompare(String a, String b) => a.compareTo(b);

  Future<void> _deleteEntry(BuildContext context, WidgetRef ref, HorarioEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar clase?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(apiClientProvider).delete('/api/v1/horarios/${e.id}');
        ref.invalidate(horarioGrupoProvider(groupId));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showAddHorario(BuildContext context, WidgetRef ref) async {
    String? selSubjId;
    String? selTeacherId;
    int selDay = 0;
    TimeOfDay start = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 8, minute: 0);
    List<Map<String, dynamic>> subjs = [];
    List<Map<String, dynamic>> teachers = [];
    bool loading = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          if (loading) {
            Future.microtask(() async {
              final dio = ref.read(apiClientProvider);
              final rS = await dio.get('/api/v1/subjects/');
              final rT = await dio.get('/api/v1/teachers/');
              if (ctx.mounted) {
                setState(() {
                  subjs = (rS.data['data'] as List).cast<Map<String, dynamic>>();
                  teachers = (rT.data['data'] as List).cast<Map<String, dynamic>>();
                  loading = false;
                });
              }
            });
            return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
          }

          return AlertDialog(
            title: const Text('Programar clase'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Materia'),
                    items: subjs.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['nombre']))).toList(),
                    onChanged: (v) => selSubjId = v,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Maestro'),
                    items: teachers.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['nombre']))).toList(),
                    onChanged: (v) => selTeacherId = v,
                  ),
                  DropdownButtonFormField<int>(
                    value: selDay,
                    decoration: const InputDecoration(labelText: 'Día'),
                    items: List.generate(6, (i) => DropdownMenuItem(value: i, child: Text(_dias[i]))),
                    onChanged: (v) => selDay = v!,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final t = await showTimePicker(context: ctx, initialTime: start);
                            if (t != null) setState(() => start = t);
                          },
                          child: Text('Inicio: ${start.format(ctx)}'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final t = await showTimePicker(context: ctx, initialTime: end);
                            if (t != null) setState(() => end = t);
                          },
                          child: Text('Fin: ${end.format(ctx)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: (selSubjId == null || selTeacherId == null) ? null : () async {
                  try {
                    final hStart = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                    final hEnd = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
                    await ref.read(apiClientProvider).post('/api/v1/horarios/', data: {
                      'group_id': groupId,
                      'subject_id': selSubjId,
                      'teacher_id': selTeacherId,
                      'dia_semana': selDay,
                      'hora_inicio': hStart,
                      'hora_fin': hEnd,
                    });
                    Navigator.pop(ctx);
                    ref.invalidate(horarioGrupoProvider(groupId));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Reusing AlumnoDialog from AlumnosAdminScreen ----------
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
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _matriculaCtrl = TextEditingController(text: e?['matricula'] as String? ?? '');
    _nombreCtrl = TextEditingController(text: e?['nombre'] as String? ?? '');
    _apPaternoCtrl = TextEditingController(text: e?['apellido_paterno'] as String? ?? '');
    _apMaternoCtrl = TextEditingController(text: e?['apellido_materno'] as String? ?? '');
    _emailCtrl = TextEditingController(text: e?['email'] as String? ?? '');
    _curpCtrl = TextEditingController(text: e?['curp'] as String? ?? '');
    if (e?['fecha_nacimiento'] != null) {
      _fechaNacimiento = DateTime.parse(e!['fecha_nacimiento'] as String);
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
        'curp': _curpCtrl.text.trim().isEmpty ? null : _curpCtrl.text.trim().toUpperCase(),
        'fecha_nacimiento': _fechaNacimiento?.toIso8601String().split('T')[0],
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
    return AlertDialog(
      title: Text(_isEdit ? 'Editar alumno' : 'Nuevo alumno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEdit) TextField(controller: _matriculaCtrl, decoration: const InputDecoration(labelText: 'Matrícula')),
            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: _apPaternoCtrl, decoration: const InputDecoration(labelText: 'Ap. Paterno')),
            TextField(controller: _apMaternoCtrl, decoration: const InputDecoration(labelText: 'Ap. Materno')),
            TextField(controller: _curpCtrl, decoration: const InputDecoration(labelText: 'CURP')),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            ListTile(
              title: Text(_fechaNacimiento == null ? 'Fecha Nac.' : '${_fechaNacimiento!.toLocal()}'.split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now());
                if (d != null) setState(() => _fechaNacimiento = d);
              },
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
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
