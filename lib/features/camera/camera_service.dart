import 'package:flutter/services.dart';

/// Error de cámara con código propio, nunca un mensaje genérico.
///
/// Códigos (los mismos que en Kotlin, plan §3.2):
/// `camera_unavailable`, `camera_in_use`, `permission_denied`,
/// `session_failed`, `already_open`.
class CameraException implements Exception {
  const CameraException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() =>
      'CameraException($code${message != null ? ': $message' : ''})';
}

/// Sesión de vista previa abierta: id de la textura y rotación del
/// preview en grados (0/90/180/270, múltiplo de 90).
///
/// La rotación la calcula Kotlin (sensor − rotación de pantalla) y la
/// aplica el widget `Texture` en Dart: `SurfaceTexture` no tiene
/// `setTransform`, así que no se puede girar en el lado nativo.
class CameraPreviewSession {
  const CameraPreviewSession({
    required this.textureId,
    this.rotationDegrees = 0,
  });

  final int textureId;

  /// Grados que hay que girar la textura para que se vea derecha.
  final int rotationDegrees;
}

/// Puente Dart ↔ Kotlin para la cámara (canal `com.felix.depstream/camera`).
///
/// Solo envuelve el canal: no guarda estado de la cámara en SQLite ni
/// en ningún sitio (el estado vive en Kotlin mientras la sesión existe).
/// Si no hay canal (tests sin mock), `open()` devuelve un error en lugar
/// de inventar una textura.
class CameraService {
  CameraService({MethodChannel? channel, EventChannel? rotationChannel})
    : _channel = channel ?? const MethodChannel('com.felix.depstream/camera'),
      _rotationChannel =
          rotationChannel ??
          const EventChannel('com.felix.depstream/camera_rotation');

  final MethodChannel _channel;

  /// Canal por el que Kotlin empuja el giro del preview en vivo.
  final EventChannel _rotationChannel;

  /// Giro del preview en vivo (0/90/180/270), cada vez que cambia la
  /// rotación de pantalla con la sesión abierta.
  ///
  /// Kotlin empuja `{"rotationDegrees": ...}`; los eventos sin un giro
  /// válido se descartan, nunca se inventa un giro. Sin canal, el
  /// stream emite un error al escuchar (lo traga quien se suscribe).
  Stream<int> get rotationChanged =>
      _rotationChannel.receiveBroadcastStream().map((event) {
        final rotation = event is Map ? event['rotationDegrees'] : null;
        return rotation is int ? rotation : -1;
      }).where((rotation) => rotation >= 0);

  /// Abre la cámara trasera y devuelve la sesión de vista previa
  /// (id de textura + rotación). Lanza [CameraException] con el
  /// código del fallo.
  Future<CameraPreviewSession> open() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('openCamera');
      if (raw == null) {
        throw const CameraException(
          'session_failed',
          'La cámara no devolvió textura.',
        );
      }
      final textureId = raw['textureId'];
      if (textureId is! int) {
        throw const CameraException(
          'session_failed',
          'La cámara no devolvió textura.',
        );
      }
      final rotation = raw['rotationDegrees'];
      return CameraPreviewSession(
        textureId: textureId,
        rotationDegrees: rotation is int ? rotation : 0,
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    } on MissingPluginException {
      throw const CameraException(
        'camera_unavailable',
        'Sin canal de cámara.',
      );
    }
  }

  /// Cierra la sesión. No falla si ya estaba cerrada.
  Future<void> close() async {
    try {
      await _channel.invokeMethod<void>('closeCamera');
    } on PlatformException {
      // Cerrar nunca debe lanzar: lo peor ya pasó.
    } on MissingPluginException {
      // Sin canal no hay nada que cerrar.
    }
  }

  /// Estado actual de la sesión en Kotlin: `state` (`closed`/`opening`/
  /// `open`/`error`) y `errorCode` (o null). Sin canal, `closed`.
  Future<Map<String, String>> state() async {
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('getCameraState');
      if (raw == null) return {'state': 'closed'};
      final state = raw['state']?.toString() ?? 'closed';
      final result = <String, String>{'state': state};
      final errorCode = raw['errorCode']?.toString();
      if (errorCode != null) result['errorCode'] = errorCode;
      return result;
    } on MissingPluginException {
      return {'state': 'closed'};
    } on PlatformException {
      return {'state': 'closed'};
    }
  }
}
