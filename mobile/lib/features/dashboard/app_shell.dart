import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../features/attendance/attendance_sync_service.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    final hasPending = ref.watch(hasPendingSyncProvider);

    return authAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (auth) {
        if (auth is! AuthAuthenticated) return child;
        final tabs = _tabsForRole(auth.primaryRole);
        final currentIndex = _indexForLocation(
            GoRouterState.of(context).matchedLocation, tabs);

        return Scaffold(
          body: child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: currentIndex,
            selectedItemColor: const Color(0xFF1976D2),
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            onTap: (i) => context.go(tabs[i].path),
            items: tabs.map((t) {
              final showBadge = t.path == '/attendance' && hasPending.valueOrNull == true;
              return BottomNavigationBarItem(
                icon: showBadge
                    ? Badge(
                        backgroundColor: Colors.orange,
                        child: Icon(t.icon),
                      )
                    : Icon(t.icon),
                label: t.label,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  int _indexForLocation(String location, List<_Tab> tabs) {
    for (int i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].path)) return i;
    }
    return 0;
  }

  List<_Tab> _tabsForRole(String role) {
    switch (role) {
      case 'docente':
        return [
          _Tab('/home', 'Inicio', Icons.home_outlined),
          _Tab('/attendance', 'Asistencia', Icons.checklist_outlined),
          _Tab('/grades', 'Calificaciones', Icons.grade_outlined),
        ];
      case 'padre':
        return [
          _Tab('/home', 'Inicio', Icons.home_outlined),
          _Tab('/attendance', 'Asistencia', Icons.checklist_outlined),
          _Tab('/grades', 'Calificaciones', Icons.grade_outlined),
        ];
      case 'alumno':
        return [
          _Tab('/home', 'Inicio', Icons.home_outlined),
          _Tab('/attendance', 'Mi Asistencia', Icons.checklist_outlined),
          _Tab('/grades', 'Mis Calificaciones', Icons.grade_outlined),
        ];
      case 'directivo':
        return [
          _Tab('/home', 'Inicio', Icons.home_outlined),
          _Tab('/students', 'Alumnos', Icons.people_outlined),
          _Tab('/groups', 'Grupos', Icons.group_outlined),
          _Tab('/reports', 'Reportes', Icons.picture_as_pdf_outlined),
        ];
      case 'control_escolar':
        return [
          _Tab('/home', 'Inicio', Icons.home_outlined),
          _Tab('/students', 'Alumnos', Icons.people_outlined),
          _Tab('/imports', 'Importar', Icons.upload_file_outlined),
          _Tab('/reports', 'Constancias', Icons.picture_as_pdf_outlined),
        ];
      default:
        return [_Tab('/home', 'Inicio', Icons.home_outlined)];
    }
  }
}

class _Tab {
  final String path;
  final String label;
  final IconData icon;
  const _Tab(this.path, this.label, this.icon);
}
