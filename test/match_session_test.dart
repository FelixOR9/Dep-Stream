import 'package:dep_stream/features/match/match_clock.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchSession', () {
    test('crea un partido en borrador con id único y equipos recortados', () {
      final a = MatchSession.create(homeTeam: '  Águilas ', awayTeam: 'Leones');
      final b = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');

      expect(a.homeTeam, 'Águilas');
      expect(a.awayTeam, 'Leones');
      expect(a.status, MatchStatus.draft);
      expect(a.status.label, 'Borrador');
      expect(a.title, 'Águilas vs Leones');
      expect(a.id, isNot(b.id));
    });

    test('toMap/fromMap conservan todos los campos', () {
      final original = MatchSession.create(
        homeTeam: 'Águilas',
        awayTeam: 'Leones',
        createdAt: DateTime(2026, 11, 24, 18, 30),
      );

      final restored = MatchSession.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.homeTeam, 'Águilas');
      expect(restored.awayTeam, 'Leones');
      expect(restored.createdAt, DateTime(2026, 11, 24, 18, 30));
      expect(restored.status, MatchStatus.draft);
    });

    test('los campos nuevos tienen valores por defecto de la Etapa 0', () {
      final match = MatchSession.create(homeTeam: 'Águilas', awayTeam: 'Leones');

      expect(match.homeColor, '#D32F2F');
      expect(match.awayColor, '#1976D2');
      expect(match.periodDurationMinutes, 45);
      expect(match.periodsCount, 2);
      expect(match.homeScore, 0);
      expect(match.awayScore, 0);
      expect(match.scoreText, '0 - 0');
      expect(match.currentPeriod, 1);
      expect(match.periodLabel, '1er tiempo');
      expect(match.clockStatus, ClockStatus.stopped);
      expect(match.clockStartedAt, isNull);
      expect(match.clockAccumulatedMs, 0);
    });

    test('toMap/fromMap conservan colores, duración, marcador y reloj', () {
      final original = MatchSession.create(
        homeTeam: 'Tigres',
        awayTeam: 'Pumas',
        homeColor: '#388E3C',
        awayColor: '#FBC02D',
        periodDurationMinutes: 20,
        periodsCount: 2,
      ).copyWith(
        status: MatchStatus.inProgress,
        homeScore: 2,
        awayScore: 1,
        currentPeriod: 2,
        clockStatus: ClockStatus.paused,
        clockAccumulatedMs: 600000,
      );

      final restored = MatchSession.fromMap(original.toMap());

      expect(restored.homeColor, '#388E3C');
      expect(restored.awayColor, '#FBC02D');
      expect(restored.periodDurationMinutes, 20);
      expect(restored.periodsCount, 2);
      expect(restored.homeScore, 2);
      expect(restored.awayScore, 1);
      expect(restored.scoreText, '2 - 1');
      expect(restored.currentPeriod, 2);
      expect(restored.periodLabel, '2º tiempo');
      expect(restored.clockStatus, ClockStatus.paused);
      expect(restored.clockAccumulatedMs, 600000);
    });

    test('las etiquetas de los 5 estados son en español', () {
      expect(MatchStatus.draft.label, 'Borrador');
      expect(MatchStatus.inProgress.label, 'En vivo');
      expect(MatchStatus.paused.label, 'Pausa');
      expect(MatchStatus.periodEnded.label, 'Fin del periodo');
      expect(MatchStatus.finished.label, 'Finalizado');
    });

    test('un periodo único se etiqueta como único tiempo', () {
      final match = MatchSession.create(
        homeTeam: 'Águilas',
        awayTeam: 'Leones',
        periodsCount: 1,
      );
      expect(match.periodLabel, 'Único tiempo');
    });

    test('valida duración, periodos y colores', () {
      expect(
        () => MatchSession.create(
          homeTeam: 'Águilas',
          awayTeam: 'Leones',
          periodDurationMinutes: 3,
        ),
        throwsAssertionError,
      );
      expect(
        () => MatchSession.create(
          homeTeam: 'Águilas',
          awayTeam: 'Leones',
          periodsCount: 5,
        ),
        throwsAssertionError,
      );
      expect(
        () => MatchSession.create(
          homeTeam: 'Águilas',
          awayTeam: 'Leones',
          homeColor: 'rojo',
        ),
        throwsAssertionError,
      );
      expect(MatchSession.teamColors.length, 8);
      expect(MatchSession.isValidColor('#D32F2F'), isTrue);
      expect(MatchSession.isValidColor('#d32f2f'), isTrue);
      expect(MatchSession.isValidColor('D32F2F'), isFalse);
    });

    test('un estado desconocido se lee como borrador, nunca como avanzado', () {
      final restored = MatchSession.fromMap({
        'id': 'x1',
        'home_team': 'Águilas',
        'away_team': 'Leones',
        'created_at': 1000,
        'status': 'transmitiendo',
      });

      expect(restored.status, MatchStatus.draft);
    });

    test('no permite equipos vacíos', () {
      expect(
        () => MatchSession.create(homeTeam: '   ', awayTeam: 'Leones'),
        throwsAssertionError,
      );
      expect(
        () => MatchSession.create(homeTeam: 'Águilas', awayTeam: ''),
        throwsAssertionError,
      );
    });
  });
}
