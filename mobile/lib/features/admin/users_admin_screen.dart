import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/user_summary.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'users_admin_provider.dart';

class UsersAdminScreen extends ConsumerWidget {
  const UsersAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de usuarios')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/users/new'),
        child: const Icon(Icons.person_add),
      ),
      body: usersAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('$e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('Sin usuarios registrados'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) => _UserTile(
              user: users[i],
              onDeactivate: () => _deactivate(context, ref, users[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    UserSummary user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text('¿Desactivar a ${user.nombreCompleto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        final dio = ref.read(apiClientProvider);
        await dio.delete('/api/v1/users/${user.id}');
        ref.invalidate(usersAdminProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

class _UserTile extends StatelessWidget {
  final UserSummary user;
  final VoidCallback onDeactivate;
  const _UserTile({required this.user, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(user.nombre?[0].toUpperCase() ?? '?'),
      ),
      title: Text(user.nombreCompleto),
      subtitle: Text(user.roles.join(', ')),
      trailing: IconButton(
        icon: const Icon(Icons.person_off_outlined, color: Colors.red),
        tooltip: 'Desactivar',
        onPressed: onDeactivate,
      ),
    );
  }
}
