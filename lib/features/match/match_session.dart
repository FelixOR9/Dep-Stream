import 'dart:math';

import 'package:dep_stream/features/match/match_clock.dart';

/// Un partido. Es la única fuente de verdad del partido en Dep-Stream:
/// nada de duplicar equipos, fecha, marcador o reloj en dos sitios.
///
/// Etapa 1: equipos, colores, duración y periodos, marcador, reloj de
/// pared y 5 estados. Los jugadores, las alineaciones y los logos llegan
/// en la Etapa 6. El modelo es genérico por dentro (equipos + estado)
/// para que añadir futsal o baloncesto después sea configuración, no
/// reescritura.
class MatchSession {
  MatchSession({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.createdAt,
    this.status = MatchStatus.draft,
    this.homeColor = '#D32F2F',
    this.awayColor = '#1976D2',
    this.periodDurationMinutes = 45,
    this.periodsCount = 2,
    this.homeScore = 0,
    this.awayScore = 0,
    this.currentPeriod = 1,
    this.clockStatus = ClockStatus.stopped,
    this.clockStartedAt,
    this.clockAccumulatedMs = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt,
       assert(homeTeam.trim().isNotEmpty, 'El equipo local no puede estar vacío'),
       assert(awayTeam.trim().isNotEmpty, 'El equipo visitante no puede estar vacío'),
       assert(
         periodDurationMinutes >= 5 && periodDurationMinutes <= 90,
         'La duración del periodo debe estar entre 5 y 90 minutos',
       ),
       assert(periodsCount >= 1 && periodsCount <= 4,
           'El número de periodos debe estar entre 1 y 4'),
       assert(currentPeriod >= 1 && currentPeriod <= periodsCount,
           'El periodo actual debe estar entre 1 y el número de periodos'),
       assert(homeScore >= 0, 'El marcador local no puede ser negativo'),
       assert(awayScore >= 0, 'El marcador visitante no puede ser negativo'),
       assert(isValidColor(homeColor), 'El color local debe ser #RRGGBB'),
       assert(isValidColor(awayColor), 'El color visitante debe ser #RRGGBB');

  /// Crea un partido nuevo con id único y fecha de creación.
  factory MatchSession.create({
    required String homeTeam,
    required String awayTeam,
    DateTime? createdAt,
    String homeColor = '#D32F2F',
    String awayColor = '#1976D2',
    int periodDurationMinutes = 45,
    int periodsCount = 2,
  }) {
    final now = createdAt ?? DateTime.now();
    return MatchSession(
      id: _newId(now),
      homeTeam: homeTeam.trim(),
      awayTeam: awayTeam.trim(),
      createdAt: now,
      homeColor: homeColor,
      awayColor: awayColor,
      periodDurationMinutes: periodDurationMinutes,
      periodsCount: periodsCount,
    );
  }

  factory MatchSession.fromMap(Map<String, Object?> map) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      map['created_at'] as int,
    );
    final updatedAtMs = map['updated_at'] as int?;
    return MatchSession(
      id: map['id'] as String,
      homeTeam: map['home_team'] as String,
      awayTeam: map['away_team'] as String,
      createdAt: createdAt,
      status: MatchStatusX.fromName(map['status'] as String?),
      homeColor: map['home_color'] as String? ?? '#D32F2F',
      awayColor: map['away_color'] as String? ?? '#1976D2',
      periodDurationMinutes: map['period_duration_minutes'] as int? ?? 45,
      periodsCount: map['periods_count'] as int? ?? 2,
      homeScore: map['home_score'] as int? ?? 0,
      awayScore: map['away_score'] as int? ?? 0,
      currentPeriod: map['current_period'] as int? ?? 1,
      clockStatus: ClockStatusX.fromName(map['clock_status'] as String?),
      clockStartedAt: map['clock_started_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['clock_started_at'] as int,
            ),
      clockAccumulatedMs: map['clock_accumulated_ms'] as int? ?? 0,
      updatedAt: updatedAtMs == null || updatedAtMs == 0
          ? createdAt
          : DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
    );
  }

  final String id;
  final String homeTeam;
  final String awayTeam;
  final DateTime createdAt;
  final MatchStatus status;
  final String homeColor;
  final String awayColor;
  final int periodDurationMinutes;
  final int periodsCount;
  final int homeScore;
  final int awayScore;
  final int currentPeriod;
  final ClockStatus clockStatus;
  final DateTime? clockStartedAt;
  final int clockAccumulatedMs;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'home_team': homeTeam,
      'away_team': awayTeam,
      'created_at': createdAt.millisecondsSinceEpoch,
      'status': status.name,
      'home_color': homeColor,
      'away_color': awayColor,
      'period_duration_minutes': periodDurationMinutes,
      'periods_count': periodsCount,
      'home_score': homeScore,
      'away_score': awayScore,
      'current_period': currentPeriod,
      'clock_status': clockStatus.name,
      'clock_started_at': clockStartedAt?.millisecondsSinceEpoch,
      'clock_accumulated_ms': clockAccumulatedMs,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Título corto para la lista: "Águilas vs Leones".
  String get title => '$homeTeam vs $awayTeam';

  /// Marcador corto: "2 - 1".
  String get scoreText => '$homeScore - $awayScore';

  /// Reloj de pared de este partido, reconstruido desde los campos
  /// persistidos. El controlador lo usa para mostrar el tiempo.
  MatchClock get clock => MatchClock(
    periodDuration: Duration(minutes: periodDurationMinutes),
    periodsCount: periodsCount,
    currentPeriod: currentPeriod,
    status: clockStatus,
    accumulated: Duration(milliseconds: clockAccumulatedMs),
    startedAt: clockStartedAt,
  );

  /// Etiqueta del periodo actual: "Único tiempo", "1er tiempo", "2º tiempo".
  String get periodLabel {
    if (periodsCount == 1) return 'Único tiempo';
    switch (currentPeriod) {
      case 1:
        return '1er tiempo';
      case 2:
        return '2º tiempo';
      case 3:
        return '3er tiempo';
      default:
        return '$currentPeriodº tiempo';
    }
  }

  /// Etiqueta del siguiente periodo ("2º tiempo"), o vacía si no queda.
  String get nextPeriodLabel {
    if (currentPeriod >= periodsCount) return '';
    return copyWith(currentPeriod: currentPeriod + 1).periodLabel;
  }

  MatchSession copyWith({
    String? homeTeam,
    String? awayTeam,
    DateTime? createdAt,
    MatchStatus? status,
    String? homeColor,
    String? awayColor,
    int? periodDurationMinutes,
    int? periodsCount,
    int? homeScore,
    int? awayScore,
    int? currentPeriod,
    ClockStatus? clockStatus,
    DateTime? clockStartedAt,
    bool clearClockStartedAt = false,
    int? clockAccumulatedMs,
    DateTime? updatedAt,
  }) {
    return MatchSession(
      id: id,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      homeColor: homeColor ?? this.homeColor,
      awayColor: awayColor ?? this.awayColor,
      periodDurationMinutes: periodDurationMinutes ?? this.periodDurationMinutes,
      periodsCount: periodsCount ?? this.periodsCount,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      clockStatus: clockStatus ?? this.clockStatus,
      clockStartedAt: clearClockStartedAt
          ? null
          : (clockStartedAt ?? this.clockStartedAt),
      clockAccumulatedMs: clockAccumulatedMs ?? this.clockAccumulatedMs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Paleta de colores de equipo (Etapa 1): 8 colores, sin paquetes.
  static const List<String> teamColors = [
    '#D32F2F', // rojo
    '#1976D2', // azul
    '#388E3C', // verde
    '#FBC02D', // amarillo
    '#F57C00', // naranja
    '#7B1FA2', // morado
    '#212121', // negro
    '#F5F5F5', // blanco
  ];

  static final RegExp _colorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

  static bool isValidColor(String value) => _colorPattern.hasMatch(value);

  /// Convierte un color `#RRGGBB` a su valor entero para Flutter.
  static int colorValue(String hex) =>
      int.parse(hex.substring(1), radix: 16) + 0xFF000000;

  static String _newId(DateTime now) {
    final random = Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${now.millisecondsSinceEpoch.toRadixString(36)}-$random';
  }
}

/// Estado del partido.
enum MatchStatus { draft, inProgress, paused, periodEnded, finished }

extension MatchStatusX on MatchStatus {
  /// Etiqueta en español para la lista de partidos.
  String get label {
    switch (this) {
      case MatchStatus.draft:
        return 'Borrador';
      case MatchStatus.inProgress:
        return 'En vivo';
      case MatchStatus.paused:
        return 'Pausa';
      case MatchStatus.periodEnded:
        return 'Fin del periodo';
      case MatchStatus.finished:
        return 'Finalizado';
    }
  }

  static MatchStatus fromName(String? name) {
    for (final status in MatchStatus.values) {
      if (status.name == name) return status;
    }
    // Un valor desconocido nunca se presenta como un estado avanzado.
    return MatchStatus.draft;
  }
}
