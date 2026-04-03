import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/attendance_record.dart';

// Exposes whether there are unsynced records (for badge)
final hasPendingSyncProvider = StreamProvider<bool>((ref) {
  final box = Hive.box<AttendanceRecord>('attendance_pending');
  return box.watch().map((_) => box.values.any((r) => r.syncState == 'pending'));
});

// Background sync — call once in main or AppShell initState
final attendanceSyncServiceProvider = Provider<AttendanceSyncService>((ref) {
  return AttendanceSyncService(ref);
});

class AttendanceSyncService {
  final Ref _ref;
  AttendanceSyncService(this._ref) {
    _listenConnectivity();
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncPending();
      }
    });
  }

  Future<void> syncPending() async {
    final box = Hive.box<AttendanceRecord>('attendance_pending');
    final pending = box.values.where((r) => r.syncState == 'pending').toList();
    if (pending.isEmpty) return;

    final dio = _ref.read(apiClientProvider);
    for (final record in pending) {
      try {
        await dio.post('/api/v1/attendance/', data: {
          'student_id': record.studentId,
          'group_id': record.groupId,
          'fecha': record.fecha,
          'status': record.status,
        });
        record.syncState = 'synced';
        await record.save();
      } catch (_) {
        // leave as pending — retry next connectivity event
      }
    }
  }
}
