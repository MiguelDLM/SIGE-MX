import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    return authAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (auth) {
        if (auth is! AuthAuthenticated) return const SizedBox.shrink();
        return Scaffold(
          appBar: AppBar(
            title: const Text('SIGE-MX'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).logout(),
              ),
            ],
          ),
          body: _HomeBody(auth: auth),
        );
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  final AuthAuthenticated auth;
  const _HomeBody({required this.auth});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WelcomeCard(role: auth.primaryRole),
        const SizedBox(height: 16),
        ..._cardsForRole(auth.primaryRole),
      ],
    );
  }

  List<Widget> _cardsForRole(String role) {
    switch (role) {
      case 'docente':
        return [
          _InfoCard(Icons.checklist, 'Asistencia', 'Toma lista de tus grupos'),
          _InfoCard(Icons.grade, 'Calificaciones', 'Captura evaluaciones'),
        ];
      case 'padre':
      case 'alumno':
        return [
          _InfoCard(Icons.checklist, 'Asistencia', 'Consulta el registro'),
          _InfoCard(Icons.grade, 'Calificaciones', 'Consulta tus materias'),
        ];
      case 'directivo':
        return [
          _InfoCard(Icons.people, 'Alumnos', 'Lista de alumnos inscritos'),
          _InfoCard(Icons.picture_as_pdf, 'Reportes', 'Genera boletas y constancias'),
        ];
      case 'control_escolar':
        return [
          _InfoCard(Icons.people, 'Alumnos', 'Gestión de alumnos'),
          _InfoCard(Icons.upload_file, 'Importar', 'Carga de datos CSV/Excel'),
        ];
      default:
        return [];
    }
  }
}

class _WelcomeCard extends StatelessWidget {
  final String role;
  const _WelcomeCard({required this.role});

  String _label(String role) {
    const map = {
      'docente': 'Docente',
      'padre': 'Padre/Tutor',
      'alumno': 'Alumno',
      'directivo': 'Directivo',
      'control_escolar': 'Control Escolar',
    };
    return map[role] ?? role;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1976D2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.school, color: Colors.white, size: 40),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bienvenido',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(_label(role),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoCard(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1976D2)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
