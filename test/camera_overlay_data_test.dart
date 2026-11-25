import 'package:dep_stream/features/camera/camera_overlay_data.dart';
import 'package:dep_stream/features/match/match_clock.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraOverlayData', () {
    test('partido 2-1, 2º tiempo, 23:41, en vivo', () {
      final match = MatchSession.create(
        homeTeam: 'Águilas',
        awayTeam: 'Leones',
        homeColor: '#D32F2F',
        awayColor: '#1976D2',
      ).copyWith(
        status: MatchStatus.inProgress,
        homeScore: 2,
        awayScore: 1,
        currentPeriod: 2,
        clockStatus: ClockStatus.paused,
        clockAccumulatedMs: (23 * 60 + 41) * 1000,
        clearClockStartedAt: true,
      );

      final data = CameraOverlayData.fromMatch(match);

      expect(data.homeTeam, 'Águilas');
      expect(data.awayTeam, 'Leones');
      expect(data.homeColor, '#D32F2F');
      expect(data.awayColor, '#1976D2');
      expect(data.scoreText, '2 - 1');
      expect(data.clockText, '23:41');
      expect(data.periodLabel, '2º tiempo');
      expect(data.statusLabel, 'En vivo');
    });

    test('partido en borrador: 0-0, 00:00, Borrador', () {
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');

      final data = CameraOverlayData.fromMatch(match);

      expect(data.scoreText, '0 - 0');
      expect(data.clockText, '00:00');
      expect(data.periodLabel, '1er tiempo');
      expect(data.statusLabel, 'Borrador');
    });

    test('partido finalizado: estado Finalizado y marcador final', () {
      final match = MatchSession.create(
        homeTeam: 'Águilas',
        awayTeam: 'Leones',
      ).copyWith(
        status: MatchStatus.finished,
        homeScore: 3,
        awayScore: 0,
        clockStatus: ClockStatus.finished,
        clockAccumulatedMs: 45 * 60 * 1000,
        clearClockStartedAt: true,
      );

      final data = CameraOverlayData.fromMatch(match);

      expect(data.scoreText, '3 - 0');
      expect(data.statusLabel, 'Finalizado');
    });

    test('color inválido en la base usa el color por defecto', () {
      // El constructor de MatchSession valida los colores con assert,
      // así que un color inválido solo puede llegar desde una base
      // corrupta en release (sin asserts). La defensa vive en
      // safeColor, que es lo que fromMatch usa para cada equipo.
      expect(CameraOverlayData.safeColor('rojo', '#D32F2F'), '#D32F2F');
      expect(CameraOverlayData.safeColor('#ZZZZZZ', '#1976D2'), '#1976D2');
      expect(CameraOverlayData.safeColor('', '#D32F2F'), '#D32F2F');
      expect(CameraOverlayData.safeColor('#388E3C', '#D32F2F'), '#388E3C');
    });
  });
}
