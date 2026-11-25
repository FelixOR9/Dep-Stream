import 'package:dep_stream/features/camera/camera_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionsChannel =
      MethodChannel('com.felix.depstream/permissions');
  const cameraChannel = MethodChannel('com.felix.depstream/camera');
  const rotationChannel = EventChannel('com.felix.depstream/camera_rotation');

  /// Mock de permisos (concedido), de cámara (textura 7, giro 90) y
  /// del canal de giro en vivo. `openCamera` tarda un poco, como la
  /// apertura real, para poder empujar un aviso de giro mientras se
  /// está abriendo. El sink del canal de giro queda en [rotationSink]
  /// para empujar eventos desde los tests.
  late MockStreamHandlerEventSink rotationSink;

  void mockChannels() {
    final binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      permissionsChannel,
      (call) async {
        if (call.method == 'checkPermissions') {
          return <String, String>{
            'camera': 'granted',
            'microphone': 'denied',
            'notifications': 'notRequested',
          };
        }
        return null;
      },
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      cameraChannel,
      (call) async {
        if (call.method == 'openCamera') {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return <String, Object?>{
            'textureId': 7,
            'rotationDegrees': 90,
          };
        }
        if (call.method == 'closeCamera') return null;
        if (call.method == 'getCameraState') {
          return <String, Object?>{'state': 'open', 'errorCode': null};
        }
        return null;
      },
    );
    binding.defaultBinaryMessenger.setMockStreamHandler(
      rotationChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          rotationSink = events;
        },
      ),
    );
    addTearDown(() {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionsChannel, null);
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, null);
      binding.defaultBinaryMessenger
          .setMockStreamHandler(rotationChannel, null);
    });
  }

  /// Empuja un aviso de giro en vivo, como lo haría Kotlin al cambiar
  /// la rotación de pantalla, y deja que llegue al controlador.
  Future<void> pushRotation(int degrees) async {
    rotationSink.success(<String, Object?>{'rotationDegrees': degrees});
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  group('CameraController giro en vivo', () {
    test('abrir deja el giro de la sesión y un aviso lo actualiza',
        () async {
      mockChannels();
      final controller = CameraController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.open();
      expect(controller.state, CameraControllerState.open);
      expect(controller.rotationDegrees, 90);
      final afterOpen = notifications;

      await pushRotation(0);
      expect(controller.rotationDegrees, 0);
      expect(notifications, greaterThan(afterOpen));

      await pushRotation(180);
      expect(controller.rotationDegrees, 180);
    });

    test('un aviso sin cambio de giro no notifica', () async {
      mockChannels();
      final controller = CameraController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.open();
      final afterOpen = notifications;

      await pushRotation(90);
      expect(controller.rotationDegrees, 90);
      expect(notifications, afterOpen);
    });

    test('un aviso durante la apertura manda sobre la respuesta',
        () async {
      mockChannels();
      final controller = CameraController();
      addTearDown(controller.dispose);

      // La apertura tarda 50 ms; el aviso llega a los 10 ms, con la
      // pantalla ya en horizontal: al terminar debe mandar el aviso
      // (180), no el giro 90 de la respuesta.
      final opening = controller.open();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await pushRotation(180);
      await opening;

      expect(controller.state, CameraControllerState.open);
      expect(controller.rotationDegrees, 180);
    });

    test('cerrar deja de escuchar: los avisos ya no cambian nada',
        () async {
      mockChannels();
      final controller = CameraController();
      addTearDown(controller.dispose);

      await controller.open();
      expect(controller.rotationDegrees, 90);

      await controller.close();
      expect(controller.state, CameraControllerState.closed);
      expect(controller.rotationDegrees, 0);

      await pushRotation(90);
      expect(controller.rotationDegrees, 0);
      expect(controller.state, CameraControllerState.closed);
    });
  });
}
