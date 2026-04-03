import 'package:hive/hive.dart';

part 'attendance_record.g.dart';

@HiveType(typeId: 0)
class AttendanceRecord extends HiveObject {
  @HiveField(0)
  final String studentId;

  @HiveField(1)
  final String groupId;

  @HiveField(2)
  final String fecha;

  @HiveField(3)
  String status;

  @HiveField(4)
  String syncState;

  AttendanceRecord({
    required this.studentId,
    required this.groupId,
    required this.fecha,
    required this.status,
    this.syncState = 'pending',
  });
}
