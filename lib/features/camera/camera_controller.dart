import 'package:dep_stream/core/permissions/permission_controller.dart';
import 'package:dep_stream/core/permissions/permission_state.dart';
import 'package:dep_stream/features/camera/camera_service.dart';
import 'package:flutter/foundation.dart';

/// Estado de la sesión de cámara en la pantalla.
enum CameraControllerState { closed, opening, open, error }

/// Controlador de la pantalla de cámara.
///
/// Dueño de la sesión Camera2 mientras la pantalla está visible:
/// abre al entrar, cierra al salir y al pasar a segundo plano, reabre
/// al volver. El partido no depende de él: si la cámara falla o está
/// denegada, el `MatchController` sigue funcionando y el marcador
/// sigue guardándose en SQLite.
///
/// No guarda nada en SQLite ni en ningún sitio: el estado de la
/// sesión vive en Kotlin. Sin canal (tests sin mock), `open()` deja
/// el estado en `error` con `camera_unavailable`, nunca en abierto.
class CameraController extends ChangeNotifier {
  CameraController({
    CameraService? cameraService,
    PermissionController? permissionController,
  }) : _cameraService = cameraService ?? CameraService(),
       _permissionController =
           permissionController ?? PermissionController();

  final CameraService _cameraService;
  final PermissionController _permissionController;

  CameraControllerState _state = CameraControllerState.closed;
  int? _textureId;
  String? _errorCode;
  bool _permissionDenied = false;
  bool _permissionPermanentlyDenied = false;
  bool _disposed = false;
  // Se pidió cerrar mientras la cámara se estaba abriendo: en cuanto
  // la apertura termine, se cierra en el acto (sin dejar una sesión
  // abierta sin dueño).
  bool _closeAfterOpen = false;

  CameraControllerState get state => _state;
  int? get textureId => _textureId;
  String? get errorCode => _errorCode;

  /// `true` si la cámara está denegada (hay que mostrar la pantalla honesta).
  bool get permissionDenied => _permissionDenied;

  /// `true` si está denegada para siempre (el botón es "Abrir ajustes").
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;

  bool get isOpen => _state == CameraControllerState.open;

  /// Abre la cámara (después de comprobar el permiso). No-op si ya
  /// está abierta o abriéndose.
  Future<void> open() async {
    if (_state == CameraControllerState.opening ||
        _state == CameraControllerState.open) {
      return;
    }
    _state = CameraControllerState.opening;
    _errorCode = null;
    _permissionDenied = false;
    _permissionPermanentlyDenied = false;
    notifyListeners();
    final states = await _permissionController.checkPermissions();
    if (_disposed || _closeAfterOpen) {
      await _finishOpeningCancelled();
      return;
    }
    final camera = states.firstWhere(
      (s) => s.permission == AppPermission.camera,
      orElse: () => const PermissionState(
        permission: AppPermission.camera,
        status: PermissionStatus.notRequested,
      ),
    );
    if (camera.status != PermissionStatus.granted) {
      _state = CameraControllerState.closed;
      _permissionDenied = true;
      _permissionPermanentlyDenied =
          camera.status == PermissionStatus.permanentlyDenied;
      _closeAfterOpen = false;
      if (!_disposed) notifyListeners();
      return;
    }
    try {
      _textureId = await _cameraService.open();
      _state = CameraControllerState.open;
    } on CameraException catch (e) {
      _textureId = null;
      _errorCode = e.code;
      _state = CameraControllerState.error;
    }
    if (_disposed || _closeAfterOpen) {
      await _finishOpeningCancelled();
      return;
    }
    notifyListeners();
  }

  /// La apertura se canceló (dispose o close durante la apertura):
  /// si llegó a abrirse la sesión, se cierra en el acto y el estado
  /// queda cerrado, sin notificar a nadie (ya no hay quien escuche).
  Future<void> _finishOpeningCancelled() async {
    _closeAfterOpen = false;
    if (_state == CameraControllerState.open) {
      await _cameraService.close();
    }
    _textureId = null;
    _state = CameraControllerState.closed;
    _errorCode = null;
  }

  /// Pide solo el permiso de cámara (desde la pantalla honesta de
  /// denegación). Si se concede, abre la cámara en el acto; si no,
  /// la pantalla honesta sigue visible, sin pedir en bucle.
  Future<void> requestPermission() async {
    final state = await _permissionController.requestCamera();
    if (state.status == PermissionStatus.granted) {
      _permissionDenied = false;
      _permissionPermanentlyDenied = false;
      notifyListeners();
      await open();
    } else {
      _permissionDenied = true;
      _permissionPermanentlyDenied =
          state.status == PermissionStatus.permanentlyDenied;
      notifyListeners();
    }
  }

  /// Abre los ajustes del sistema (permiso negado para siempre).
  Future<void> openAppSettings() =>
      _permissionController.openAppSettings();

  /// Cierra la sesión. Idempotente: cerrar sin abrir no hace nada.
  /// Si se llama mientras se está abriendo, la apertura se cancela
  /// en cuanto termine (nunca deja una sesión abierta sin dueño).
  Future<void> close() async {
    if (_state == CameraControllerState.closed) return;
    if (_state == CameraControllerState.opening) {
      _closeAfterOpen = true;
      return;
    }
    await _cameraService.close();
    _textureId = null;
    _state = CameraControllerState.closed;
    _errorCode = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // El cierre ordenado lo pide la pantalla en su dispose; aquí se
    // marca el dispuesto para que ningún await posterior notifique
    // a un controlador ya destruido.
    _disposed = true;
    super.dispose();
  }
}
