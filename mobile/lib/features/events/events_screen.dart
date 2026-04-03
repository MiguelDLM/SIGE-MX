import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/event.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import 'events_provider.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
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
            itemBuilder: (_, i) => _EventCard(event: events[i]),
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  const _EventCard({required this.event});

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
