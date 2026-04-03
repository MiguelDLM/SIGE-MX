import 'package:flutter/material.dart';

// TODO(task3): implement full theme per spec (#1976D2 primary)
class AppTheme {
  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1976D2),
    ),
    useMaterial3: true,
  );
}
