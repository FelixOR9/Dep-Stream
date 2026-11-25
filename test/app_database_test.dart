import 'dart:io';

import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/match_repository.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  // Se usa databaseFactoryFfiNoIsolate (FFI directo, sin isolate aparte):
  // la factoría por defecto corre SQLite en otro isolate y sus respuestas
  // por puerto no llegan dentro del FakeAsync de los widget tests, lo que
  // colgaba `pumpWidget`. Solo afecta a los tests; la app usa el plugin
  // sqflite real en Android.
  group('AppDatabase + MatchRepository', () {
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

    test('crear, listar, leer y borrar un partido', () async {
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');
      await repository.insert(match);

      final all = await repository.getAll();
      expect(all.length, 1);
      expect(all.first.title, 'Águilas vs Leones');
      expect(all.first.status, MatchStatus.draft);

      final byId = await repository.getById(match.id);
      expect(byId?.homeTeam, 'Águilas');

      await repository.delete(match.id);
      expect(await repository.getAll(), isEmpty);
      expect(await repository.getById(match.id), isNull);
    });

    test('los partidos se listan del más reciente al más antiguo', () async {
      final old = MatchSession.create(
        homeTeam: 'Viejos',
        awayTeam: 'Rivales',
        createdAt: DateTime(2026, 1, 1),
      );
      final recent = MatchSession.create(
        homeTeam: 'Nuevos',
        awayTeam: 'Rivales',
        createdAt: DateTime(2026, 11, 24),
      );
      await repository.insert(old);
      await repository.insert(recent);

      final all = await repository.getAll();
      expect(all.map((m) => m.homeTeam), ['Nuevos', 'Viejos']);
    });

    test('los datos sobreviven al cerrar y reabrir la base', () async {
      final tempDir = await Directory.systemTemp.createTemp('depstream_test');
      final path = '${tempDir.path}/depstream.db';
      try {
        final fileDb = AppDatabase(
          factoryOverride: databaseFactoryFfiNoIsolate,
          path: path,
        );
        final fileRepo = MatchRepository(fileDb);
        await fileRepo.insert(
          MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones'),
        );
        await fileDb.close();

        final reopened = AppDatabase(
          factoryOverride: databaseFactoryFfiNoIsolate,
          path: path,
        );
        final reopenedRepo = MatchRepository(reopened);
        expect((await reopenedRepo.getAll()).length, 1);
        await reopened.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
