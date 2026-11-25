import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local de Dep-Stream, versión 1 (Etapa 0).
///
/// Una sola tabla: `matches`. Las migraciones futuras serán versionadas
/// (v1 → v2…) y nunca borrarán datos sin autorización de Félix.
class AppDatabase {
  /// Para tests: se puede inyectar otra factoría (por ejemplo, la de FFI en
  /// memoria) y otra ruta. En la app se usan los valores por defecto.
  /// El parámetro se llama `factoryOverride` porque `databaseFactory` es
  /// también el getter de sqflite y lo ocultaría en la lista inicializadora.
  AppDatabase({DatabaseFactory? factoryOverride, String? path})
    : _databaseFactory = factoryOverride ?? databaseFactory,
      _pathOverride = path;

  static const int version = 1;
  static const String databaseName = 'depstream.db';
  static const String matchesTable = 'matches';

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
        onCreate: (db, version) => _createTables(db),
      ),
    );
    return _db!;
  }

  Future<Database> get database async => _db ?? await open();

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $matchesTable (
        id TEXT PRIMARY KEY,
        home_team TEXT NOT NULL,
        away_team TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL
      )
    ''');
  }
}
