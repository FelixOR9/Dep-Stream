import 'package:dep_stream/core/permissions/permission_controller.dart';
import 'package:dep_stream/core/permissions/permission_state.dart';
import 'package:flutter/material.dart';

/// Pantalla de ajustes: solo lo que existe en la Etapa 0.
///
/// - Versión de la app.
/// - Estado real de cada permiso, comprobado al entrar y al volver a la app.
/// - Botón para pedir los permisos y botón para abrir los ajustes del
///   sistema cuando un permiso está negado para siempre.
/// - "Acerca de", sin prometer funciones que no existen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.permissionController, super.key});

  static const String routeName = '/settings';

  /// Inyectable para tests. En la app se usa el controlador real.
  final PermissionController? permissionController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late final PermissionController _controller;
  List<PermissionState> _states = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.permissionController ?? PermissionController();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app, el estado de los permisos puede haber cambiado
    // en los ajustes del sistema. Se vuelve a comprobar, nunca se cachea.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final states = await _controller.checkPermissions();
    if (mounted) {
      setState(() {
        _states = states;
        _loading = false;
      });
    }
  }

  Future<void> _request() async {
    final states = await _controller.requestPermissions();
    if (mounted) setState(() => _states = states);
  }

  bool get _anyPermanentlyDenied => _states.any(
    (s) => s.status == PermissionStatus.permanentlyDenied,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Dep-Stream',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text('Versión 0.3.0+3 (Etapa 2: Cámara y overlay)'),
          const SizedBox(height: 24),
          const Text(
            'Permisos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ..._states.map(
              (state) => Card(
                child: ListTile(
                  title: Text(state.permission.label),
                  subtitle: Text(
                    '${state.permission.explanation}\nEstado: ${state.status.label}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _request,
            child: const Text('Solicitar permisos'),
          ),
          if (_anyPermanentlyDenied) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _controller.openAppSettings(),
              child: const Text('Abrir ajustes del sistema'),
            ),
            const Text(
              'Un permiso negado para siempre solo se puede conceder desde '
              'los ajustes del sistema.',
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Acerca de',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dep-Stream transmitirá partidos de fútbol en vivo a Facebook '
            'desde tu teléfono, con marcador y grabación local. En esta '
            'versión ya puedes crear partidos, jugarlos con marcador y '
            'reloj, y ver la cámara con el marcador encima. La grabación '
            'y la transmisión llegan en las siguientes etapas.',
          ),
        ],
      ),
    );
  }
}
