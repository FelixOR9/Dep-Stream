import 'package:dep_stream/app.dart';
import 'package:dep_stream/core/database/app_database.dart';
import 'package:flutter/material.dart';

/// Dep-Stream — Etapa 0: Fundación.
///
/// Arranca la app, crea la base de datos local (v1) y muestra la pantalla
/// principal. Si la base de datos no se puede crear, la app lo muestra en
/// pantalla en lugar de cerrarse en silencio.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  try {
    await database.open();
  } catch (e) {
    runApp(DatabaseErrorApp(error: e.toString()));
    return;
  }
  runApp(DepStreamApp(database: database));
}

/// Pantalla honesta de error si la base de datos no se pudo crear.
class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({required this.error, super.key});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dep-Stream no pudo iniciar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'No se pudo crear la base de datos local. '
                'Libera espacio o reinstala la app. Ningún partido se ha perdido: '
                'no había ninguno guardado.',
              ),
              const SizedBox(height: 12),
              Text(error),
            ],
          ),
        ),
      ),
    );
  }
}
