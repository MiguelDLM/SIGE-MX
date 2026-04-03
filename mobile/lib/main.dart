import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'shared/models/attendance_record.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(AttendanceRecordAdapter());
  await Hive.openBox<AttendanceRecord>('attendance_pending');
  await Hive.openBox<String>('settings');
  runApp(const ProviderScope(child: SigeApp()));
}

class SigeApp extends ConsumerWidget {
  const SigeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SIGE-MX',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
