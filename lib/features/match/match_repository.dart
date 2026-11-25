import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/match_event.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:sqflite/sqflite.dart';

/// Acceso a los partidos guardados en SQLite.
///
/// Regla de oro: el marcador es un caché de los eventos de gol. Cada
/// cambio de marcador y su evento se escriben en la misma transacción:
/// nunca se actualiza el marcador sin su evento, ni al revés. La
/// pantalla nunca escribe en la base directamente: lo hace el
/// `MatchController` a través de aquí.
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

  /// Actualiza los datos de configuración de un partido (equipos,
  /// colores, duración, periodos, fecha). Solo se aplica si el partido
  /// sigue en borrador: un partido en curso no se edita desde la base.
  /// Devuelve `true` si se aplicó, `false` si se rechazó.
  Future<bool> update(MatchSession match) async {
    final db = await _database.database;
    final count = await db.update(
      AppDatabase.matchesTable,
      {
        'home_team': match.homeTeam,
        'away_team': match.awayTeam,
        'created_at': match.createdAt.millisecondsSinceEpoch,
        'home_color': match.homeColor,
        'away_color': match.awayColor,
        'period_duration_minutes': match.periodDurationMinutes,
        'periods_count': match.periodsCount,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [match.id, MatchStatus.draft.name],
    );
    return count == 1;
  }

  /// Guarda el progreso de un partido en curso: estado, marcador,
  /// periodo y reloj. Sin comprobación de borrador: es la escritura
  /// que usa el controlador en cada transición y cada cambio de reloj.
  Future<void> saveProgress(MatchSession match) async {
    final db = await _database.database;
    await db.update(
      AppDatabase.matchesTable,
      {
        'status': match.status.name,
        'home_score': match.homeScore,
        'away_score': match.awayScore,
        'current_period': match.currentPeriod,
        'clock_status': match.clockStatus.name,
        'clock_started_at': match.clockStartedAt?.millisecondsSinceEpoch,
        'clock_accumulated_ms': match.clockAccumulatedMs,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [match.id],
    );
  }

  /// Añade un evento (gol o tarjeta) y actualiza el marcador si es gol,
  /// en la misma transacción. Devuelve el evento guardado.
  Future<MatchEvent> addEvent(MatchEvent event) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert(AppDatabase.eventsTable, event.toMap());
      if (event.kind == EventKind.goal) {
        final column = event.team == EventTeam.home
            ? 'home_score'
            : 'away_score';
        await txn.rawUpdate(
          'UPDATE ${AppDatabase.matchesTable} '
          'SET $column = $column + 1, updated_at = ? WHERE id = ?',
          [now, event.matchId],
        );
      } else {
        await txn.rawUpdate(
          'UPDATE ${AppDatabase.matchesTable} '
          'SET updated_at = ? WHERE id = ?',
          [now, event.matchId],
        );
      }
    });
    return event;
  }

  /// Anula el gol más reciente de un equipo: borra su evento y baja el
  /// marcador en 1, en la misma transacción. Devuelve el evento anulado,
  /// o `null` si ese equipo no tenía goles (y no hace nada).
  Future<MatchEvent?> removeLastGoalEvent(
    String matchId,
    EventTeam team,
  ) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    MatchEvent? removed;
    await db.transaction((txn) async {
      final rows = await txn.query(
        AppDatabase.eventsTable,
        where: 'match_id = ? AND team = ? AND kind = ?',
        whereArgs: [matchId, team.name, EventKind.goal.name],
        orderBy: 'created_at DESC, id DESC',
        limit: 1,
      );
      if (rows.isEmpty) return;
      removed = MatchEvent.fromMap(rows.first);
      await txn.delete(
        AppDatabase.eventsTable,
        where: 'id = ?',
        whereArgs: [removed!.id],
      );
      final column = team == EventTeam.home ? 'home_score' : 'away_score';
      await txn.rawUpdate(
        'UPDATE ${AppDatabase.matchesTable} '
        'SET $column = MAX($column - 1, 0), updated_at = ? WHERE id = ?',
        [now, matchId],
      );
    });
    return removed;
  }

  /// Eventos de un partido, del más antiguo al más reciente.
  Future<List<MatchEvent>> getEvents(String matchId) async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.eventsTable,
      where: 'match_id = ?',
      whereArgs: [matchId],
      orderBy: 'minute ASC, created_at ASC',
    );
    return rows.map(MatchEvent.fromMap).toList();
  }
}
