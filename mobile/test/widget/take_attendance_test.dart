import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:sige_mx/features/attendance/attendance_provider.dart';
import 'package:sige_mx/features/attendance/take_attendance_screen.dart';
import 'package:sige_mx/shared/models/attendance_record.dart';
import 'package:sige_mx/shared/models/student.dart';

void main() {
  setUpAll(() async {
    Hive.init('/tmp/hive_test');
    Hive.registerAdapter(AttendanceRecordAdapter());
    await Hive.openBox<AttendanceRecord>('attendance_pending');
  });

  tearDown(() async {
    await Hive.box<AttendanceRecord>('attendance_pending').clear();
  });

  testWidgets('shows student list for group', (tester) async {
    final fakeStudents = [
      Student(id: 's1', matricula: 'A001', nombre: 'Laura', apellidoPaterno: 'García'),
      Student(id: 's2', matricula: 'A002', nombre: 'Pedro', apellidoPaterno: 'Martínez'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupStudentsProvider('g1').overrideWith(
            (_) => Future.value(fakeStudents),
          ),
        ],
        child: const MaterialApp(
          home: TakeAttendanceScreen(groupId: 'g1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Laura García'), findsOneWidget);
    expect(find.text('Pedro Martínez'), findsOneWidget);
  });
}
