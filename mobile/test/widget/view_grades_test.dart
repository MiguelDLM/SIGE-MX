import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sige_mx/features/grades/grades_provider.dart';
import 'package:sige_mx/features/grades/view_grades_screen.dart';
import 'package:sige_mx/shared/models/grade.dart';

void main() {
  testWidgets('shows grades for student', (tester) async {
    final fakeGrades = [
      Grade(id: 'g1', evaluationId: 'eval1', studentId: 's1', calificacion: '9.5'),
      Grade(id: 'g2', evaluationId: 'eval2', studentId: 's1', calificacion: '7.0'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentGradesProvider('s1').overrideWith(
            (_) => Future.value(fakeGrades),
          ),
        ],
        child: const MaterialApp(
          home: ViewGradesScreen(studentId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9.5'), findsOneWidget);
    expect(find.text('7.0'), findsOneWidget);
  });

  testWidgets('shows empty state when no grades', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentGradesProvider('s2').overrideWith(
            (_) => Future.value(<Grade>[]),
          ),
        ],
        child: const MaterialApp(
          home: ViewGradesScreen(studentId: 's2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin calificaciones registradas'), findsOneWidget);
  });
}
