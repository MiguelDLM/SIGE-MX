import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/models/attendance_record.dart';

final hasPendingSyncProvider = StreamProvider<bool>((ref) {
  final box = Hive.box<AttendanceRecord>('attendance_pending');
  return box.watch().map((_) => box.values.any((r) => r.syncState == 'pending'));
});
