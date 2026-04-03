import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import 'attendance_provider.dart';

class ViewAttendanceScreen extends ConsumerWidget {
  const ViewAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    return authAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(body: ErrorView(message: '$e')),
      data: (auth) {
        if (auth is! AuthAuthenticated) return const SizedBox();
        return _AttendanceList(studentId: auth.userId);
      },
    );
  }
}

class _AttendanceList extends ConsumerWidget {
  final String studentId;
  const _AttendanceList({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(studentAttendanceProvider(studentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Asistencia')),
      body: attendanceAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(studentAttendanceProvider(studentId)),
        ),
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('Sin registros de asistencia'));
          }
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (_, i) {
              final r = records[i];
              final status = r['status'] as String? ?? '';
              return ListTile(
                leading: _StatusIcon(status: status),
                title: Text(r['fecha']?.toString() ?? ''),
                trailing: Chip(
                  label: Text(status),
                  backgroundColor: _statusColor(status).withOpacity(0.15),
                  labelStyle: TextStyle(color: _statusColor(status)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'presente': return Colors.green;
      case 'falta': return Colors.red;
      case 'retardo': return Colors.orange;
      case 'justificado': return Colors.blue;
      default: return Colors.grey;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'presente': return const Icon(Icons.check_circle, color: Colors.green);
      case 'falta': return const Icon(Icons.cancel, color: Colors.red);
      case 'retardo': return const Icon(Icons.schedule, color: Colors.orange);
      case 'justificado': return const Icon(Icons.info, color: Colors.blue);
      default: return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }
}
