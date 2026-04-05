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
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _UserTile(
              user: users[i],
              onResetPassword: () => _resetPassword(context, ref, users[i]),
              onDelete: () => _confirmDelete(context, ref, users[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref, UserSummary user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar contraseña'),
        content: Text('La contraseña de "${user.nombreCompleto}" volverá a su valor predeterminado (CURP o Matrícula).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reiniciar')),
        ],
      ),
    );
    if (ok == true) {
      try {
        final dio = ref.read(apiClientProvider);
        final resp = await dio.post('/api/v1/users/${user.id}/reset-password');
        final newPwd = resp.data['data']['default_password'];
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Éxito'),
              content: Text('Nueva contraseña: $newPwd'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, UserSummary user) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gestionar acceso'),
        content: Text('Usuario: ${user.nombreCompleto}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'deactivate'),
            child: const Text('Inactivar', style: TextStyle(color: Colors.orange)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'permanent'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar Permanente'),
          ),
        ],
      ),
    );

    if (action == null) return;

    try {
      final dio = ref.read(apiClientProvider);
      if (action == 'deactivate') {
        await dio.delete('/api/v1/users/${user.id}');
      } else {
        await dio.delete('/api/v1/users/${user.id}/permanent');
      }
      ref.invalidate(usersAdminProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _UserTile extends StatelessWidget {
  final UserSummary user;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;
  const _UserTile({required this.user, required this.onResetPassword, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(user.nombre?[0].toUpperCase() ?? '?')),
      title: Text(user.nombreCompleto),
      subtitle: Text(user.roles.join(', ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.lock_reset, color: Colors.blue),
            tooltip: 'Reiniciar contraseña',
            onPressed: onResetPassword,
          ),
          IconButton(
            icon: const Icon(Icons.person_off_outlined, color: Colors.red),
            tooltip: 'Inactivar/Eliminar',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
