import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/models/event.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import 'events_provider.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final isAdmin = auth is AuthAuthenticated &&
        (auth.primaryRole == 'directivo' ||
            auth.primaryRole == 'control_escolar');

    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => context.push('/events/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: eventsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(eventsProvider),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('Sin eventos programados'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _EventCard(
              event: events[i],
              isAdmin: isAdmin,
              onEdit: () =>
                  context.push('/events/${events[i].id}/edit', extra: events[i]),
              onDelete: () => _deleteEvent(context, ref, events[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteEvent(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar "${event.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        final dio = ref.read(apiClientProvider);
        await dio.delete('/api/v1/events/${event.id}');
        ref.invalidate(eventsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _tipoColor(event.tipo).withOpacity(0.15),
          child: Icon(_tipoIcon(event.tipo), color: _tipoColor(event.tipo)),
        ),
        title: Text(event.titulo ?? 'Evento',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(event.fechaInicio?.substring(0, 10) ?? ''),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.descripcion != null &&
                    event.descripcion!.isNotEmpty)
                  Text(event.descripcion!),
                if (event.fechaFin != null) ...[
                  const SizedBox(height: 4),
                  Text('Hasta: ${event.fechaFin!.substring(0, 10)}',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 4),
                Chip(
                  label: Text(event.tipo ?? 'otro'),
                  backgroundColor:
                      _tipoColor(event.tipo).withOpacity(0.1),
                  labelStyle:
                      TextStyle(color: _tipoColor(event.tipo)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.people_outline, size: 16),
                      label: const Text('Participantes'),
                      onPressed: () => context.push(
                          '/events/${event.id}/participants', extra: event),
                    ),
                    if (isAdmin) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.workspace_premium_outlined,
                            size: 16),
                        label: const Text('Constancias'),
                        onPressed: () => context.push(
                            '/events/${event.id}/constancias', extra: event),
                      ),
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        label: const Text('Eliminar',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tipoColor(String? tipo) {
    switch (tipo) {
      case 'academico':
        return Colors.blue;
      case 'cultural':
        return Colors.purple;
      case 'deportivo':
        return Colors.green;
      case 'administrativo':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _tipoIcon(String? tipo) {
    switch (tipo) {
      case 'academico':
        return Icons.school;
      case 'cultural':
        return Icons.palette;
      case 'deportivo':
        return Icons.sports;
      case 'administrativo':
        return Icons.business;
      default:
        return Icons.event;
    }
  }
}
