import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/message.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import '../../core/api/api_client.dart';
import 'messaging_provider.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(inboxProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mensajes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Recibidos'),
              Tab(text: 'Enviados'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Nuevo mensaje',
              onPressed: () => context.push('/messages/new'),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            inboxAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(inboxProvider),
              ),
              data: (messages) => _MessageList(
                messages: messages,
                onTap: (m) {
                  ref.read(apiClientProvider).post(
                    '/api/v1/messages/${m.id}/read',
                  ).then((_) => ref.invalidate(inboxProvider)).ignore();
                  _showMessageDialog(context, m);
                },
              ),
            ),
            Consumer(builder: (ctx, ref2, _) {
              final sentAsync = ref2.watch(sentProvider);
              return sentAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => ErrorView(
                    message: '$e',
                    onRetry: () => ref2.invalidate(sentProvider)),
                data: (messages) => _MessageList(
                    messages: messages,
                    onTap: (m) => _showMessageDialog(context, m)),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showMessageDialog(BuildContext context, Message m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_typeLabel(m.type)),
        content: Text(m.content ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'directo':
        return 'Mensaje directo';
      case 'grupo':
        return 'Mensaje de grupo';
      case 'sistema':
        return 'Mensaje del sistema';
      default:
        return 'Mensaje';
    }
  }
}

class _MessageList extends StatelessWidget {
  final List<Message> messages;
  final void Function(Message) onTap;
  const _MessageList({required this.messages, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('Sin mensajes'));
    }
    return ListView.separated(
      itemCount: messages.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = messages[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                m.read ? Colors.grey.shade300 : const Color(0xFF1976D2),
            child: Icon(
              Icons.mail_outline,
              color: m.read ? Colors.grey : Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            m.content ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: m.read ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Text(m.createdAt?.substring(0, 10) ?? ''),
          onTap: () => onTap(m),
        );
      },
    );
  }
}
