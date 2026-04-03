import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/evaluation.dart';
import '../../shared/models/student.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import '../../core/api/api_client.dart';
import '../attendance/attendance_provider.dart';
import 'grades_provider.dart';

/// Screen 1 — docente picks a group then an evaluation
class CaptureGradesGroupListScreen extends ConsumerWidget {
  const CaptureGradesGroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(teacherGroupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Calificaciones')),
      body: groupsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (groups) {
          if (groups.isEmpty) return const Center(child: Text('Sin grupos asignados'));
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              return ExpansionTile(
                leading: const Icon(Icons.group, color: Color(0xFF1976D2)),
                title: Text(g.nombre ?? 'Grupo'),
                children: [
                  _EvaluationList(groupId: g.id),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EvaluationList extends ConsumerWidget {
  final String groupId;
  const _EvaluationList({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evalsAsync = ref.watch(groupEvaluationsProvider(groupId));
    return evalsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (evals) {
        if (evals.isEmpty) {
          return const ListTile(title: Text('Sin evaluaciones en este grupo'));
        }
        return Column(
          children: evals.map((e) => ListTile(
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                title: Text(e.titulo ?? 'Evaluación'),
                subtitle: Text(e.tipo ?? ''),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/grades/capture/${e.id}'),
              )).toList(),
        );
      },
    );
  }
}

/// Screen 2 — docente enters calificacion for each student
class CaptureGradesScreen extends ConsumerStatefulWidget {
  final String evaluationId;
  const CaptureGradesScreen({super.key, required this.evaluationId});

  @override
  ConsumerState<CaptureGradesScreen> createState() =>
      _CaptureGradesScreenState();
}

class _CaptureGradesScreenState extends ConsumerState<CaptureGradesScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capturar calificaciones'),
        actions: [
          TextButton(
            key: const Key('save_grades'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _EvaluationStudentList(
        evaluationId: widget.evaluationId,
        controllers: _controllers,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final dio = ref.read(apiClientProvider);
    for (final entry in _controllers.entries) {
      final studentId = entry.key;
      final value = entry.value.text.trim();
      if (value.isEmpty) continue;
      try {
        await dio.post('/api/v1/grades/', data: {
          'evaluation_id': widget.evaluationId,
          'student_id': studentId,
          'calificacion': value,
        });
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _saving = false);
      context.pop();
    }
  }
}

class _EvaluationStudentList extends ConsumerWidget {
  final String evaluationId;
  final Map<String, TextEditingController> controllers;
  const _EvaluationStudentList({
    required this.evaluationId,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(teacherGroupsProvider);
    return groupsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (groups) {
        return _FindEvaluationInGroups(
          evaluationId: evaluationId,
          groupIds: groups.map((g) => g.id).toList(),
          controllers: controllers,
        );
      },
    );
  }
}

class _FindEvaluationInGroups extends ConsumerWidget {
  final String evaluationId;
  final List<String> groupIds;
  final Map<String, TextEditingController> controllers;

  const _FindEvaluationInGroups({
    required this.evaluationId,
    required this.groupIds,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final gId in groupIds) {
      final evalsAsync = ref.watch(groupEvaluationsProvider(gId));
      final evals = evalsAsync.valueOrNull;
      if (evals == null) continue;
      final eval = evals.where((e) => e.id == evaluationId).firstOrNull;
      if (eval != null && eval.groupId != null) {
        return _StudentsWithControllers(
          groupId: eval.groupId!,
          controllers: controllers,
        );
      }
    }
    return const LoadingIndicator();
  }
}

class _StudentsWithControllers extends ConsumerWidget {
  final String groupId;
  final Map<String, TextEditingController> controllers;
  const _StudentsWithControllers({required this.groupId, required this.controllers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(groupStudentsProvider(groupId));
    return studentsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (students) => ListView.builder(
        itemCount: students.length,
        itemBuilder: (_, i) {
          final s = students[i];
          controllers.putIfAbsent(s.id, () => TextEditingController());
          return ListTile(
            title: Text(s.nombreCompleto),
            subtitle: Text(s.matricula),
            trailing: SizedBox(
              width: 80,
              child: TextField(
                controller: controllers[s.id],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '0-10',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
