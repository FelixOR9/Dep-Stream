import 'package:dep_stream/core/permissions/permission_controller.dart';
import 'package:dep_stream/core/permissions/permission_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Los tests de MethodChannel necesitan el binding de tests inicializado.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionStatus', () {
    test('un valor desconocido se lee como sin pedir, nunca como concedido', () {
      expect(
        PermissionStatusX.fromChannelName('concedido_siempre'),
        PermissionStatus.notRequested,
      );
      expect(
        PermissionStatusX.fromChannelName(null),
        PermissionStatus.notRequested,
      );
    });

    test('los cuatro estados tienen etiqueta en español', () {
      expect(PermissionStatus.granted.label, 'Concedido');
      expect(PermissionStatus.denied.label, 'Negado');
      expect(PermissionStatus.permanentlyDenied.label, 'Negado para siempre');
      expect(PermissionStatus.notRequested.label, 'Sin pedir');
    });
  });

  group('PermissionController', () {
    const channel = MethodChannel('com.felix.depstream/permissions');

    test('checkPermissions parsea el mapa del canal nativo', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'checkPermissions');
            return <String, String>{
              'camera': 'granted',
              'microphone': 'denied',
              'notifications': 'permanentlyDenied',
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final states = await PermissionController().checkPermissions();

      expect(states.length, 3);
      expect(states[0].permission, AppPermission.camera);
      expect(states[0].status, PermissionStatus.granted);
      expect(states[1].status, PermissionStatus.denied);
      expect(states[2].status, PermissionStatus.permanentlyDenied);
    });

    test('sin canal, todo es sin pedir y no falla', () async {
      final states = await PermissionController().checkPermissions();
      expect(
        states.map((s) => s.status).toSet(),
        {PermissionStatus.notRequested},
      );
    });
  });
}
