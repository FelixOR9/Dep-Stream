import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/core/theme/app_theme.dart';
import 'package:dep_stream/features/home/home_screen.dart';
import 'package:dep_stream/features/match/create_match_screen.dart';
import 'package:dep_stream/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';

/// Raíz de la app. Recibe la base de datos ya abierta desde `main` para
/// poder inyectar una base en memoria en los tests.
class DepStreamApp extends StatelessWidget {
  const DepStreamApp({required this.database, super.key});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dep-Stream',
      theme: AppTheme.dark(),
      home: HomeScreen(database: database),
      routes: {
        CreateMatchScreen.routeName: (context) =>
            CreateMatchScreen(database: database),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
      },
    );
  }
}
