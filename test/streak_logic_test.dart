import 'package:flutter_test/flutter_test.dart';
import 'package:Potato/services/streak_service.dart';

/// Unit test that simulates the exact September 2026 timeline and asserts
/// the correct final state after the logic rewrite (where timer starts on FIRST freeze used).
///
/// Timeline:
///   Sep 4  – Exercise (first ever).  streak=1, freezes=2
///   Sep 5  – Miss.                   streak=1, freezes=1, frozenDates: [Sep5]
///                                    recharge timer starts: Sep5+15 = Sep20
///   Sep 6  – Exercise.               streak=2, freezes=1
///   Sep 7  – Miss.                   streak=2, freezes=0, frozenDates: [Sep5,Sep7]
///                                    timer is already running.
///   Sep 8  – Exercise.               streak=3, freezes=0
///   Sep 9  – Miss, 0 freezes.        streak=0 (breaks), Sep9=grey
///   Sep10–14 – Nothing.              streak=0
///   Sep15  – Exercise restart.       streak=1, freezes=0
///   Sep16–19 – Daily exercise.       streak=2..5, freezes=0
///   Sep20  – Daily exercise.         streak=6, freezes=0
///                                    end-of-day Sep20: recharge fires → freezes=2
///   Sep21  – Daily exercise.         streak=7, freezes=2
///   Sep22  – Miss, 2 freezes.        streak=7, freezes=1, frozenDates: [Sep5, Sep7, Sep22]
///                                    recharge timer starts: Sep22+15 = Oct07
///   Sep23  – Today (evaluated).      streak=7, freezes=1, timer = Oct07
void main() {
  group('StreakService._simulateForward – September 2026 timeline (timer starts on first freeze)', () {
    // Helper to build a date key string.
    String dk(int month, int day) =>
        '2026-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    // Active days (days the user exercised).
    final List<String> activeDates = [
      dk(9, 4),  // Sep 4
      dk(9, 6),  // Sep 6
      dk(9, 8),  // Sep 8
      dk(9, 15), dk(9, 16), dk(9, 17), dk(9, 18), dk(9, 19), dk(9, 20), dk(9, 21), // Sep 15-21
    ];

    test('Step 1: Misses on Sep 5, Sep 7, breaks on Sep 9', () {
      final result = StreakService.getEffectiveDisplayState(
        streak: 3,                          // Simulated streak after Sep 8 exercise
        freezesAvailable: 2,               // initial
        frozenDates: [],
        nextFreezeRechargeDate: null,
        activeDates: activeDates,
        lastEvaluatedDate: dk(9, 4),          // last evaluated = Sep 4
        todayOverride: DateTime(2026, 9, 10), // Stop simulation right after Sep 9
      );

      // Timer starts on Sep 5 -> expires on Sep 20.
      expect(result.frozenDates, contains(dk(9, 5)));
      expect(result.frozenDates, contains(dk(9, 7)));
      expect(result.streak, equals(0)); // Broke on Sep 9
      expect(result.nextFreezeRechargeDate, equals(dk(9, 20)));
    });

    test('Step 2: Recharge fires Sep 20, Sep 22 uses a freeze', () {
      // Simulate that the user has been opening the app and exercising until Sep 21.
      // So lastEvaluatedDate is Sep 21. The timer we started on Sep 5 is still pending for Sep 20.
      // Actually, if we evaluate from Sep 19 to Sep 23:
      final result = StreakService.getEffectiveDisplayState(
        streak: 7,                          // streak after Sep 21 exercise
        freezesAvailable: 0,               // used up earlier
        frozenDates: [dk(9, 5), dk(9, 7)],
        nextFreezeRechargeDate: dk(9, 20), // Timer from Sep 5
        activeDates: activeDates,
        lastEvaluatedDate: dk(9, 19),          // evaluate from Sep 19
        todayOverride: DateTime(2026, 9, 23),
      );

      // Sep 20: recharge fires -> freezes = 2.
      // Sep 22: Miss. Freezes = 2 -> 1. Timer starts for Oct 7.
      expect(result.frozenDates, contains(dk(9, 22)), reason: 'Sep 22 should be frozen');
      expect(result.streak, equals(7), reason: 'Streak protected');
      expect(result.freezesAvailable, equals(1));
      expect(result.nextFreezeRechargeDate, equals(dk(10, 7)));
    });
  });
}
