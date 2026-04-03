import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sige_mx/core/auth/auth_notifier.dart';
import 'package:sige_mx/core/auth/auth_state.dart';
import 'package:sige_mx/features/auth/login_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final bool shouldFail;
  _FakeAuthNotifier({required this.shouldFail});

  @override
  Future<AuthState> build() async => const AuthUnauthenticated();

  @override
  Future<void> login(String email, String password) async {
    if (shouldFail) throw Exception('401');
    state = const AsyncData(AuthAuthenticated(
      userId: 'u1',
      roles: ['docente'],
      primaryRole: 'docente',
    ));
  }
}

Widget _wrap(AuthNotifier notifier) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => notifier),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('shows error on login failure', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthNotifier(shouldFail: true)));
    await tester.enterText(find.byKey(const Key('email_field')), 'x@x.com');
    await tester.enterText(find.byKey(const Key('password_field')), 'wrong');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_error')), findsOneWidget);
  });

  testWidgets('no error shown on successful login', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthNotifier(shouldFail: false)));
    await tester.enterText(find.byKey(const Key('email_field')), 'teacher@school.mx');
    await tester.enterText(find.byKey(const Key('password_field')), 'pass123');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_error')), findsNothing);
  });
}
