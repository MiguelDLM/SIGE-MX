import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Configuración',
                onPressed: () => context.push('/settings'),
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
        ..._cardsForRole(context, auth.primaryRole),
      ],
    );
  }

  List<Widget> _cardsForRole(BuildContext context, String role) {
    final cards = <Widget>[];
    
    if (role == 'directivo' || role == 'control_escolar') {
      cards.addAll([
        _InfoCard(
          Icons.people_outline,
          'Usuarios',
          'Gestión de personal y accesos',
          onTap: () => context.push('/admin/users'),
        ),
        _InfoCard(
          Icons.group_work_outlined,
          'Grupos',
          'Organización de grados y secciones',
          onTap: () => context.push('/admin/grupos'),
        ),
        _InfoCard(
          Icons.school_outlined,
          'Maestros',
          'Plantilla docente y especialidades',
          onTap: () => context.push('/admin/maestros'),
        ),
        _InfoCard(
          Icons.person_search_outlined,
          'Alumnos',
          'Gestión de expedientes y padres',
          onTap: () => context.push('/admin/alumnos'),
        ),
        _InfoCard(
          Icons.settings_applications_outlined,
          'Configuración',
          'Ajustes del ciclo escolar y escuela',
          onTap: () => context.push('/admin/config'),
        ),
      ]);
    }

    if (role == 'docente') {
      cards.addAll([
        _InfoCard(Icons.checklist, 'Asistencia', 'Toma lista de tus grupos',
            onTap: () => context.push('/attendance')),
        _InfoCard(Icons.grade, 'Calificaciones', 'Captura evaluaciones',
            onTap: () => context.push('/grades')),
        _InfoCard(Icons.schedule, 'Mi Horario', 'Consulta tus clases',
            onTap: () => context.push('/mi-horario')),
      ]);
    }

    if (role == 'padre' || role == 'alumno') {
      cards.addAll([
        _InfoCard(Icons.checklist, 'Asistencia', 'Consulta el registro',
            onTap: () => context.push('/attendance')),
        _InfoCard(Icons.grade, 'Calificaciones', 'Consulta tus materias',
            onTap: () => context.push('/grades')),
        _InfoCard(Icons.calendar_month, 'Mi Horario', 'Horario de clases',
            onTap: () => context.push('/mi-horario')),
      ]);
    }

    return cards;
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
  final VoidCallback? onTap;
  const _InfoCard(this.icon, this.title, this.subtitle, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
          child: Icon(icon, color: const Color(0xFF1976D2)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ),
    );
  }
}
