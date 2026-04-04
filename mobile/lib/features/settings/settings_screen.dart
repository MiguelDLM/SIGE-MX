import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/server_config.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlController;
  bool _editingUrl = false;

  @override
  void initState() {
    super.initState();
    _urlController =
        TextEditingController(text: ref.read(serverUrlProvider) ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await ref.read(serverUrlProvider.notifier).setUrl(url);
    setState(() => _editingUrl = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('URL actualizada')));
    }
  }

  Future<void> _resetServer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambiar servidor'),
        content: const Text(
            'Se cerrará tu sesión y tendrás que configurar la URL nuevamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).logout();
      await ref.read(serverUrlProvider.notifier).clearUrl();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final isAdmin = auth is AuthAuthenticated &&
        (auth.primaryRole == 'directivo' ||
            auth.primaryRole == 'control_escolar');
    final serverUrl = ref.watch(serverUrlProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          // ── Conexión ──────────────────────────────────────────────
          const _SectionHeader('Conexión'),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Servidor'),
            subtitle: _editingUrl
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                          onPressed: _saveUrl, child: const Text('Guardar')),
                    ]),
                  )
                : Text(serverUrl ?? '—',
                    style: const TextStyle(fontFamily: 'monospace')),
            trailing: _editingUrl
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _editingUrl = false),
                  )
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar URL',
                    onPressed: () => setState(() => _editingUrl = true),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_outlined),
            title: const Text('Cambiar de servidor'),
            subtitle: const Text('Reconfigurar y cerrar sesión'),
            onTap: _resetServer,
          ),

          // ── Sistema (solo admin) ───────────────────────────────────
          if (isAdmin) ...[
            const Divider(),
            const _SectionHeader('Administración del sistema'),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Información del plantel'),
              subtitle: const Text('Nombre, CCT, turno, dirección'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/config'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Ciclo escolar activo'),
              subtitle: const Text('Gestionar periodos académicos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/cycles'),
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Gestión de usuarios'),
              subtitle: const Text('Crear y administrar cuentas'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/users'),
            ),
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('Gestión de eventos'),
              subtitle: const Text('Crear y editar eventos del plantel'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/events'),
            ),
          ],

          // ── Sesión ────────────────────────────────────────────────
          const Divider(),
          const _SectionHeader('Sesión'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.red)),
            onTap: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
