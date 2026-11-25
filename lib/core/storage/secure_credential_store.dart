import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro de claves (Etapa 0: preparado, sin claves reales).
///
/// Las claves de stream y los tokens futuros se guardan aquí, nunca en
/// SQLite, en SharedPreferences, en el código ni en logs. En la Etapa 0 no
/// hay ninguna pantalla para pegar una clave: solo existe el almacén y sus
/// pruebas.
class SecureCredentialStore {
  SecureCredentialStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Clave bajo la que se guardará la clave de transmisión (Etapa 5).
  static const String streamKeyKey = 'depstream_stream_key';

  Future<void> saveStreamKey(String key) =>
      _storage.write(key: streamKeyKey, value: key);

  Future<String?> readStreamKey() => _storage.read(key: streamKeyKey);

  Future<void> deleteStreamKey() => _storage.delete(key: streamKeyKey);
}
