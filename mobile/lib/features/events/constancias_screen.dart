import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/event.dart';

// ---------- Model ----------
class Constancia {
  final String id;
  final String eventId;
  final String userId;
  final String authorizedBy;
  final String authorizedAt;
  final String? revokedAt;
  final String? notas;
  final bool active;

  const Constancia({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.authorizedBy,
    required this.authorizedAt,
    this.revokedAt,
    this.notas,
    this.active = true,
  });

  factory Constancia.fromJson(Map<String, dynamic> j) => Constancia(
        id: j['id'] as String,
        eventId: j['event_id'] as String,
        userId: j['user_id'] as String,
        authorizedBy: j['authorized_by'] as String,
        authorizedAt: j['authorized_at'] as String,
        revokedAt: j['revoked_at'] as String?,
        notas: j['notas'] as String?,
        active: j['active'] as bool? ?? true,
      );
}

// ---------- Providers ----------
final constanciasEventProvider =
    FutureProvider.family<List<Constancia>, String>((ref, eventId) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/constancias/',
      queryParameters: {'event_id': eventId});
  return (resp.data['data'] as List)
      .map((j) => Constancia.fromJson(j as Map<String, dynamic>))
      .toList();
});

final misConstanciasProvider = FutureProvider<List<Constancia>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/constancias/mis-constancias');
  return (resp.data['data'] as List)
      .map((j) => Constancia.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---------- Event Constancias Screen (admin) ----------
class ConstanciasEventScreen extends ConsumerStatefulWidget {
  final Event event;
  const ConstanciasEventScreen({super.key, required this.event});

  @override
  ConsumerState<ConstanciasEventScreen> createState() =>
      _ConstanciasEventScreenState();
}

class _ConstanciasEventScreenState
    extends ConsumerState<ConstanciasEventScreen> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final constanciasAsync =
        ref.watch(constanciasEventProvider(widget.event.id));
    final participantsAsync = ref.watch(
        _resolvedParticipantsProvider(widget.event.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Constancias'),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Autorizar seleccionados',
              onPressed: () => _authorizeBatch(context),
            ),
        ],
      ),
      body: participantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (participants) {
          if (participants.isEmpty) {
            return const Center(child: Text('Sin participantes en este evento'));
          }
          return constanciasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (constancias) {
              final constanciaByUser = {
                for (final c in constancias) c.userId: c
              };

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${constancias.where((c) => c.active).length}/${participants.length} autorizadas',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.select_all, size: 18),
                          label: const Text('Autorizar todos'),
                          onPressed: () => _authorizeAll(context, participants,
                              constanciaByUser),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: participants.length,
                      itemBuilder: (_, i) {
                        final p = participants[i];
                        final uid = p['user_id'] as String;
                        final nombre = p['nombre'] as String? ?? uid;
                        final constancia = constanciaByUser[uid];
                        final hasActive =
                            constancia != null && constancia.active;

                        return CheckboxListTile(
                          value: _selected.contains(uid),
                          onChanged: hasActive
                              ? null
                              : (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(uid);
                                    } else {
                                      _selected.remove(uid);
                                    }
                                  }),
                          title: Text(nombre),
                          secondary: hasActive
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified,
                                        color: Colors.green, size: 20),
                                    IconButton(
                                      icon: const Icon(Icons.undo,
                                          color: Colors.red, size: 20),
                                      tooltip: 'Revocar',
                                      onPressed: () => _revoke(
                                          context, constancia.id),
                                    ),
                                  ],
                                )
                              : null,
                          subtitle: constancia != null && !constancia.active
                              ? const Text('Revocada',
                                  style: TextStyle(color: Colors.red))
                              : null,
                        );
                      },
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check),
                          label:
                              Text('Autorizar ${_selected.length} seleccionados'),
                          onPressed: () => _authorizeBatch(context),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _authorizeBatch(BuildContext context) async {
    if (_selected.isEmpty) return;
    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/constancias/batch',
        data: {
          'event_id': widget.event.id,
          'user_ids': _selected.toList(),
        },
      );
      setState(() => _selected.clear());
      ref.invalidate(constanciasEventProvider(widget.event.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Constancias autorizadas')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _authorizeAll(
    BuildContext context,
    List<Map<String, dynamic>> participants,
    Map<String, Constancia> constanciaByUser,
  ) async {
    final pending = participants
        .map((p) => p['user_id'] as String)
        .where((uid) {
          final c = constanciaByUser[uid];
          return c == null || !c.active;
        })
        .toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos ya tienen constancia')));
      return;
    }
    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/constancias/batch',
        data: {
          'event_id': widget.event.id,
          'user_ids': pending,
        },
      );
      ref.invalidate(constanciasEventProvider(widget.event.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pending.length} constancias autorizadas')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _revoke(BuildContext context, String constanciaId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Revocar constancia?'),
        content: const Text('Esta acción se puede deshacer autorizando nuevamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref
            .read(apiClientProvider)
            .delete('/api/v1/constancias/$constanciaId');
        ref.invalidate(constanciasEventProvider(widget.event.id));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

// Provider for resolved participants of an event
final _resolvedParticipantsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, eventId) async {
  final dio = ref.read(apiClientProvider);
  final resp =
      await dio.get('/api/v1/events/$eventId/participants/resolved');
  return (resp.data['data'] as List).cast<Map<String, dynamic>>();
});

// ---------- Mis Constancias Screen ----------
class MisConstanciasScreen extends ConsumerWidget {
  const MisConstanciasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(misConstanciasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Constancias')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              TextButton(
                onPressed: () => ref.invalidate(misConstanciasProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Sin constancias'),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = items[i];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.workspace_premium_outlined,
                      color: Colors.white),
                ),
                title: Text('Evento: ${c.eventId.substring(0, 8)}…'),
                subtitle: Text(
                    'Autorizada: ${c.authorizedAt.substring(0, 10)}'),
                trailing: c.active
                    ? const Icon(Icons.verified, color: Colors.green)
                    : const Icon(Icons.cancel, color: Colors.red),
              );
            },
          );
        },
      ),
    );
  }
}
