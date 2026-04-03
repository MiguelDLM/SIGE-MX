import 'package:hive_flutter/hive_flutter.dart';

part 'attendance_record.g.dart';

// TODO(task4): generate adapter with build_runner
@HiveType(typeId: 0)
class AttendanceRecord extends HiveObject {
  @HiveField(0)
  late String studentId;

  @HiveField(1)
  late String groupId;

  @HiveField(2)
  late String fecha;

  @HiveField(3)
  late String status; // presente | ausente | justificado

  @HiveField(4)
  late String syncState; // pending | synced
}
