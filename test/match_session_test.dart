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
