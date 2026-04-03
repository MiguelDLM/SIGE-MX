import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../config/server_config.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/app_shell.dart';
import '../../features/dashboard/home_screen.dart';
import '../../features/setup/server_setup_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/attendance/take_attendance_screen.dart';
import '../../features/attendance/view_attendance_screen.dart';
import '../../features/grades/capture_grades_screen.dart';
import '../../features/grades/view_grades_screen.dart';
import '../../features/messaging/inbox_screen.dart';
import '../../features/messaging/send_message_screen.dart';
import '../../features/justifications/justification_list_screen.dart';
import '../../features/justifications/submit_justification_screen.dart';
import '../../features/events/events_screen.dart';
import '../../features/reports/reports_screen.dart';

final _routerNotifierProvider =
    ChangeNotifierProvider<_RouterNotifier>((ref) => _RouterNotifier(ref));

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(authNotifierProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen<String?>(serverUrlProvider, (_, __) {
      notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final serverUrl = _ref.read(serverUrlProvider);
    if (serverUrl == null || serverUrl.isEmpty) {
      return state.matchedLocation == '/setup' ? null : '/setup';
    }

    final authAsync = _ref.read(authNotifierProvider);
    return authAsync.when(
      loading: () => null,
      error: (_, __) => '/login',
      data: (auth) {
        final loc = state.matchedLocation;
        if (loc == '/setup') return '/login';
        final isLogin = loc == '/login';
        if (auth is AuthUnauthenticated) return isLogin ? null : '/login';
        if (auth is AuthAuthenticated && isLogin) return '/home';
        return null;
      },
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);
  return GoRouter(
    refreshListenable: notifier,
    redirect: notifier.redirect,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/setup',
        builder: (_, __) => const ServerSetupScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/attendance',
            builder: (_, __) => const AttendanceIndexScreen(),
          ),
          GoRoute(
            path: '/attendance/take/:groupId',
            builder: (_, s) =>
                TakeAttendanceScreen(groupId: s.pathParameters['groupId']!),
          ),
          GoRoute(
            path: '/grades',
            builder: (_, __) => const GradesIndexScreen(),
          ),
          GoRoute(
            path: '/grades/capture/:evaluationId',
            builder: (_, s) => CaptureGradesScreen(
                evaluationId: s.pathParameters['evaluationId']!),
          ),
          GoRoute(
            path: '/grades/view/:studentId',
            builder: (_, s) =>
                ViewGradesScreen(studentId: s.pathParameters['studentId']!),
          ),
          GoRoute(
            path: '/messages',
            builder: (_, __) => const InboxScreen(),
          ),
          GoRoute(
            path: '/messages/new',
            builder: (_, __) => const SendMessageScreen(),
          ),
          GoRoute(
            path: '/justifications',
            builder: (_, __) => const JustificationListScreen(),
          ),
          GoRoute(
            path: '/justifications/new',
            builder: (_, __) => const SubmitJustificationScreen(),
          ),
          GoRoute(
            path: '/events',
            builder: (_, __) => const EventsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (_, __) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/students',
            builder: (_, __) => const _ComingSoon(label: 'Alumnos'),
          ),
          GoRoute(
            path: '/groups',
            builder: (_, __) => const _ComingSoon(label: 'Grupos'),
          ),
          GoRoute(
            path: '/imports',
            builder: (_, __) => const _ComingSoon(label: 'Importar'),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class _ComingSoon extends StatelessWidget {
  final String label;
  const _ComingSoon({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(child: Text('$label — próximamente')),
    );
  }
}

class AttendanceIndexScreen extends ConsumerWidget {
  const AttendanceIndexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    return authAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (auth) {
        if (auth is AuthAuthenticated &&
            auth.primaryRole == 'docente') {
          return const TakeAttendanceGroupListScreen();
        }
        return const ViewAttendanceScreen();
      },
    );
  }
}

class GradesIndexScreen extends ConsumerWidget {
  const GradesIndexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    return authAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (auth) {
        if (auth is AuthAuthenticated && auth.primaryRole == 'docente') {
          return const CaptureGradesGroupListScreen();
        }
        final studentId = auth is AuthAuthenticated ? auth.userId : '';
        return ViewGradesScreen(studentId: studentId);
      },
    );
  }
}
