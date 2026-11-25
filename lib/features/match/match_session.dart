import 'dart:math';

/// Un partido. Es la única fuente de verdad del partido en Dep-Stream:
/// nada de duplicar equipos, fecha o estado en dos sitios.
///
/// En la Etapa 0 solo hay equipos, fecha y estado `draft`. El marcador,
/// el reloj, los jugadores y los eventos llegan en las Etapas 1 y 6.
/// El modelo es genérico por dentro (equipos + estado) para que añadir
/// futsal o baloncesto después sea configuración, no reescritura.
class MatchSession {
  MatchSession({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.createdAt,
    this.status = MatchStatus.draft,
  }) : assert(homeTeam.trim().isNotEmpty, 'El equipo local no puede estar vacío'),
       assert(awayTeam.trim().isNotEmpty, 'El equipo visitante no puede estar vacío');

  /// Crea un partido nuevo con id único y fecha de creación.
  factory MatchSession.create({
    required String homeTeam,
    required String awayTeam,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return MatchSession(
      id: _newId(now),
      homeTeam: homeTeam.trim(),
      awayTeam: awayTeam.trim(),
      createdAt: now,
    );
  }

  factory MatchSession.fromMap(Map<String, Object?> map) {
    return MatchSession(
      id: map['id'] as String,
      homeTeam: map['home_team'] as String,
      awayTeam: map['away_team'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      status: MatchStatusX.fromName(map['status'] as String?),
    );
  }

  final String id;
  final String homeTeam;
  final String awayTeam;
  final DateTime createdAt;
  final MatchStatus status;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'home_team': homeTeam,
      'away_team': awayTeam,
      'created_at': createdAt.millisecondsSinceEpoch,
      'status': status.name,
    };
  }

  /// Título corto para la lista: "Águilas vs Leones".
  String get title => '$homeTeam vs $awayTeam';

  static String _newId(DateTime now) {
    final random = Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${now.millisecondsSinceEpoch.toRadixString(36)}-$random';
  }
}

/// Estado del partido. En la Etapa 0 solo existe `draft`.
enum MatchStatus { draft }

extension MatchStatusX on MatchStatus {
  /// Etiqueta en español para la lista de partidos.
  String get label {
    switch (this) {
      case MatchStatus.draft:
        return 'Borrador';
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
