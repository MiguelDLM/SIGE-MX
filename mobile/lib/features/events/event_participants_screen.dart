import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/event.dart';

// ---------- Model ----------
class EventParticipantRule {
  final String id;
  final String eventId;
  final String tipo;
  final String? userId;
  final String? groupId;
  final String? subjectId;
  final String? rol;
  final String? label;

  const EventParticipantRule({
    required this.id,
    required this.eventId,
    required this.tipo,
    this.userId,
    this.groupId,
    this.subjectId,
    this.rol,
    this.label,
  });

  factory EventParticipantRule.fromJson(Map<String, dynamic> j) =>
      EventParticipantRule(
        id: j['id'] as String,
        eventId: j['event_id'] as String,
        tipo: j['tipo'] as String,
        userId: j['user_id'] as String?,
        groupId: j['group_id'] as String?,
        subjectId: j['subject_id'] as String?,
        rol: j['rol'] as String?,
        label: j['label'] as String?,
      );

  IconData get icon {
    switch (tipo) {
      case 'grupo':
        return Icons.group_outlined;
      case 'materia':
        return Icons.book_outlined;
      case 'rol':
        return Icons.badge_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String get displayLabel {
    if (label != null) return label!;
    switch (tipo) {
      case 'grupo':
        return 'Grupo: ${groupId?.substring(0, 8) ?? ''}…';
      case 'materia':
        return 'Materia: ${subjectId?.substring(0, 8) ?? ''}…';
      case 'rol':
        return 'Rol: $rol';
      default:
        return userId?.substring(0, 8) ?? '';
    }
  }
}

// ---------- Provider ----------
final eventParticipantRulesProvider =
    FutureProvider.family<List<EventParticipantRule>, String>(
        (ref, eventId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/events/$eventId/participants');
  return (resp.data['data'] as List)
      .map((j) => EventParticipantRule.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---------- Screen ----------
class EventParticipantsScreen extends ConsumerWidget {
  final Event event;
  const EventParticipantsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventParticipantRulesProvider(event.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Participantes')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Agregar'),
        onPressed: () => _showAddSheet(context, ref),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('Sin participantes agregados'));
          }
          return ListView.separated(
            itemCount: rules.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = rules[i];
              return ListTile(
                leading: CircleAvatar(child: Icon(r.icon)),
                title: Text(r.displayLabel),
                subtitle: Text(r.tipo),
                trailing: IconButton(
                  icon:
                      const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _removeRule(context, ref, r),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddParticipantSheet(event: event, ref: ref),
    );
    ref.invalidate(eventParticipantRulesProvider(event.id));
  }

  Future<void> _removeRule(
      BuildContext context, WidgetRef ref, EventParticipantRule r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Quitar participante?'),
        content: Text('Se quitará "${r.displayLabel}" del evento.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(apiClientProvider).delete(
            '/api/v1/events/${event.id}/participants/${r.id}');
        ref.invalidate(eventParticipantRulesProvider(event.id));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

// ---------- Add participant bottom sheet ----------
class _AddParticipantSheet extends StatefulWidget {
  final Event event;
  final WidgetRef ref;
  const _AddParticipantSheet({required this.event, required this.ref});

  @override
  State<_AddParticipantSheet> createState() => _AddParticipantSheetState();
}

class _AddParticipantSheetState extends State<_AddParticipantSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = false;

  // Individual
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _userResults = [];
  String? _selectedUserId;

  // Grupo
  List<Map<String, dynamic>> _grupos = [];
  String? _selectedGroupId;

  // Materia
  List<Map<String, dynamic>> _materias = [];
  String? _selectedSubjectId;

  // Rol
  String _selectedRol = 'alumno';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadLists();
  }

  Future<void> _loadLists() async {
    try {
      final dio = widget.ref.read(apiClientProvider);
      final gs = await dio.get('/api/v1/groups/');
      final ms = await dio.get('/api/v1/subjects/');
      setState(() {
        _grupos = (gs.data['data'] as List).cast<Map<String, dynamic>>();
        _materias = (ms.data['data'] as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    Map<String, dynamic> body = {};
    switch (_tabCtrl.index) {
      case 0:
        if (_selectedUserId == null) {
          setState(() => _loading = false);
          return;
        }
        body = {'tipo': 'individual', 'user_id': _selectedUserId};
        break;
      case 1:
        if (_selectedGroupId == null) {
          setState(() => _loading = false);
          return;
        }
        body = {'tipo': 'grupo', 'group_id': _selectedGroupId};
        break;
      case 2:
        if (_selectedSubjectId == null) {
          setState(() => _loading = false);
          return;
        }
        body = {'tipo': 'materia', 'subject_id': _selectedSubjectId};
        break;
      case 3:
        body = {'tipo': 'rol', 'rol': _selectedRol};
        break;
    }
    try {
      await widget.ref.read(apiClientProvider).post(
            '/api/v1/events/${widget.event.id}/participants',
            data: body,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Agregar participantes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Individual'),
              Tab(text: 'Grupo'),
              Tab(text: 'Materia'),
              Tab(text: 'Rol'),
            ],
          ),
          SizedBox(
            height: 250,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Individual
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Nombre o correo'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () async {
                              try {
                                final dio =
                                    widget.ref.read(apiClientProvider);
                                final r = await dio.get('/api/v1/users/',
                                    queryParameters: {
                                      'search': _searchCtrl.text
                                    });
                                setState(() {
                                  _userResults = (r.data['data'] as List)
                                      .cast<Map<String, dynamic>>();
                                });
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _userResults.length,
                          itemBuilder: (_, i) {
                            final u = _userResults[i];
                            return RadioListTile<String>(
                              title: Text(u['nombre'] as String? ?? ''),
                              subtitle: Text(u['email'] as String? ?? ''),
                              value: u['id'] as String,
                              groupValue: _selectedUserId,
                              onChanged: (v) =>
                                  setState(() => _selectedUserId = v),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Grupo
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    value: _selectedGroupId,
                    decoration: const InputDecoration(labelText: 'Grupo'),
                    items: _grupos
                        .map((g) => DropdownMenuItem(
                              value: g['id'] as String,
                              child: Text(g['nombre'] as String? ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedGroupId = v),
                  ),
                ),
                // Materia
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    value: _selectedSubjectId,
                    decoration: const InputDecoration(
                        labelText: 'Materia (todos sus maestros)'),
                    items: _materias
                        .map((m) => DropdownMenuItem(
                              value: m['id'] as String,
                              child: Text(m['nombre'] as String? ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSubjectId = v),
                  ),
                ),
                // Rol
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    value: _selectedRol,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(value: 'alumno', child: Text('Alumnos')),
                      DropdownMenuItem(value: 'docente', child: Text('Maestros')),
                      DropdownMenuItem(
                          value: 'directivo', child: Text('Directivos')),
                      DropdownMenuItem(
                          value: 'control_escolar',
                          child: Text('Control escolar')),
                      DropdownMenuItem(value: 'tutor', child: Text('Tutores')),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedRol = v ?? 'alumno'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Agregar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
