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

/// Puente Dart ↔ Kotlin para la cámara (canal `com.felix.depstream/camera`).
///
/// Solo envuelve el canal: no guarda estado de la cámara en SQLite ni
/// en ningún sitio (el estado vive en Kotlin mientras la sesión existe).
/// Si no hay canal (tests sin mock), `open()` devuelve un error en lugar
/// de inventar una textura.
class CameraService {
  CameraService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.felix.depstream/camera');

  final MethodChannel _channel;

  /// Abre la cámara trasera y devuelve el id de la textura de la vista
  /// previa. Lanza [CameraException] con el código del fallo.
  Future<int> open() async {
    try {
      final textureId = await _channel.invokeMethod<int>('openCamera');
      if (textureId == null) {
        throw const CameraException(
          'session_failed',
          'La cámara no devolvió textura.',
        );
      }
      return textureId;
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
