import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sige_mx/core/auth/auth_notifier.dart';
import 'package:sige_mx/core/auth/auth_state.dart';
import 'package:sige_mx/features/justifications/justifications_provider.dart';
import 'package:sige_mx/features/reports/reports_screen.dart';
import 'package:sige_mx/shared/models/student.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthAuthenticated(
        userId: 'u1',
        roles: ['padre'],
        primaryRole: 'padre',
      );
}

void main() {
  testWidgets('reports screen shows boleta and constancia buttons', (tester) async {
    final fakeStudents = [
      Student(
          id: 's1',
          matricula: 'A001',
          nombre: 'Laura',
          apellidoPaterno: 'García'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
          myStudentsProvider.overrideWith((_) => Future.value(fakeStudents)),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boleta_s1')), findsOneWidget);
    expect(find.byKey(const Key('constancia_s1')), findsOneWidget);
  });
}
