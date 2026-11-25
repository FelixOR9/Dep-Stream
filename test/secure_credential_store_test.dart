import 'package:dep_stream/core/storage/secure_credential_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Los tests de MethodChannel necesitan el binding de tests inicializado.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureCredentialStore', () {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final stored = <String, String>{};

    setUp(() {
      stored.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = call.arguments as Map<Object?, Object?>?;
            final key = args?['key'] as String?;
            switch (call.method) {
              case 'write':
                stored[key!] = args!['value'] as String;
                return null;
              case 'read':
                return stored[key];
              case 'delete':
                stored.remove(key);
                return null;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('guardar, leer y borrar una clave (valor de prueba, no real)', () async {
      final store = SecureCredentialStore();

      await store.saveStreamKey('clave-de-prueba');
      expect(await store.readStreamKey(), 'clave-de-prueba');

      await store.deleteStreamKey();
      expect(await store.readStreamKey(), isNull);
    });
  });
}
