import 'package:dep_stream/features/match/match_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchEvent', () {
    test('toMap/fromMap conservan todos los campos', () {
      final original = MatchEvent.create(
        matchId: 'm1',
        team: EventTeam.home,
        kind: EventKind.goal,
        minute: 24,
        createdAt: DateTime(2026, 11, 25, 18, 24),
      );

      final restored = MatchEvent.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.matchId, 'm1');
      expect(restored.team, EventTeam.home);
      expect(restored.kind, EventKind.goal);
      expect(restored.kind.label, 'Gol');
      expect(restored.minute, 24);
      expect(restored.createdAt, DateTime(2026, 11, 25, 18, 24));
    });

    test('las etiquetas de los tipos de evento son en español', () {
      expect(EventKind.goal.label, 'Gol');
      expect(EventKind.yellow.label, 'Amarilla');
      expect(EventKind.red.label, 'Roja');
    });

    test('un valor desconocido de equipo o tipo no rompe la lectura', () {
      final restored = MatchEvent.fromMap({
        'id': 'e1',
        'match_id': 'm1',
        'team': 'centro',
        'kind': 'penalti',
        'minute': 10,
        'created_at': 1000,
      });

      expect(restored.team, EventTeam.home);
      expect(restored.kind, EventKind.goal);
    });

    test('no permite minuto menor que 1', () {
      expect(
        () => MatchEvent.create(
          matchId: 'm1',
          team: EventTeam.away,
          kind: EventKind.yellow,
          minute: 0,
        ),
        throwsAssertionError,
      );
    });
  });
}
