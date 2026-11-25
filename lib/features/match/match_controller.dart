import 'dart:async';

import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/match_clock.dart';
import 'package:dep_stream/features/match/match_event.dart';
import 'package:dep_stream/features/match/match_repository.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter/foundation.dart';

/// Controlador de la pantalla de partido.
///
/// Guarda el partido actual y sus eventos, y es el único que escribe en
/// la base de datos desde la pantalla: cada cambio (gol, tarjeta, pausa,
/// periodo, fin) se persiste en el acto, antes de repintar. La pantalla
/// nunca escribe en la base directamente.
///
/// El reloj se repinta con un `Timer` de 1 s, pero el tiempo siempre se
/// recalcula desde la hora de pared (`MatchClock`), así que el `Timer`
/// solo repinta: si se retrasa o la app pasa a segundo plano, el reloj
/// no se atrasa.
class MatchController extends ChangeNotifier {
  MatchController({required AppDatabase database, required this.matchId})
    : _repository = MatchRepository(database);

  final String matchId;
  final MatchRepository _repository;

  MatchSession? _match;
  List<MatchEvent> _events = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  MatchSession? get match => _match;
  List<MatchEvent> get events => List.unmodifiable(_events);
  bool get loading => _loading;
  String? get error => _error;

  /// Reloj de pared del partido actual (o `null` si aún no cargó).
  MatchClock? get clock => _match?.clock;

  /// Minuto de partido actual (o 1 si aún no cargó).
  int get currentMinute => _match?.clock.currentMinute ?? 1;

  /// Carga el partido y sus eventos desde la base. Aplica la guarda de
  /// tope de periodo: si el reloj superó la duración del periodo
  /// (teléfono reiniciado en mitad del partido), se congela en fin de
  /// periodo y se persiste la corrección.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      var session = await _repository.getById(matchId);
      if (session == null) {
        _error = 'El partido ya no existe.';
        _match = null;
        _events = [];
      } else {
        final capped = session.clock.applyPeriodCap();
        if (capped.status != session.clockStatus) {
          session = session.copyWith(
            status: MatchStatus.periodEnded,
            clockStatus: capped.status,
            clockAccumulatedMs: capped.accumulated.inMilliseconds,
            clearClockStartedAt: true,
            updatedAt: DateTime.now(),
          );
          await _repository.saveProgress(session);
        }
        _match = session;
        _events = await _repository.getEvents(matchId);
      }
    } catch (e) {
      _error = 'No se pudo cargar el partido: $e';
    } finally {
      _loading = false;
      _syncTimer();
      notifyListeners();
    }
  }

  Future<bool> _reload() async {
    try {
      final session = await _repository.getById(matchId);
      if (session == null) return false;
      _match = session;
      _events = await _repository.getEvents(matchId);
      _syncTimer();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'No se pudo actualizar el partido: $e';
      notifyListeners();
      return false;
    }
  }

  void _syncTimer() {
    final running = _match?.clockStatus == ClockStatus.running;
    if (running && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    } else if (!running) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _onTick(Timer timer) {
    final session = _match;
    if (session == null) return;
    final clock = session.clock;
    if (clock.status == ClockStatus.running &&
        clock.elapsed > clock.periodDuration) {
      // El periodo terminó mientras la app estaba abierta: se congela
      // en fin de periodo y se persiste, sin esperar a recargar.
      unawaited(endPeriod());
      return;
    }
    notifyListeners();
  }

  Future<bool> _applyTransition(
    MatchStatus newStatus,
    MatchClock Function(MatchClock) change,
  ) async {
    final session = _match;
    if (session == null) return false;
    final newClock = change(session.clock);
    final updated = session.copyWith(
      status: newStatus,
      currentPeriod: newClock.currentPeriod,
      clockStatus: newClock.status,
      clockStartedAt: newClock.startedAt,
      clearClockStartedAt: newClock.startedAt == null,
      clockAccumulatedMs: newClock.accumulated.inMilliseconds,
      updatedAt: DateTime.now(),
    );
    try {
      await _repository.saveProgress(updated);
    } catch (e) {
      _error = 'No se pudo guardar el cambio: $e';
      notifyListeners();
      return false;
    }
    return _reload();
  }

  /// Inicia el partido (desde borrador): reloj en marcha, estado en vivo.
  Future<bool> startMatch() async {
    if (_match?.status != MatchStatus.draft) return false;
    return _applyTransition(MatchStatus.inProgress, (c) => c.start());
  }

  /// Pausa el reloj (en vivo → pausa).
  Future<bool> pause() async {
    if (_match?.status != MatchStatus.inProgress) return false;
    return _applyTransition(MatchStatus.paused, (c) => c.pause());
  }

  /// Reanuda el reloj (pausa → en vivo).
  Future<bool> resume() async {
    if (_match?.status != MatchStatus.paused) return false;
    return _applyTransition(MatchStatus.inProgress, (c) => c.start());
  }

  /// Termina el periodo actual (en vivo o pausa → fin del periodo).
  Future<bool> endPeriod() async {
    final status = _match?.status;
    if (status != MatchStatus.inProgress && status != MatchStatus.paused) {
      return false;
    }
    return _applyTransition(MatchStatus.periodEnded, (c) => c.endPeriod());
  }

  /// Inicia el siguiente periodo (fin del periodo → en vivo).
  Future<bool> startNextPeriod() async {
    final session = _match;
    if (session == null) return false;
    if (session.status != MatchStatus.periodEnded) return false;
    if (session.currentPeriod >= session.periodsCount) return false;
    return _applyTransition(MatchStatus.inProgress, (c) => c.startNextPeriod());
  }

  /// Finaliza el partido (con confirmación en la pantalla).
  Future<bool> finish() async {
    final status = _match?.status;
    if (status != MatchStatus.inProgress &&
        status != MatchStatus.paused &&
        status != MatchStatus.periodEnded) {
      return false;
    }
    return _applyTransition(MatchStatus.finished, (c) => c.finish());
  }

  /// Gol +1 de un equipo: evento + marcador, en la misma transacción.
  Future<bool> addGoal(EventTeam team) async {
    final session = _match;
    if (session == null) return false;
    if (session.status != MatchStatus.inProgress &&
        session.status != MatchStatus.paused) {
      return false;
    }
    try {
      await _repository.addEvent(
        MatchEvent.create(
          matchId: matchId,
          team: team,
          kind: EventKind.goal,
          minute: session.clock.currentMinute,
        ),
      );
    } catch (e) {
      _error = 'No se pudo registrar el gol: $e';
      notifyListeners();
      return false;
    }
    return _reload();
  }

  /// Anula el gol más reciente de un equipo. Devuelve el evento anulado,
  /// o `null` si ese equipo no tenía goles.
  Future<MatchEvent?> removeLastGoal(EventTeam team) async {
    final session = _match;
    if (session == null) return null;
    if (session.status != MatchStatus.inProgress &&
        session.status != MatchStatus.paused) {
      return null;
    }
    try {
      final removed = await _repository.removeLastGoalEvent(matchId, team);
      if (removed == null) return null;
      await _reload();
      return removed;
    } catch (e) {
      _error = 'No se pudo anular el gol: $e';
      notifyListeners();
      return null;
    }
  }

  /// Tarjeta amarilla o roja de un equipo. No cambia el marcador.
  Future<bool> addCard(EventTeam team, EventKind kind) async {
    final session = _match;
    if (session == null) return false;
    if (kind != EventKind.yellow && kind != EventKind.red) return false;
    if (session.status != MatchStatus.inProgress &&
        session.status != MatchStatus.paused) {
      return false;
    }
    try {
      await _repository.addEvent(
        MatchEvent.create(
          matchId: matchId,
          team: team,
          kind: kind,
          minute: session.clock.currentMinute,
        ),
      );
    } catch (e) {
      _error = 'No se pudo registrar la tarjeta: $e';
      notifyListeners();
      return false;
    }
    return _reload();
  }

  /// ¿Tiene al menos un gol este equipo? (Para mostrar el botón −1.)
  bool hasGoals(EventTeam team) {
    return _events.any(
      (e) => e.team == team && e.kind == EventKind.goal,
    );
  }

  /// El gol más reciente de un equipo (para la confirmación de −1).
  MatchEvent? lastGoal(EventTeam team) {
    final goals = _events
        .where((e) => e.team == team && e.kind == EventKind.goal)
        .toList();
    if (goals.isEmpty) return null;
    return goals.last;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
