import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local de Dep-Stream, versión 2 (Etapa 1).
///
/// - Tabla `matches`: partido, marcador, colores, duración, periodos y
///   estado del reloj (migración v1 → v2 con `ADD COLUMN`, sin borrar nada).
/// - Tabla `match_events`: cada gol y cada tarjeta, con su minuto.
///   El marcador es un caché de los eventos de gol: ambos se escriben
///   siempre en la misma transacción (ver `MatchRepository`).
class AppDatabase {
  /// Para tests: se puede inyectar otra factoría (por ejemplo, la de FFI en
  /// memoria) y otra ruta. En la app se usan los valores por defecto.
  /// El parámetro se llama `factoryOverride` porque `databaseFactory` es
  /// también el getter de sqflite y lo ocultaría en la lista inicializadora.
  AppDatabase({DatabaseFactory? factoryOverride, String? path})
    : _databaseFactory = factoryOverride ?? databaseFactory,
      _pathOverride = path;

  static const int version = 2;
  static const String databaseName = 'depstream.db';
  static const String matchesTable = 'matches';
  static const String eventsTable = 'match_events';

  final DatabaseFactory _databaseFactory;
  final String? _pathOverride;

  Database? _db;

  /// Abre (y crea si no existe) la base de datos. Se llama al arrancar.
  Future<Database> open() async {
    if (_db != null) return _db!;
    final path =
        _pathOverride ??
        p.join(await getDatabasesPath(), databaseName);
    _db = await _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        // Sin esto, el `ON DELETE CASCADE` de `match_events` no se
        // aplica: al borrar un partido, sus eventos deben borrarse.
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _createTables(db),
        onUpgrade: (db, oldVersion, newVersion) =>
            _migrate(db, oldVersion, newVersion),
      ),
    );
    return _db!;
  }

  Future<Database> get database async => _db ?? await open();

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Esquema v2 completo. Una instalación nueva y una base migrada desde
  /// v1 deben quedar idénticas (hay un test que lo comprueba).
  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $matchesTable (
        id TEXT PRIMARY KEY,
        home_team TEXT NOT NULL,
        away_team TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        home_color TEXT NOT NULL DEFAULT '#D32F2F',
        away_color TEXT NOT NULL DEFAULT '#1976D2',
        period_duration_minutes INTEGER NOT NULL DEFAULT 45,
        periods_count INTEGER NOT NULL DEFAULT 2,
        home_score INTEGER NOT NULL DEFAULT 0,
        away_score INTEGER NOT NULL DEFAULT 0,
        current_period INTEGER NOT NULL DEFAULT 1,
        clock_status TEXT NOT NULL DEFAULT 'stopped',
        clock_started_at INTEGER NULL,
        clock_accumulated_ms INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createEventsTable(db);
  }

  static Future<void> _createEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $eventsTable (
        id TEXT PRIMARY KEY,
        match_id TEXT NOT NULL REFERENCES $matchesTable(id) ON DELETE CASCADE,
        team TEXT NOT NULL,
        kind TEXT NOT NULL,
        minute INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_match_events_match_id
      ON $eventsTable(match_id)
    ''');
  }

  /// Migración v1 → v2. Solo `ADD COLUMN` con `DEFAULT` y una tabla nueva:
  /// no hay `DROP TABLE` ni `DELETE`. Corre dentro de la transacción de
  /// sqflite: si un paso falla, la base queda en v1.
  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == 1) {
      await db.execute(
        "ALTER TABLE $matchesTable ADD COLUMN home_color TEXT NOT NULL DEFAULT '#D32F2F'",
      );
      await db.execute(
        "ALTER TABLE $matchesTable ADD COLUMN away_color TEXT NOT NULL DEFAULT '#1976D2'",
      );
      await db.execute(
        'ALTER TABLE $matchesTable ADD COLUMN period_duration_minutes INTEGER NOT NULL DEFAULT 45',
      );
      await db.execute(
        'ALTER TABLE $matchesTable ADD COLUMN periods_count INTEGER NOT NULL DEFAULT 2',
      );
      await db.execute(
        'ALTER TABLE $matchesTable ADD COLUMN home_score INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $matchesTable ADD COLUMN away_score INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $matchesTable ADD COLUMN current_period INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        "ALTER TABLE $matchesTable ADD COLUMN clock_status TEXT NOT NULL DEFAULT 'stopped'",
      );
      await db.execute(
        'ALTER TABLE $matchesTable ADD COLUMN clock_started_at INTEGER NULL',
      );
      await db.execute(
        'ALTER TABLE $matchesTable ADD COLUMN clock_accumulated_ms INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $matchesTable ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await _createEventsTable(db);
      // Los partidos de la Etapa 0 quedan en borrador, 0-0, colores por
      // defecto, 45 min, 2 periodos, reloj parado. No se toca `created_at`
      // ni `status` ni ningún `id`.
      await db.execute(
        'UPDATE $matchesTable SET updated_at = created_at',
      );
    }
  }
}
