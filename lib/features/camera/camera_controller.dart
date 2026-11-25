import 'dart:async';

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

  /// Rotación del preview en grados (0/90/180/270), la actual en vivo,
  /// no solo la de la apertura: Kotlin avisa a cada cambio de pantalla.
  int _rotationDegrees = 0;

  /// Suscripción a los avisos de giro en vivo, activa solo mientras
  /// la cámara se está abriendo o está abierta.
  StreamSubscription<int>? _rotationSubscription;

  /// Giro que llegó en vivo mientras la cámara se estaba abriendo:
  /// la respuesta de `open()` puede traer el giro de antes del cambio
  /// de pantalla, así que al terminar manda el último aviso recibido.
  int? _pendingRotation;
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

  /// Grados que hay que girar la textura para que se vea derecha.
  int get rotationDegrees => _rotationDegrees;
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
    _pendingRotation = null;
    // Escuchar el giro en vivo desde ya: la pantalla gira a
    // horizontal mientras se abre la cámara, y ese aviso puede llegar
    // antes de que la apertura termine.
    _rotationSubscription ??= _cameraService.rotationChanged.listen(
      _onRotationEvent,
      onError: (_) {},
      cancelOnError: false,
    );
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
      _cancelRotationSubscription();
      if (!_disposed) notifyListeners();
      return;
    }
    try {
      final session = await _cameraService.open();
      _textureId = session.textureId;
      // Si llegó un aviso de giro mientras se abría, ese es el
      // vigente: la respuesta puede traer el giro de antes del cambio
      // de pantalla.
      _rotationDegrees = _pendingRotation ?? session.rotationDegrees;
      _pendingRotation = null;
      _state = CameraControllerState.open;
    } on CameraException catch (e) {
      _textureId = null;
      _rotationDegrees = 0;
      _errorCode = e.code;
      _state = CameraControllerState.error;
      _cancelRotationSubscription();
    }
    if (_disposed || _closeAfterOpen) {
      await _finishOpeningCancelled();
      return;
    }
    notifyListeners();
  }

  /// Un aviso de giro en vivo de Kotlin.
  ///
  /// Con la cámara abierta, el giro se aplica en el acto y se
  /// notifica para que el visor re-renderice; mientras se está
  /// abriendo, se guarda para aplicar al terminar (la respuesta de
  /// `open()` puede traer un giro ya viejo). En cualquier otro estado
  /// se ignora. Sin cambio no se notifica.
  void _onRotationEvent(int rotationDegrees) {
    if (_disposed) return;
    if (_state == CameraControllerState.opening) {
      _pendingRotation = rotationDegrees;
      return;
    }
    if (_state != CameraControllerState.open) return;
    if (rotationDegrees == _rotationDegrees) return;
    _rotationDegrees = rotationDegrees;
    notifyListeners();
  }

  /// Deja de escuchar el giro en vivo. Idempotente.
  void _cancelRotationSubscription() {
    unawaited(_rotationSubscription?.cancel());
    _rotationSubscription = null;
    _pendingRotation = null;
  }

  /// La apertura se canceló (dispose o close durante la apertura):
  /// si llegó a abrirse la sesión, se cierra en el acto y el estado
  /// queda cerrado, sin notificar a nadie (ya no hay quien escuche).
  Future<void> _finishOpeningCancelled() async {
    _closeAfterOpen = false;
    _cancelRotationSubscription();
    if (_state == CameraControllerState.open) {
      await _cameraService.close();
    }
    _textureId = null;
    _rotationDegrees = 0;
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
    _cancelRotationSubscription();
    await _cameraService.close();
    _textureId = null;
    _rotationDegrees = 0;
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
    _cancelRotationSubscription();
    super.dispose();
  }
}
