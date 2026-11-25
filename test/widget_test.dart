import 'package:dep_stream/app.dart';
import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  // NoIsolate: ver el comentario en app_database_test.dart. La factoría
  // por defecto (con isolate aparte) cuelga `pumpWidget` en los tests.
  Future<AppDatabase> openTestDatabase() async {
    final database = AppDatabase(
      factoryOverride: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    await database.open();
    return database;
  }

  group('DepStreamApp', () {
    testWidgets('muestra la lista vacía con mensaje honesto', (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      await tester.pumpWidget(DepStreamApp(database: database));
      await tester.pumpAndSettle();

      expect(find.text('Dep-Stream'), findsWidgets);
      expect(find.textContaining('Aún no hay partidos'), findsOneWidget);
      expect(find.text('Crear partido'), findsOneWidget);
    });

    testWidgets('crear un partido lo muestra en la lista', (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      await tester.pumpWidget(DepStreamApp(database: database));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear partido'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Equipo local'),
        'Águilas',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Equipo visitante'),
        'Leones',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar partido'));
      await tester.pumpAndSettle();

      expect(find.text('Águilas vs Leones'), findsOneWidget);
      expect(find.text('Borrador'), findsOneWidget);
    });

    testWidgets('el formulario exige los dos equipos', (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      await tester.pumpWidget(DepStreamApp(database: database));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear partido'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar partido'));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(find.text('Escribe el equipo local'), findsOneWidget);
      expect(find.text('Escribe el equipo visitante'), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    const channel = MethodChannel('com.felix.depstream/permissions');

    testWidgets('muestra el estado real de cada permiso', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'checkPermissions') {
              return <String, String>{
                'camera': 'granted',
                'microphone': 'denied',
                'notifications': 'notRequested',
              };
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Versión 0.3.0+3 (Etapa 2: Cámara y overlay)'), findsOneWidget);
      expect(find.text('Cámara'), findsOneWidget);
      expect(find.textContaining('Concedido'), findsOneWidget);
      expect(find.textContaining('Negado'), findsOneWidget);
      expect(find.textContaining('Sin pedir'), findsOneWidget);
    });
  });
}
