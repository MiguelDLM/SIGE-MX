import 'package:dio/dio.dart';
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
  bool _testingUrl = false;
  String? _urlError;

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
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return;
    final url = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

    setState(() {
      _testingUrl = true;
      _urlError = null;
    });

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
      await dio.get('$url/health');
      await ref.read(serverUrlProvider.notifier).setUrl(url);
      setState(() {
        _editingUrl = false;
        _urlError = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('URL actualizada')));
      }
    } on DioException catch (e) {
      setState(() {
        _urlError = (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout)
            ? 'Tiempo de espera agotado. Verifica la URL y que el servidor esté activo.'
            : 'No se pudo conectar al servidor: ${e.message}';
      });
    } catch (e) {
      setState(() => _urlError = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _testingUrl = false);
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              enabled: !_testingUrl,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText: _urlError,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _testingUrl ? null : _saveUrl,
                            child: _testingUrl
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Guardar'),
                          ),
                        ]),
                      ],
                    ),
                  )
                : Text(serverUrl ?? '—',
                    style: const TextStyle(fontFamily: 'monospace')),
            trailing: _editingUrl
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _testingUrl
                        ? null
                        : () => setState(() {
                              _editingUrl = false;
                              _urlError = null;
                            }),
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
              leading: const Icon(Icons.book_outlined),
              title: const Text('Materias'),
              subtitle: const Text('Gestionar materias del plantel'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/materias'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Grupos y horarios'),
              subtitle: const Text('Crear grupos, asignar alumnos y horarios'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/grupos'),
            ),
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('Gestión de eventos'),
              subtitle: const Text('Crear y editar eventos del plantel'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/events'),
            ),
          ],

          // ── Horario personal ──────────────────────────────────────
          const Divider(),
          const _SectionHeader('Funciones'),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Mi horario'),
            subtitle: const Text('Ver horario de clases (funciona sin conexión)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/mi-horario'),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Mis constancias'),
            subtitle: const Text('Constancias de participación en eventos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/mis-constancias'),
          ),

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
