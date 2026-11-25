import 'dart:async';

import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/core/permissions/permission_controller.dart';
import 'package:dep_stream/features/camera/camera_controller.dart';
import 'package:dep_stream/features/camera/camera_overlay_data.dart';
import 'package:dep_stream/features/camera/camera_overlay_widget.dart';
import 'package:dep_stream/features/camera/camera_preview_widget.dart';
import 'package:dep_stream/features/camera/camera_service.dart';
import 'package:dep_stream/features/match/match_controller.dart';
import 'package:dep_stream/features/match/match_event.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla de cámara: vista previa con el overlay del partido.
///
/// Horizontal fija mientras está abierta (el overlay es 16:9 y se
/// filma un partido): al entrar se bloquea a los dos horizontales y
/// al salir se restaura la orientación. Visor 16:9 a la izquierda,
/// columna de controles a la derecha, al alcance del pulgar.
///
/// Controles en la cámara: solo lo urgente con una mano (gol +1 por
/// equipo y pausa/reanudar), con las mismas reglas de estado y los
/// mismos métodos del `MatchController` que la pantalla de partido.
/// Tarjetas, −1, fin de periodo y finalizar se quedan en la pantalla
/// de partido. Sin botones muertos: todo lo visible funciona.
///
/// La cámara se abre al entrar y se cierra siempre al salir y al
/// pasar a segundo plano. El partido no depende de la cámara: si está
/// denegada o falla, el marcador sigue funcionando desde la pantalla
/// de partido.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    required this.database,
    this.cameraService,
    this.permissionController,
    super.key,
  });

  static const String routeName = '/camera';

  final AppDatabase database;

  /// Inyectables para tests. En la app se usan los reales.
  final CameraService? cameraService;
  final PermissionController? permissionController;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  MatchController? _matchController;
  CameraController? _cameraController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final matchId = ModalRoute.of(context)?.settings.arguments as String?;
    if (matchId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    _matchController = MatchController(
      database: widget.database,
      matchId: matchId,
    )..load();
    _cameraController = CameraController(
      cameraService: widget.cameraService,
      permissionController: widget.permissionController,
    )..open();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Al volver, la cámara se reabre sola y el marcador se relee.
      _cameraController?.open();
      _matchController?.load();
    } else if (state == AppLifecycleState.paused) {
      // En segundo plano Android puede quitar la cámara: se cierra.
      unawaited(_cameraController?.close());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    unawaited(_cameraController?.close());
    _cameraController?.dispose();
    _matchController?.dispose();
    super.dispose();
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchController = _matchController;
    final cameraController = _cameraController;
    return Scaffold(
      appBar: AppBar(title: const Text('Cámara')),
      body: matchController == null || cameraController == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: Listenable.merge([
                matchController,
                cameraController,
              ]),
              builder: (context, _) {
                final match = matchController.match;
                if (matchController.loading && match == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (match == null) {
                  return _backOnly(
                    matchController.error ?? 'Partido no encontrado.',
                  );
                }
                if (cameraController.permissionDenied) {
                  return _deniedScreen(cameraController);
                }
                if (cameraController.state ==
                    CameraControllerState.error) {
                  return _errorScreen(cameraController);
                }
                return _cameraBody(
                  context,
                  matchController,
                  cameraController,
                  match,
                );
              },
            ),
    );
  }

  Widget _backOnly(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver al partido'),
            ),
          ],
        ),
      ),
    );
  }

  /// Cámara denegada: pantalla honesta. El partido sigue jugándose
  /// desde la pantalla de partido; la denegación solo quita el visor.
  /// Si está denegada para siempre, el botón es "Abrir ajustes"
  /// (pedirla otra vez sería pedir en bucle).
  Widget _deniedScreen(CameraController cameraController) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dep-Stream necesita acceso a la cámara para mostrar '
              'la vista previa.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (cameraController.permissionPermanentlyDenied)
              ElevatedButton(
                onPressed: () => cameraController.openAppSettings(),
                child: const Text('Abrir ajustes'),
              )
            else
              ElevatedButton(
                onPressed: () => cameraController.requestPermission(),
                child: const Text('Pedir permiso'),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver al partido'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorScreen(CameraController cameraController) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se pudo abrir la cámara'
              '${cameraController.errorCode != null ? ' (${cameraController.errorCode})' : ''}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => cameraController.open(),
              child: const Text('Reintentar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver al partido'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraBody(
    BuildContext context,
    MatchController matchController,
    CameraController cameraController,
    MatchSession match,
  ) {
    final inPlay =
        match.status == MatchStatus.inProgress ||
        match.status == MatchStatus.paused;
    return SafeArea(
      child: Row(
        children: [
          // Visor 16:9 con el overlay encima.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CameraPreviewWidget(
                textureId: cameraController.textureId,
                rotationDegrees: cameraController.rotationDegrees,
                overlay: CameraOverlayWidget(
                  data: CameraOverlayData.fromMatch(match),
                ),
              ),
            ),
          ),
          // Columna de controles, al alcance del pulgar.
          SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (inPlay) ...[
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: _GoalButton(
                        label: 'GOL ${match.homeTeam.toUpperCase()} +1',
                        colorHex: match.homeColor,
                        onPressed: () async {
                          final ok = await matchController.addGoal(
                            EventTeam.home,
                          );
                          if (!mounted) return;
                          if (ok) {
                            _showInfo(
                              'Gol de ${match.homeTeam} '
                              '(min ${matchController.currentMinute})',
                            );
                          } else {
                            _showError('No se pudo registrar el gol.');
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: _GoalButton(
                        label: 'GOL ${match.awayTeam.toUpperCase()} +1',
                        colorHex: match.awayColor,
                        onPressed: () async {
                          final ok = await matchController.addGoal(
                            EventTeam.away,
                          );
                          if (!mounted) return;
                          if (ok) {
                            _showInfo(
                              'Gol de ${match.awayTeam} '
                              '(min ${matchController.currentMinute})',
                            );
                          } else {
                            _showError('No se pudo registrar el gol.');
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final ok =
                              match.status == MatchStatus.inProgress
                              ? await matchController.pause()
                              : await matchController.resume();
                          if (!mounted) return;
                          if (!ok) {
                            _showError(
                              match.status == MatchStatus.inProgress
                                  ? 'No se pudo pausar.'
                                  : 'No se pudo reanudar.',
                            );
                          }
                        },
                        child: Text(
                          match.status == MatchStatus.inProgress
                              ? 'Pausa'
                              : 'Reanudar',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver al partido'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de gol con el color del equipo. El texto es negro o blanco
/// según lo claro que sea el color, para que siempre se lea.
class _GoalButton extends StatelessWidget {
  const _GoalButton({
    required this.label,
    required this.colorHex,
    required this.onPressed,
  });

  final String label;
  final String colorHex;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = Color(MatchSession.colorValue(colorHex));
    final foreground = background.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
      ),
      onPressed: onPressed,
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
