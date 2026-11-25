import 'dart:math';

/// Un evento de un partido: un gol o una tarjeta, con su minuto.
///
/// Los eventos son la única fuente de verdad del marcador: el marcador
/// (`home_score`/`away_score`) es un caché de los eventos de gol, y ambos
/// se escriben siempre en la misma transacción (ver `MatchRepository`).
class MatchEvent {
  MatchEvent({
    required this.id,
    required this.matchId,
    required this.team,
    required this.kind,
    required this.minute,
    required this.createdAt,
  }) : assert(minute >= 1, 'El minuto del evento debe ser al menos 1');

  factory MatchEvent.create({
    required String matchId,
    required EventTeam team,
    required EventKind kind,
    required int minute,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return MatchEvent(
      id: _newId(now),
      matchId: matchId,
      team: team,
      kind: kind,
      minute: minute,
      createdAt: now,
    );
  }

  factory MatchEvent.fromMap(Map<String, Object?> map) {
    return MatchEvent(
      id: map['id'] as String,
      matchId: map['match_id'] as String,
      team: EventTeamX.fromName(map['team'] as String?),
      kind: EventKindX.fromName(map['kind'] as String?),
      minute: map['minute'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
    );
  }

  final String id;
  final String matchId;
  final EventTeam team;
  final EventKind kind;
  final int minute;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'match_id': matchId,
      'team': team.name,
      'kind': kind.name,
      'minute': minute,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  static String _newId(DateTime now) {
    final random = Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'ev-${now.millisecondsSinceEpoch.toRadixString(36)}-$random';
  }
}

/// Equipo al que pertenece el evento.
enum EventTeam { home, away }

extension EventTeamX on EventTeam {
  static EventTeam fromName(String? name) {
    for (final team in EventTeam.values) {
      if (team.name == name) return team;
    }
    return EventTeam.home;
  }
}

/// Tipo de evento.
enum EventKind { goal, yellow, red }

extension EventKindX on EventKind {
  /// Etiqueta en español para la lista de eventos.
  String get label {
    switch (this) {
      case EventKind.goal:
        return 'Gol';
      case EventKind.yellow:
        return 'Amarilla';
      case EventKind.red:
        return 'Roja';
    }
  }

  static EventKind fromName(String? name) {
    for (final kind in EventKind.values) {
      if (kind.name == name) return kind;
    }
    return EventKind.goal;
  }
}
