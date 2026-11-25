import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/match_controller.dart';
import 'package:dep_stream/features/match/match_event.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter/material.dart';

/// Pantalla de partido en vivo: marcador, reloj, goles y tarjetas.
///
/// Controles grandes, pensados para usar con el teléfono en la mano.
/// Solo se muestra el control válido según el estado del partido:
/// no hay botones muertos. Cada cambio se guarda en SQLite en el acto,
/// antes de repintar: si la escritura falla, se muestra el error y no
/// se repinta un marcador falso.
class MatchScreen extends StatefulWidget {
  const MatchScreen({required this.database, super.key});

  static const String routeName = '/match';

  final AppDatabase database;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with WidgetsBindingObserver {
  MatchController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final matchId = ModalRoute.of(context)?.settings.arguments as String?;
    if (matchId == null) {
      // Sin partido no hay pantalla: se vuelve a la lista.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    _controller = MatchController(database: widget.database, matchId: matchId)
      ..load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app, el marcador y el reloj se vuelven a leer de
    // la base: si el teléfono se reinició con la app en este partido,
    // lo que se muestra es lo guardado, no lo de la memoria.
    if (state == AppLifecycleState.resumed) {
      _controller?.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _run(Future<bool> Function() action, String errorMessage) async {
    final ok = await action();
    if (!ok && mounted) _showError(errorMessage);
  }

  Future<void> _confirmFinish() async {
    final controller = _controller;
    if (controller == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Finalizar el partido?'),
        content: const Text(
          'El marcador quedará como resultado final.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(controller.finish, 'No se pudo finalizar el partido.');
    }
  }

  Future<void> _confirmRemoveGoal(EventTeam team, String teamName) async {
    final controller = _controller;
    if (controller == null) return;
    final lastGoal = controller.lastGoal(team);
    if (lastGoal == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Anular el gol?'),
        content: Text(
          'Se anulará el gol de $teamName del minuto ${lastGoal.minute}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = await controller.removeLastGoal(team);
    if (!mounted) return;
    if (removed == null) {
      _showError('No se pudo anular el gol.');
    } else {
      _showInfo('Gol anulado (min ${removed.minute}).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Partido')),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final match = controller.match;
                if (controller.loading && match == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (match == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        controller.error ?? 'Partido no encontrado.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return _buildBody(context, controller, match);
              },
            ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MatchController controller,
    MatchSession match,
  ) {
    final clock = match.clock;
    final inPlay =
        match.status == MatchStatus.inProgress ||
        match.status == MatchStatus.paused;
    final canScore = inPlay;
    final events = controller.events;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Marcador grande: equipos con su color y el resultado.
        Row(
          children: [
            Expanded(
              child: _TeamScore(
                name: match.homeTeam,
                colorHex: match.homeColor,
                score: match.homeScore,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '-',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _TeamScore(
                name: match.awayTeam,
                colorHex: match.awayColor,
                score: match.awayScore,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Reloj grande + periodo + estado.
        Center(
          child: Text(
            clock.formattedElapsed,
            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Text(
            match.periodLabel,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        Center(
          child: Chip(label: Text(match.status.label)),
        ),
        if (controller.error != null) ...[
          const SizedBox(height: 8),
          Text(
            controller.error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        // Botones de gol.
        if (canScore) ...[
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final ok = await controller.addGoal(EventTeam.home);
                if (!mounted) return;
                if (ok) {
                  _showInfo(
                    'Gol de ${match.homeTeam} (min ${controller.currentMinute})',
                  );
                } else {
                  _showError('No se pudo registrar el gol.');
                }
              },
              child: Text('GOL ${match.homeTeam.toUpperCase()} +1'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final ok = await controller.addGoal(EventTeam.away);
                if (!mounted) return;
                if (ok) {
                  _showInfo(
                    'Gol de ${match.awayTeam} (min ${controller.currentMinute})',
                  );
                } else {
                  _showError('No se pudo registrar el gol.');
                }
              },
              child: Text('GOL ${match.awayTeam.toUpperCase()} +1'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (controller.hasGoals(EventTeam.home))
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _confirmRemoveGoal(EventTeam.home, match.homeTeam),
                    child: Text('−1 ${match.homeTeam}'),
                  ),
                ),
              if (controller.hasGoals(EventTeam.home) &&
                  controller.hasGoals(EventTeam.away))
                const SizedBox(width: 8),
              if (controller.hasGoals(EventTeam.away))
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _confirmRemoveGoal(EventTeam.away, match.awayTeam),
                    child: Text('−1 ${match.awayTeam}'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Tarjetas.
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _run(
                    () => controller.addCard(EventTeam.home, EventKind.yellow),
                    'No se pudo registrar la tarjeta.',
                  ),
                  child: Text('Amarilla ${match.homeTeam}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _run(
                    () => controller.addCard(EventTeam.home, EventKind.red),
                    'No se pudo registrar la tarjeta.',
                  ),
                  child: Text('Roja ${match.homeTeam}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _run(
                    () => controller.addCard(EventTeam.away, EventKind.yellow),
                    'No se pudo registrar la tarjeta.',
                  ),
                  child: Text('Amarilla ${match.awayTeam}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _run(
                    () => controller.addCard(EventTeam.away, EventKind.red),
                    'No se pudo registrar la tarjeta.',
                  ),
                  child: Text('Roja ${match.awayTeam}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // Controles del reloj: solo el válido según el estado.
        ..._clockControls(context, controller, match),
        const SizedBox(height: 12),
        // Cámara: vista previa con el overlay del partido.
        SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/camera',
              arguments: match.id,
            ),
            child: const Text('Cámara'),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Eventos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('Aún no hay eventos en este partido.')
        else
          ...events.reversed.map(
            (event) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(
                "${event.minute}'",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              title: Text(
                '${event.kind.label} de '
                '${event.team == EventTeam.home ? match.homeTeam : match.awayTeam}',
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _clockControls(
    BuildContext context,
    MatchController controller,
    MatchSession match,
  ) {
    switch (match.status) {
      case MatchStatus.draft:
        return [
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  _run(controller.startMatch, 'No se pudo iniciar el partido.'),
              child: const Text('Iniciar partido'),
            ),
          ),
        ];
      case MatchStatus.inProgress:
        return [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () =>
                        _run(controller.pause, 'No se pudo pausar.'),
                    child: const Text('Pausa'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => _run(
                      controller.endPeriod,
                      'No se pudo terminar el periodo.',
                    ),
                    child: const Text('Fin del periodo'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _confirmFinish,
              child: const Text('Finalizar partido'),
            ),
          ),
        ];
      case MatchStatus.paused:
        return [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () =>
                        _run(controller.resume, 'No se pudo reanudar.'),
                    child: const Text('Reanudar'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => _run(
                      controller.endPeriod,
                      'No se pudo terminar el periodo.',
                    ),
                    child: const Text('Fin del periodo'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _confirmFinish,
              child: const Text('Finalizar partido'),
            ),
          ),
        ];
      case MatchStatus.periodEnded:
        final hasNext = match.currentPeriod < match.periodsCount;
        return [
          if (hasNext)
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _run(
                  controller.startNextPeriod,
                  'No se pudo iniciar el siguiente periodo.',
                ),
                child: Text('Iniciar ${match.nextPeriodLabel}'),
              ),
            ),
          if (hasNext) const SizedBox(height: 12),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _confirmFinish,
              child: const Text('Finalizar partido'),
            ),
          ),
        ];
      case MatchStatus.finished:
        return [
          const Center(
            child: Text(
              'Partido finalizado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ];
    }
  }
}

/// Nombre del equipo con su punto de color y su marcador.
class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.name,
    required this.colorHex,
    required this.score,
  });

  final String name;
  final String colorHex;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Color(MatchSession.colorValue(colorHex)),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Text(
          '$score',
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
