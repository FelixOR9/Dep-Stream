import 'package:dep_stream/features/camera/camera_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.felix.depstream/camera');

  group('CameraService', () {
    test(
        'open() con canal que devuelve textura 7 y giro 90 devuelve ambos',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'openCamera') {
              return <String, Object?>{
                'textureId': 7,
                'rotationDegrees': 90,
              };
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final session = await CameraService().open();
      expect(session.textureId, 7);
      expect(session.rotationDegrees, 90);
    });

    test('open() sin rotationDegrees en la respuesta usa giro 0',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'openCamera') {
              return <String, Object?>{'textureId': 7};
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final session = await CameraService().open();
      expect(session.textureId, 7);
      expect(session.rotationDegrees, 0);
    });

    test('open() sin textureId en la respuesta devuelve session_failed',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'openCamera') {
              return <String, Object?>{'rotationDegrees': 90};
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      try {
        await CameraService().open();
        fail('open() debería lanzar CameraException.');
      } on CameraException catch (e) {
        expect(e.code, 'session_failed');
      }
    });

    test('open() con error camera_in_use devuelve el error con su código',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'openCamera') {
              throw PlatformException(
                code: 'camera_in_use',
                message: 'La cámara está en uso por otra aplicación.',
              );
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      try {
        await CameraService().open();
        fail('open() debería lanzar CameraException.');
      } on CameraException catch (e) {
        expect(e.code, 'camera_in_use');
      }
    });

    test('open() sin canal devuelve error, nunca una textura inventada',
        () async {
      // Sin mock: MissingPluginException → camera_unavailable.
      try {
        await CameraService().open();
        fail('open() debería lanzar CameraException.');
      } on CameraException catch (e) {
        expect(e.code, 'camera_unavailable');
      }
    });

    test('close() llama al método y no falla sin canal', () async {
      // Sin mock: MissingPluginException se traga, close() no lanza.
      await CameraService().close();
    });

    test('state() devuelve el estado y el código de error de Kotlin',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getCameraState') {
              return <String, Object?>{
                'state': 'error',
                'errorCode': 'camera_in_use',
              };
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final state = await CameraService().state();
      expect(state['state'], 'error');
      expect(state['errorCode'], 'camera_in_use');
    });

    test('state() sin canal devuelve closed', () async {
      expect(await CameraService().state(), {'state': 'closed'});
    });
  });
}
