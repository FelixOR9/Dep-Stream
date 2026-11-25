import 'package:dep_stream/features/match/match_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchClock', () {
    late DateTime fakeNow;

    MatchClock clock({
      int periodMinutes = 45,
      int periods = 2,
      DateTime Function()? now,
    }) {
      return MatchClock(
        periodDuration: Duration(minutes: periodMinutes),
        periodsCount: periods,
        now: now ?? () => fakeNow,
      );
    }

    setUp(() {
      fakeNow = DateTime(2026, 11, 25, 18, 0, 0);
    });

    test('arrancar en 0 → 90 s simulados → 90 s y minuto 2', () {
      final started = clock().start();
      fakeNow = fakeNow.add(const Duration(seconds: 90));

      expect(started.elapsed, const Duration(seconds: 90));
      expect(started.formattedElapsed, '01:30');
      expect(started.currentMinute, 2);
    });

    test('pausa a los 60 s → avanzan 60 s → sigue en 60 s; reanudar sigue',
        () {
      var c = clock().start();
      fakeNow = fakeNow.add(const Duration(seconds: 60));
      c = c.pause();

      expect(c.elapsed, const Duration(seconds: 60));
      expect(c.status, ClockStatus.paused);

      fakeNow = fakeNow.add(const Duration(seconds: 60));
      expect(c.elapsed, const Duration(seconds: 60));

      c = c.start();
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      expect(c.elapsed, const Duration(seconds: 90));
      expect(c.status, ClockStatus.running);
    });

    test('fin de periodo a los 30 s → 45:00 congelado; periodo 2 arranca en 0',
        () {
      var c = clock().start();
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      c = c.endPeriod();

      expect(c.status, ClockStatus.periodEnded);
      expect(c.elapsed, const Duration(minutes: 45));
      expect(c.formattedElapsed, '45:00');
      expect(c.currentPeriod, 1);

      c = c.startNextPeriod();
      expect(c.status, ClockStatus.running);
      expect(c.currentPeriod, 2);
      expect(c.elapsed, Duration.zero);
    });

    test('tope de periodo: 5 min, avanzan 7 min → 5:00 y periodEnded', () {
      var c = clock(periodMinutes: 5).start();
      fakeNow = fakeNow.add(const Duration(minutes: 7));

      final capped = c.applyPeriodCap();
      expect(capped.status, ClockStatus.periodEnded);
      expect(capped.elapsed, const Duration(minutes: 5));
      expect(capped.formattedElapsed, '05:00');
    });

    test('minuto global en 2º periodo: 10 min, duración 45 → minuto 56',
        () {
      final c = MatchClock(
        periodDuration: const Duration(minutes: 45),
        periodsCount: 2,
        currentPeriod: 2,
        status: ClockStatus.paused,
        accumulated: const Duration(minutes: 10),
        now: () => fakeNow,
      );

      expect(c.currentMinute, 56);
    });

    test('un gol en el 46 de un periodo de 45 se registra como minuto 45',
        () {
      final c = MatchClock(
        periodDuration: const Duration(minutes: 45),
        periodsCount: 2,
        currentPeriod: 1,
        status: ClockStatus.paused,
        accumulated: const Duration(minutes: 45),
        now: () => fakeNow,
      );

      expect(c.currentMinute, 45);
    });

    test('finalizar congela el tiempo aunque avance el reloj', () {
      var c = clock().start();
      fakeNow = fakeNow.add(const Duration(minutes: 20));
      c = c.finish();

      expect(c.status, ClockStatus.finished);
      expect(c.elapsed, const Duration(minutes: 20));

      fakeNow = fakeNow.add(const Duration(minutes: 10));
      expect(c.elapsed, const Duration(minutes: 20));
    });

    test('el reloj parado no avanza', () {
      final c = clock();
      fakeNow = fakeNow.add(const Duration(minutes: 5));
      expect(c.elapsed, Duration.zero);
      expect(c.formattedElapsed, '00:00');
      expect(c.currentMinute, 1);
    });
  });
}
