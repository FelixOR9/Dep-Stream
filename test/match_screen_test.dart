import 'package:dep_stream/app.dart';
import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/match_repository.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  // NoIsolate: ver el comentario en app_database_test.dart.
  Future<AppDatabase> openTestDatabase() async {
    final database = AppDatabase(
      factoryOverride: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    await database.open();
    return database;
  }

  Future<void> openMatchScreen(
    WidgetTester tester,
    AppDatabase database,
    MatchSession match,
  ) async {
    await tester.pumpWidget(DepStreamApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text(match.title));
    await tester.pumpAndSettle();
  }

  group('MatchScreen', () {
    testWidgets('un borrador muestra 0-0, 00:00 e "Iniciar partido"',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);

      expect(find.text('Águilas'), findsWidgets);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('Iniciar partido'), findsOneWidget);
      expect(find.text('Borrador'), findsWidgets);
    });

    testWidgets('tocar "Iniciar partido" muestra "En vivo"', (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);
      await tester.scrollUntilVisible(find.text('Iniciar partido'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar partido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('En vivo'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Pausa'), 200);
      await tester.pump();
      expect(find.text('Pausa'), findsOneWidget);
    });

    testWidgets('tocar "GOL LOCAL +1" muestra 1-0 y el evento en la lista',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);
      await tester.scrollUntilVisible(find.text('Iniciar partido'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar partido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(find.text('GOL ÁGUILAS +1'), 200);
      await tester.pump();
      await tester.tap(find.text('GOL ÁGUILAS +1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(find.text('Gol de Águilas'), 200);
      await tester.pump();
      expect(find.text('Gol de Águilas'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('−1'), -200);
      await tester.pump();
      expect(find.textContaining('−1'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('1'), -200);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('en un partido finalizado no hay botones de gol ni tarjeta',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final match = MatchSession.create(
        homeTeam: 'Águilas',
        awayTeam: 'Leones',
      ).copyWith(status: MatchStatus.finished, homeScore: 2, awayScore: 1);
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);

      await tester.scrollUntilVisible(find.text('Partido finalizado'), 200);
      await tester.pump();
      expect(find.text('Partido finalizado'), findsOneWidget);
      expect(find.textContaining('GOL'), findsNothing);
      expect(find.textContaining('Amarilla'), findsNothing);
      expect(find.textContaining('Roja'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('el botón −1 no aparece si el equipo no tiene goles',
        (tester) async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await MatchRepository(database).insert(match);

      await openMatchScreen(tester, database, match);
      await tester.scrollUntilVisible(find.text('Iniciar partido'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar partido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('−1'), findsNothing);
    });
  });
}
