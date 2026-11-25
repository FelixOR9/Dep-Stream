/// Estado del reloj de un partido.
///
/// El reloj es hora de pared: `startedAt` + `accumulated` viven en SQLite
/// y el tiempo transcurrido siempre se recalcula desde la hora actual.
/// `periodEnded` y `finished` son estados finales del tramo en curso.
enum ClockStatus { stopped, running, paused, periodEnded, finished }

extension ClockStatusX on ClockStatus {
  static ClockStatus fromName(String? name) {
    for (final status in ClockStatus.values) {
      if (status.name == name) return status;
    }
    // Un valor desconocido nunca se presenta como un reloj en marcha.
    return ClockStatus.stopped;
  }
}

/// Reloj de un partido, basado en hora de pared. Dart puro, sin Flutter.
///
/// No acumula tiempo con un `Timer`: el tiempo transcurrido se calcula
/// siempre como `accumulated + (ahora - startedAt)` mientras está en
/// marcha. Por eso sobrevive a cerrar la app, al segundo plano y al
/// reinicio del teléfono: todo el estado vive en SQLite y se restaura.
///
/// Recibe una función `now` inyectable para poder probarlo con tiempo
/// falso, sin esperar tiempo real.
class MatchClock {
  MatchClock({
    required this.periodDuration,
    required this.periodsCount,
    this.currentPeriod = 1,
    this.status = ClockStatus.stopped,
    this.accumulated = Duration.zero,
    this.startedAt,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       assert(periodDuration.inMinutes >= 5 && periodDuration.inMinutes <= 90,
           'La duración del periodo debe estar entre 5 y 90 minutos'),
       assert(periodsCount >= 1 && periodsCount <= 4,
           'El número de periodos debe estar entre 1 y 4'),
       assert(currentPeriod >= 1 && currentPeriod <= periodsCount,
           'El periodo actual debe estar entre 1 y el número de periodos');

  final Duration periodDuration;
  final int periodsCount;
  final int currentPeriod;
  final ClockStatus status;
  final Duration accumulated;
  final DateTime? startedAt;
  final DateTime Function() _now;

  DateTime get now => _now();

  /// Tiempo transcurrido en el periodo actual, sin tope.
  Duration get elapsed {
    if (status == ClockStatus.running && startedAt != null) {
      return accumulated + _now().difference(startedAt!);
    }
    return accumulated;
  }

  /// Tiempo transcurrido con tope en la duración del periodo: el reloj
  /// nunca muestra más minutos de los que dura el periodo.
  Duration get elapsedCapped =>
      elapsed > periodDuration ? periodDuration : elapsed;

  /// Minuto de partido (global, con todos los periodos): 1 en el primer
  /// minuto, con tope en la duración del periodo (un gol en el 46' de un
  /// periodo de 45' se registra como minuto 45).
  int get currentMinute {
    final inPeriod = elapsed.inMinutes + 1;
    final capped = inPeriod > periodDuration.inMinutes
        ? periodDuration.inMinutes
        : inPeriod;
    return (currentPeriod - 1) * periodDuration.inMinutes + capped;
  }

  /// Tiempo en pantalla: `MM:SS`.
  String get formattedElapsed {
    final total = elapsedCapped.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get isRunning => status == ClockStatus.running;

  MatchClock copyWith({
    Duration? periodDuration,
    int? periodsCount,
    int? currentPeriod,
    ClockStatus? status,
    Duration? accumulated,
    DateTime? startedAt,
    bool clearStartedAt = false,
  }) {
    return MatchClock(
      periodDuration: periodDuration ?? this.periodDuration,
      periodsCount: periodsCount ?? this.periodsCount,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      status: status ?? this.status,
      accumulated: accumulated ?? this.accumulated,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      now: _now,
    );
  }

  /// Arranca el reloj: desde parado (acumulado a 0) o desde pausa.
  MatchClock start() {
    if (status == ClockStatus.stopped) {
      return copyWith(
        status: ClockStatus.running,
        accumulated: Duration.zero,
        startedAt: _now(),
      );
    }
    if (status == ClockStatus.paused) {
      return copyWith(status: ClockStatus.running, startedAt: _now());
    }
    return this;
  }

  /// Pausa el reloj: el tiempo acumulado queda guardado.
  MatchClock pause() {
    if (status != ClockStatus.running) return this;
    return copyWith(
      status: ClockStatus.paused,
      accumulated: elapsedCapped,
      clearStartedAt: true,
    );
  }

  /// Termina el periodo: el tiempo queda congelado en la duración del
  /// periodo y el reloj se para.
  MatchClock endPeriod() {
    if (status != ClockStatus.running && status != ClockStatus.paused) {
      return this;
    }
    return copyWith(
      status: ClockStatus.periodEnded,
      accumulated: periodDuration,
      clearStartedAt: true,
    );
  }

  /// Inicia el siguiente periodo, si queda alguno. Resetea el acumulado.
  MatchClock startNextPeriod() {
    if (status != ClockStatus.periodEnded) return this;
    if (currentPeriod >= periodsCount) return this;
    return copyWith(
      status: ClockStatus.running,
      currentPeriod: currentPeriod + 1,
      accumulated: Duration.zero,
      startedAt: _now(),
    );
  }

  /// Finaliza el partido: el tiempo queda congelado donde estaba.
  MatchClock finish() {
    if (status == ClockStatus.finished) return this;
    final finalElapsed = status == ClockStatus.running
        ? elapsedCapped
        : accumulated;
    return copyWith(
      status: ClockStatus.finished,
      accumulated: finalElapsed,
      clearStartedAt: true,
    );
  }

  /// Guarda de tope al cargar: si el tiempo transcurrido supera la
  /// duración del periodo (por ejemplo, el teléfono se reinició en mitad
  /// del partido), el reloj se congela en la duración del periodo y el
  /// estado pasa a `periodEnded`. Devuelve el reloj corregido, o `this`
  /// si no hacía falta corregir nada.
  MatchClock applyPeriodCap() {
    if (status == ClockStatus.running && elapsed > periodDuration) {
      return copyWith(
        status: ClockStatus.periodEnded,
        accumulated: periodDuration,
        clearStartedAt: true,
      );
    }
    return this;
  }
}
