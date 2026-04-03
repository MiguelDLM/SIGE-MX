import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/models/justification.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import 'justifications_provider.dart';

class JustificationListScreen extends ConsumerWidget {
  const JustificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    final justificationsAsync = ref.watch(justificationsProvider);
    final auth = authAsync.valueOrNull;
    final isPadreOrAlumno = auth is AuthAuthenticated &&
        (auth.primaryRole == 'padre' || auth.primaryRole == 'alumno');

    return Scaffold(
      appBar: AppBar(title: const Text('Justificantes')),
      floatingActionButton: isPadreOrAlumno
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Subir'),
              onPressed: () => context.push('/justifications/new'),
            )
          : null,
      body: justificationsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(justificationsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Sin justificantes'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _JustificationTile(j: list[i]),
          );
        },
      ),
    );
  }
}

class _JustificationTile extends ConsumerWidget {
  final Justification j;
  const _JustificationTile({required this.j});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(j.status);
    final authAsync = ref.watch(authNotifierProvider);
    final auth = authAsync.valueOrNull;
    final canReview = auth is AuthAuthenticated &&
        (auth.primaryRole == 'control_escolar' ||
            auth.primaryRole == 'directivo');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.15),
        child: Icon(_statusIcon(j.status), color: statusColor, size: 20),
      ),
      title: Text(j.motivo ?? 'Sin motivo'),
      subtitle:
          Text('${j.fechaInicio ?? ''} — ${j.fechaFin ?? 'misma fecha'}'),
      trailing: canReview && j.status == 'pendiente'
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.green),
                  tooltip: 'Aprobar',
                  onPressed: () => _review(context, ref, 'aprobado'),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  tooltip: 'Rechazar',
                  onPressed: () => _review(context, ref, 'rechazado'),
                ),
              ],
            )
          : Chip(
              label: Text(j.status ?? 'pendiente'),
              backgroundColor: statusColor.withOpacity(0.15),
              labelStyle: TextStyle(color: statusColor, fontSize: 12),
            ),
    );
  }

  Future<void> _review(
      BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(apiClientProvider).patch(
        '/api/v1/justifications/${j.id}/review',
        data: {'status': status},
      );
      ref.invalidate(justificationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'aprobado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'aprobado':
        return Icons.check_circle;
      case 'rechazado':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }
}
