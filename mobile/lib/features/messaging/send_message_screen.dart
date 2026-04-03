import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/user_summary.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../core/api/api_client.dart';
import 'messaging_provider.dart';

class SendMessageScreen extends ConsumerStatefulWidget {
  const SendMessageScreen({super.key});

  @override
  ConsumerState<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends ConsumerState<SendMessageScreen> {
  final _contentCtrl = TextEditingController();
  String _selectedType = 'directo';
  final List<UserSummary> _recipients = [];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo mensaje'),
        actions: [
          TextButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Enviar',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'directo', child: Text('Directo')),
              DropdownMenuItem(value: 'grupo', child: Text('Grupo')),
            ],
            onChanged: (v) => setState(() => _selectedType = v ?? 'directo'),
          ),
          const SizedBox(height: 16),
          usersAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => Text('Error cargando usuarios: $e',
                style: const TextStyle(color: Colors.red)),
            data: (users) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Destinatarios',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Autocomplete<UserSummary>(
                  displayStringForOption: (u) => u.nombreCompleto,
                  optionsBuilder: (v) {
                    if (v.text.isEmpty) return const [];
                    final q = v.text.toLowerCase();
                    return users.where(
                        (u) => u.nombreCompleto.toLowerCase().contains(q));
                  },
                  onSelected: (u) {
                    if (!_recipients.any((r) => r.id == u.id)) {
                      setState(() => _recipients.add(u));
                    }
                  },
                  fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) =>
                      TextField(
                    controller: ctrl,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Buscar usuario...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _recipients
                      .map((u) => Chip(
                            label: Text(u.nombreCompleto),
                            onDeleted: () => setState(() =>
                                _recipients.removeWhere((r) => r.id == u.id)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mensaje',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_contentCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Escribe un mensaje');
      return;
    }
    if (_recipients.isEmpty) {
      setState(() => _error = 'Selecciona al menos un destinatario');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post('/api/v1/messages/', data: {
        'content': _contentCtrl.text.trim(),
        'type': _selectedType,
        'recipient_ids': _recipients.map((u) => u.id).toList(),
      });
      ref.invalidate(inboxProvider);
      ref.invalidate(sentProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Error al enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
