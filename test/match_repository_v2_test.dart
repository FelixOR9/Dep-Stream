import 'dart:io';

import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/match_clock.dart';
import 'package:dep_stream/features/match/match_event.dart';
import 'package:dep_stream/features/match/match_repository.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Migración v1 → v2', () {
    /// Crea una base **v1 real** (el esquema exacto de la Etapa 0) con un
    /// partido en borrador, como la que Félix tiene en su teléfono.
    Future<String> createV1Database() async {
      final tempDir = await Directory.systemTemp.createTemp('depstream_v1');
      final path = '${tempDir.path}/depstream.db';
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE matches (
                id TEXT PRIMARY KEY,
                home_team TEXT NOT NULL,
                away_team TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                status TEXT NOT NULL
              )
            ''');
          },
        ),
      );
      await db.insert('matches', {
        'id': 'v1-partido',
        'home_team': 'Águilas',
        'away_team': 'Leones',
        'created_at': 1764000000000,
        'status': 'draft',
      });
      await db.close();
      return path;
    }

    test('la migración conserva el partido de la Etapa 0', () async {
      final path = await createV1Database();
      final tempDir = Directory(path).parent;
      try {
        final database = AppDatabase(
          factoryOverride: databaseFactoryFfiNoIsolate,
          path: path,
        );
        addTearDown(database.close);
        final repository = MatchRepository(database);

        final match = await repository.getById('v1-partido');
        expect(match, isNotNull);
        expect(match!.homeTeam, 'Águilas');
        expect(match.awayTeam, 'Leones');
        expect(match.status, MatchStatus.draft);
        // Valores por defecto de la migración, sin tocar lo existente.
        expect(match.homeScore, 0);
        expect(match.awayScore, 0);
        expect(match.homeColor, '#D32F2F');
        expect(match.awayColor, '#1976D2');
        expect(match.periodDurationMinutes, 45);
        expect(match.periodsCount, 2);
        expect(match.currentPeriod, 1);
        expect(match.clockStatus, ClockStatus.stopped);
        expect(match.clockStartedAt, isNull);
        expect(match.clockAccumulatedMs, 0);
        expect(match.createdAt.millisecondsSinceEpoch, 1764000000000);
        expect(
          match.updatedAt.millisecondsSinceEpoch,
          match.createdAt.millisecondsSinceEpoch,
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('una base migrada y una base nueva en v2 tienen el mismo esquema',
        () async {
      final path = await createV1Database();
      final tempDir = Directory(path).parent;
      try {
        final migrated = AppDatabase(
          factoryOverride: databaseFactoryFfiNoIsolate,
          path: path,
        );
        addTearDown(migrated.close);
        final migratedDb = await migrated.open();

        final fresh = AppDatabase(
          factoryOverride: databaseFactoryFfiNoIsolate,
          path: inMemoryDatabasePath,
        );
        addTearDown(fresh.close);
        final freshDb = await fresh.open();

        // Se compara por PRAGMA (columnas e índices reales), no por el
        // texto del CREATE TABLE: SQLite guarda el SQL con distinto
        // formato tras un ALTER TABLE, aunque las columnas sean idénticas.
        Future<Set<String>> schema(Database db) async {
          final result = <String>{};
          for (final table in ['matches', 'match_events']) {
            final columns = await db.rawQuery('PRAGMA table_info($table)');
            for (final c in columns) {
              result.add(
                'col:$table:${c['name']}:${c['type']}:${c['notnull']}:'
                "${c['dflt_value']}:${c['pk']}",
              );
            }
            final indexes = await db.rawQuery('PRAGMA index_list($table)');
            for (final i in indexes) {
              final cols = await db.rawQuery(
                "PRAGMA index_info(${i['name']})",
              );
              result.add(
                "idx:$table:${i['name']}:${i['unique']}:"
                "${cols.map((c) => c['name']).join(',')}",
              );
            }
          }
          return result;
        }

        expect(await schema(migratedDb), await schema(freshDb));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('Eventos y marcador', () {
    late AppDatabase database;
    late MatchRepository repository;

    setUp(() {
      database = AppDatabase(
        factoryOverride: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
      repository = MatchRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    Future<MatchSession> createMatch() async {
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await repository.insert(match);
      return match;
    }

    test('gol +1 → marcador 1-0 y un evento', () async {
      final match = await createMatch();
      await repository.addEvent(
        MatchEvent.create(
          matchId: match.id,
          team: EventTeam.home,
          kind: EventKind.goal,
          minute: 24,
        ),
      );

      final updated = await repository.getById(match.id);
      expect(updated!.homeScore, 1);
      expect(updated.awayScore, 0);
      final events = await repository.getEvents(match.id);
      expect(events.length, 1);
      expect(events.first.kind, EventKind.goal);
      expect(events.first.minute, 24);
    });

    test('gol −1 → marcador 0-0 y cero eventos', () async {
      final match = await createMatch();
      await repository.addEvent(
        MatchEvent.create(
          matchId: match.id,
          team: EventTeam.home,
          kind: EventKind.goal,
          minute: 24,
        ),
      );
      final removed = await repository.removeLastGoalEvent(
        match.id,
        EventTeam.home,
      );

      expect(removed, isNotNull);
      expect(removed!.minute, 24);
      final updated = await repository.getById(match.id);
      expect(updated!.homeScore, 0);
      expect(await repository.getEvents(match.id), isEmpty);
    });

    test('−1 sin goles no hace nada y no rompe nada', () async {
      final match = await createMatch();
      final removed = await repository.removeLastGoalEvent(
        match.id,
        EventTeam.away,
      );

      expect(removed, isNull);
      final updated = await repository.getById(match.id);
      expect(updated!.awayScore, 0);
    });

    test('una tarjeta no cambia el marcador', () async {
      final match = await createMatch();
      await repository.addEvent(
        MatchEvent.create(
          matchId: match.id,
          team: EventTeam.home,
          kind: EventKind.yellow,
          minute: 31,
        ),
      );

      final updated = await repository.getById(match.id);
      expect(updated!.homeScore, 0);
      final events = await repository.getEvents(match.id);
      expect(events.length, 1);
      expect(events.first.kind, EventKind.yellow);
    });

    test('2 goles + 1 amarilla → lista de eventos con minutos correctos',
        () async {
      final match = await createMatch();
      await repository.addEvent(
        MatchEvent.create(
          matchId: match.id,
          team: EventTeam.home,
          kind: EventKind.goal,
          minute: 10,
        ),
      );
      await repository.addEvent(
        MatchEvent.create(
          matchId: match.id,
          team: EventTeam.away,
          kind: EventKind.goal,
          minute: 20,
        ),
      );
      await repository.addEvent(
        MatchEvent.create(
          matchId: match.id,
          team: EventTeam.home,
          kind: EventKind.yellow,
          minute: 31,
        ),
      );

      final updated = await repository.getById(match.id);
      expect(updated!.scoreText, '1 - 1');
      final events = await repository.getEvents(match.id);
      expect(events.map((e) => e.minute), [10, 20, 31]);
      expect(events.map((e) => e.kind.label), ['Gol', 'Gol', 'Amarilla']);
    });

    test('los eventos sobreviven al cerrar y reabrir la base', () async {
      final tempDir = await Directory.systemTemp.createTemp('depstream_test');
      final path = '${tempDir.path}/depstream.db';
      try {
        final fileDb = AppDatabase(
          factoryOverride: databaseFactoryFfiNoIsolate,
          path: path,
        );
        final fileRepo = MatchRepository(fileDb);
        final match = MatchSession.create(
          homeTeam: 'Águilas',
          awayTeam: 'Leones',
        );
        await fileRepo.insert(match);
        await fileRepo.addEvent(
          MatchEvent.create(
            matchId: match.id,
            team: EventTeam.home,
            kind: EventKind.goal,
            minute: 5,
          ),
        );
        await fileDb.close();

        final reopened = AppDatabase(
          factoryOverride: databaseFactoryFfiNoIsolate,
          path: path,
        );
        final reopenedRepo = MatchRepository(reopened);
        final restored = await reopenedRepo.getById(match.id);
        expect(restored!.homeScore, 1);
        expect((await reopenedRepo.getEvents(match.id)).length, 1);
        await reopened.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('update() de configuración solo se aplica en borrador', () async {
      final match = await createMatch();
      final edited = match.copyWith(homeTeam: 'Tigres');
      expect(await repository.update(edited), isTrue);
      expect((await repository.getById(match.id))!.homeTeam, 'Tigres');

      final inProgress = edited.copyWith(status: MatchStatus.inProgress);
      await repository.saveProgress(inProgress);
      final rejected = inProgress.copyWith(homeTeam: 'Pumas');
      expect(await repository.update(rejected), isFalse);
      expect((await repository.getById(match.id))!.homeTeam, 'Tigres');
    });
  });
}
