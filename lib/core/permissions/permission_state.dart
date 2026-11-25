/// Estados de un permiso, iguales en Dart y en Kotlin.
///
/// - [notRequested]: nunca se ha pedido.
/// - [granted]: concedido.
/// - [denied]: negado, pero se puede volver a pedir.
/// - [permanentlyDenied]: negado para siempre; solo se arregla desde los
///   ajustes del sistema. La app no debe volver a pedirlo en bucle.
enum PermissionStatus { notRequested, granted, denied, permanentlyDenied }

/// Permisos que usa Dep-Stream (Etapa 0).
enum AppPermission { camera, microphone, notifications }

extension AppPermissionX on AppPermission {
  /// Nombre que viaja por el canal de plataforma.
  String get channelName {
    switch (this) {
      case AppPermission.camera:
        return 'camera';
      case AppPermission.microphone:
        return 'microphone';
      case AppPermission.notifications:
        return 'notifications';
    }
  }

  /// Etiqueta en español para la pantalla de ajustes.
  String get label {
    switch (this) {
      case AppPermission.camera:
        return 'Cámara';
      case AppPermission.microphone:
        return 'Micrófono';
      case AppPermission.notifications:
        return 'Notificaciones';
    }
  }

  /// Para qué se pide, en español. Se muestra antes de pedirlo.
  String get explanation {
    switch (this) {
      case AppPermission.camera:
        return 'Para grabar y transmitir el partido.';
      case AppPermission.microphone:
        return 'Para que el video tenga el sonido del partido.';
      case AppPermission.notifications:
        return 'Para avisarte mientras grabas o transmites.';
    }
  }

  static AppPermission? fromChannelName(String name) {
    for (final permission in AppPermission.values) {
      if (permission.channelName == name) return permission;
    }
    return null;
  }
}

extension PermissionStatusX on PermissionStatus {
  String get channelName => name;

  /// Etiqueta en español para la pantalla de ajustes.
  String get label {
    switch (this) {
      case PermissionStatus.notRequested:
        return 'Sin pedir';
      case PermissionStatus.granted:
        return 'Concedido';
      case PermissionStatus.denied:
        return 'Negado';
      case PermissionStatus.permanentlyDenied:
        return 'Negado para siempre';
    }
  }

  static PermissionStatus fromChannelName(String? name) {
    for (final status in PermissionStatus.values) {
      if (status.name == name) return status;
    }
    // Un valor desconocido nunca se presenta como concedido.
    return PermissionStatus.notRequested;
  }
}

/// Estado de un permiso en un momento dado.
class PermissionState {
  const PermissionState({required this.permission, required this.status});

  final AppPermission permission;
  final PermissionStatus status;
}
