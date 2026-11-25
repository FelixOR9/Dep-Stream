import 'package:dep_stream/features/match/match_session.dart';

/// Datos del overlay de cámara, Dart puro.
///
/// Se construye desde un [MatchSession]: equipos y colores, marcador,
/// reloj `MM:SS`, etiqueta de periodo y estado. Sin lógica de cámara
/// y sin Flutter: se puede probar con tests unitarios y es el mismo
/// modelo que la Etapa 3 usará para dibujar el overlay quemado en el
/// vídeo. Un solo diseño fijo (decisión de Félix): las plantillas
/// editables llegan en la Etapa 6.
class CameraOverlayData {
  const CameraOverlayData({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeColor,
    required this.awayColor,
    required this.homeScore,
    required this.awayScore,
    required this.clockText,
    required this.periodLabel,
    required this.statusLabel,
  });

  /// Construye los datos desde el partido. Un color inválido en la
  /// base (defensa) no rompe la construcción: se usa el color por
  /// defecto de ese equipo.
  factory CameraOverlayData.fromMatch(MatchSession match) {
    return CameraOverlayData(
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
      homeColor: safeColor(match.homeColor, '#D32F2F'),
      awayColor: safeColor(match.awayColor, '#1976D2'),
      homeScore: match.homeScore,
      awayScore: match.awayScore,
      clockText: match.clock.formattedElapsed,
      periodLabel: match.periodLabel,
      statusLabel: match.status.label,
    );
  }

  final String homeTeam;
  final String awayTeam;
  final String homeColor;
  final String awayColor;
  final int homeScore;
  final int awayScore;
  final String clockText;
  final String periodLabel;
  final String statusLabel;

  /// Marcador corto: "2 - 1".
  String get scoreText => '$homeScore - $awayScore';

  /// Color seguro para el overlay: el valor si es `#RRGGBB`, o el
  /// color por defecto del equipo si no lo es. El constructor de
  /// `MatchSession` ya valida los colores con `assert`, pero en
  /// release los asserts no existen: si la base trae un color
  /// corrupto, el overlay no debe romperse.
  static String safeColor(String value, String fallback) =>
      MatchSession.isValidColor(value) ? value : fallback;
}
