import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import 'grades_provider.dart';

class ViewGradesScreen extends ConsumerWidget {
  final String studentId;
  const ViewGradesScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(studentGradesProvider(studentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Calificaciones')),
      body: gradesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(studentGradesProvider(studentId)),
        ),
        data: (grades) {
          if (grades.isEmpty) {
            return const Center(child: Text('Sin calificaciones registradas'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grades.length,
            itemBuilder: (_, i) {
              final g = grades[i];
              final cal = g.calificacionDouble;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _gradeColor(cal),
                    child: Text(
                      cal != null ? cal.toStringAsFixed(1) : '—',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: const Text('Evaluación'),
                  subtitle: Text(g.evaluationId ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _gradeColor(double? cal) {
    if (cal == null) return Colors.grey;
    if (cal >= 8.0) return Colors.green;
    if (cal >= 6.0) return Colors.orange;
    return Colors.red;
  }
}
