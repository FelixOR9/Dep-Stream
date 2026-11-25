import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:sqflite/sqflite.dart';

/// Acceso a los partidos guardados en SQLite.
class MatchRepository {
  MatchRepository(this._database);

  final AppDatabase _database;

  Future<void> insert(MatchSession match) async {
    final db = await _database.database;
    await db.insert(
      AppDatabase.matchesTable,
      match.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Todos los partidos, del más reciente al más antiguo.
  Future<List<MatchSession>> getAll() async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.matchesTable,
      orderBy: 'created_at DESC',
    );
    return rows.map(MatchSession.fromMap).toList();
  }

  Future<MatchSession?> getById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.matchesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MatchSession.fromMap(rows.first);
  }

  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.matchesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
