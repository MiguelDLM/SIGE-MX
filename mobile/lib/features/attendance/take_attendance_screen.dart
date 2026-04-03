import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../shared/models/group.dart';
import '../../shared/models/student.dart';
import '../../shared/models/attendance_record.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import '../../core/api/api_client.dart';
import 'attendance_provider.dart';

/// Screen 1 — docente picks a group
class TakeAttendanceGroupListScreen extends ConsumerWidget {
  const TakeAttendanceGroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(teacherGroupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Asistencia')),
      body: groupsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(teacherGroupsProvider)),
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(child: Text('No tienes grupos asignados'));
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              return ListTile(
                leading: const Icon(Icons.group, color: Color(0xFF1976D2)),
                title: Text(g.nombre ?? 'Grupo'),
                subtitle: Text('Grado ${g.grado} · ${g.turno ?? ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/attendance/take/${g.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

/// Screen 2 — docente marks each student present/falta/retardo
class TakeAttendanceScreen extends ConsumerStatefulWidget {
  final String groupId;
  const TakeAttendanceScreen({super.key, required this.groupId});

  @override
  ConsumerState<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends ConsumerState<TakeAttendanceScreen> {
  final Map<String, String> _statuses = {};
  bool _saving = false;

  static const _statusOptions = ['presente', 'falta', 'retardo', 'justificado'];

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(groupStudentsProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tomar lista'),
        actions: [
          TextButton(
            key: const Key('save_attendance'),
            onPressed: _saving ? null : () => _save(studentsAsync.valueOrNull ?? []),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: studentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (students) {
          if (students.isEmpty) return const Center(child: Text('Sin alumnos en este grupo'));
          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (_, i) => _StudentTile(
              student: students[i],
              status: _statuses[students[i].id] ?? 'presente',
              onStatusChanged: (s) =>
                  setState(() => _statuses[students[i].id] = s),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(List<Student> students) async {
    setState(() => _saving = true);
    final today = DateTime.now();
    final fecha =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((r) => r != ConnectivityResult.none);

    if (isOnline) {
      final dio = ref.read(apiClientProvider);
      for (final s in students) {
        try {
          await dio.post('/api/v1/attendance/', data: {
            'student_id': s.id,
            'group_id': widget.groupId,
            'fecha': fecha,
            'status': _statuses[s.id] ?? 'presente',
          });
        } catch (_) {
          _saveToHive(s.id, fecha, _statuses[s.id] ?? 'presente');
        }
      }
    } else {
      for (final s in students) {
        _saveToHive(s.id, fecha, _statuses[s.id] ?? 'presente');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexión — asistencia guardada localmente'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _saving = false);
      context.pop();
    }
  }

  void _saveToHive(String studentId, String fecha, String status) {
    final box = Hive.box<AttendanceRecord>('attendance_pending');
    box.add(AttendanceRecord(
      studentId: studentId,
      groupId: widget.groupId,
      fecha: fecha,
      status: status,
    ));
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  final String status;
  final ValueChanged<String> onStatusChanged;

  const _StudentTile({
    required this.student,
    required this.status,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(student.nombreCompleto),
      subtitle: Text(student.matricula),
      trailing: DropdownButton<String>(
        value: status,
        items: ['presente', 'falta', 'retardo', 'justificado']
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (v) => v != null ? onStatusChanged(v) : null,
      ),
    );
  }
}
