import 'package:dep_stream/core/permissions/permission_state.dart';
import 'package:flutter/services.dart';

/// Puente Dart ↔ Kotlin para los permisos (canal
/// `com.felix.depstream/permissions`).
///
/// El estado real vive en Android y se vuelve a comprobar en cada llamada y
/// al volver a la app; Dart nunca guarda el estado en SQLite ni lo cachea.
/// Si el canal no está disponible (por ejemplo, en tests sin mock), las
/// llamadas devuelven `notRequested` para todos los permisos en lugar de
/// fallar: un estado desconocido nunca se presenta como concedido.
class PermissionController {
  PermissionController({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.felix.depstream/permissions');

  final MethodChannel _channel;

  /// Comprueba el estado actual de los tres permisos.
  Future<List<PermissionState>> checkPermissions() async {
    final raw = await _invoke('checkPermissions');
    return _parse(raw);
  }

  /// Pide los tres permisos al sistema.
  Future<List<PermissionState>> requestPermissions() async {
    final raw = await _invoke('requestPermissions');
    return _parse(raw);
  }

  /// Pide solo la cámara (Etapa 2). Devuelve el estado de la cámara
  /// tras la respuesta del usuario. Sin canal, `notRequested`.
  Future<PermissionState> requestCamera() async {
    final raw = await _invoke('requestCamera');
    return PermissionState(
      permission: AppPermission.camera,
      status: PermissionStatusX.fromChannelName(raw['camera']),
    );
  }

  /// Abre la pantalla de ajustes de la app en el sistema.
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on PlatformException {
      // Sin canal no hay nada que abrir; la pantalla de ajustes lo muestra.
    }
  }

  Future<Map<String, String>> _invoke(String method) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(method);
      if (result == null) return {};
      return result.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } on MissingPluginException {
      // Sin implementación del canal (tests sin mock, o plataforma sin el
      // canal nativo): estado desconocido, nunca concedido.
      return {};
    } on PlatformException {
      return {};
    }
  }

  List<PermissionState> _parse(Map<String, String> raw) {
    return AppPermission.values.map((permission) {
      return PermissionState(
        permission: permission,
        status: PermissionStatusX.fromChannelName(
          raw[permission.channelName],
        ),
      );
    }).toList();
  }
}
