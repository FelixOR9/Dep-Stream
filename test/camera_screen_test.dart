import 'package:dep_stream/app.dart';
import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/match_clock.dart';
import 'package:dep_stream/features/match/match_repository.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  const permissionsChannel =
      MethodChannel('com.felix.depstream/permissions');
  const cameraChannel = MethodChannel('com.felix.depstream/camera');

  Future<AppDatabase> openTestDatabase() async {
    final database = AppDatabase(
      factoryOverride: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    await database.open();
    return database;
  }

  /// Mock de los dos canales. Devuelve el estado de cámara pedido y
  /// una textura 7 al abrir; anota en el mapa cuántas veces se abrió
  /// (`open`), se cerró (`close`), se pidió solo la cámara
  /// (`requestCamera`) y se abrieron los ajustes (`openAppSettings`).
  /// `requestCamera` concede el permiso (como haría el usuario al
  /// aceptar), así que `checkPermissions` pasa a devolver `granted`.
  Map<String, int> mockChannels({required String cameraStatus}) {
    var granted = cameraStatus == 'granted';
    final calls = <String, int>{
      'open': 0,
      'close': 0,
      'requestCamera': 0,
      'openAppSettings': 0,
    };
    final binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      permissionsChannel,
      (call) async {
        if (call.method == 'checkPermissions') {
          return <String, String>{
            'camera': granted ? 'granted' : cameraStatus,
            'microphone': 'denied',
            'notifications': 'notRequested',
          };
        }
        if (call.method == 'requestCamera') {
          calls['requestCamera'] = calls['requestCamera']! + 1;
          granted = true;
          return <String, String>{'camera': 'granted'};
        }
        if (call.method == 'openAppSettings') {
          calls['openAppSettings'] = calls['openAppSettings']! + 1;
          return null;
        }
        return null;
      },
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      cameraChannel,
      (call) async {
        if (call.method == 'openCamera') {
          calls['open'] = calls['open']! + 1;
          return 7;
        }
        if (call.method == 'closeCamera') {
          calls['close'] = calls['close']! + 1;
          return null;
        }
        if (call.method == 'getCameraState') {
          return <String, Object?>{'state': 'open', 'errorCode': null};
        }
        return null;
      },
    );
    addTearDown(() {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionsChannel, null);
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, null);
    });
    return calls;
  }

  Future<void> openMatchScreen(
    WidgetTester tester,
    AppDatabase database,
    MatchSession match,
  ) async {
    await tester.pumpWidget(DepStreamApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text(match.title));
    // Se deja completar la transición de ruta: a mitad de la transición
    // hay dos Scrollable visibles y scrollUntilVisible no puede elegir
    // uno (en la práctica hacen falta ~900 ms acumulados de avance).
    // Con pumpAndSettle no vale aquí: con el partido en vivo el Timer
    // de 1 s del controlador nunca deja asentar.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapCameraButton(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Cámara'), 200);
    await tester.pump();
    await tester.tap(find.text('Cámara'));
    // Se deja completar la transición a la pantalla de cámara (ver el
    // comentario de openMatchScreen): a mitad, la pantalla de partido
    // sigue visible debajo y sus botones duplican los de la cámara.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<MatchSession> startMatch(
    AppDatabase database,
    MatchSession match,
  ) async {
    final started = match.copyWith(
      status: MatchStatus.inProgress,
      clockStatus: ClockStatus.running,
      clockStartedAt: DateTime.now(),
      clearClockStartedAt: false,
    );
    await MatchRepository(database).saveProgress(started);
    return started;
  }

  group('CameraScreen', () {
    testWidgets('con permiso muestra el visor y el overlay del partido',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      mockChannels(cameraStatus: 'granted');
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);
      await startMatch(database, match);

      await openMatchScreen(tester, database, match);
      await tapCameraButton(tester);

      expect(find.byType(Texture), findsOneWidget);
      expect(find.text('Águilas'), findsWidgets);
      expect(find.text('Leones'), findsWidgets);
      expect(find.text('0 - 0'), findsOneWidget);
      expect(find.text('GOL ÁGUILAS +1'), findsOneWidget);
      expect(find.text('GOL LEONES +1'), findsOneWidget);
      expect(find.text('Pausa'), findsOneWidget);
    });

    testWidgets(
        'sin permiso muestra la pantalla honesta y no abre la cámara',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final calls = mockChannels(cameraStatus: 'denied');
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);
      await tapCameraButton(tester);

      expect(find.byType(Texture), findsNothing);
      expect(
        find.textContaining('necesita acceso a la cámara'),
        findsOneWidget,
      );
      expect(find.text('Volver al partido'), findsOneWidget);
      expect(calls['open'], 0);
    });

    testWidgets('tocar GOL LOCAL +1 en la cámara sube el marcador a 1-0',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      mockChannels(cameraStatus: 'granted');
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);
      await startMatch(database, match);

      await openMatchScreen(tester, database, match);
      await tapCameraButton(tester);
      await tester.tap(find.text('GOL ÁGUILAS +1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final saved = await MatchRepository(database).getById(match.id);
      expect(saved?.homeScore, 1);
      expect(find.text('1 - 0'), findsOneWidget);
    });

    testWidgets('en un partido finalizado no hay botones de gol ni pausa',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      mockChannels(cameraStatus: 'granted');
      final match = MatchSession.create(
        homeTeam: 'Águilas',
        awayTeam: 'Leones',
      ).copyWith(
        status: MatchStatus.finished,
        homeScore: 2,
        awayScore: 1,
        clockStatus: ClockStatus.finished,
        clockAccumulatedMs: 45 * 60 * 1000,
        clearClockStartedAt: true,
      );
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);
      await tapCameraButton(tester);

      expect(find.text('2 - 1'), findsOneWidget);
      expect(find.textContaining('GOL'), findsNothing);
      expect(find.text('Pausa'), findsNothing);
      expect(find.text('Reanudar'), findsNothing);
    });

    testWidgets(
        'denegada: Pedir permiso concede y la cámara se abre',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final calls = mockChannels(cameraStatus: 'denied');
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);
      await tapCameraButton(tester);
      expect(find.text('Pedir permiso'), findsOneWidget);
      expect(find.text('Abrir ajustes'), findsNothing);
      expect(calls['open'], 0);

      await tester.tap(find.text('Pedir permiso'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(calls['requestCamera'], 1);
      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets(
        'denegada para siempre: el botón es Abrir ajustes, no Pedir permiso',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final calls = mockChannels(cameraStatus: 'permanentlyDenied');
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);
      await tapCameraButton(tester);

      expect(find.text('Abrir ajustes'), findsOneWidget);
      expect(find.text('Pedir permiso'), findsNothing);
      expect(calls['open'], 0);

      await tester.tap(find.text('Abrir ajustes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(calls['openAppSettings'], 1);
      expect(calls['requestCamera'], 0);
    });

    testWidgets('Volver al partido cierra la cámara', (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final calls = mockChannels(cameraStatus: 'granted');
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);
      await tapCameraButton(tester);
      expect(calls['open'], 1);

      await tester.tap(find.text('Volver al partido'));
      // Se deja completar la transición de vuelta: el dispose de la
      // pantalla (que cierra la cámara) corre al terminar la transición.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(calls['close'], 1);
      // Se volvió a la pantalla de partido.
      expect(find.text('Iniciar partido'), findsOneWidget);
    });
  });
}
