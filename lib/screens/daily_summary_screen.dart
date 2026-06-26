import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // add share_plus to pubspec.yaml if not already present
import '../app_settings.dart';

/// One exercise's results for "today", used to populate the summary list.
/// Build a list of [ExerciseDaySummary] as the user completes each exercise
/// (e.g. accumulate it in whatever screen manages the session queue),
/// then pass the full list here once the last exercise is done.
class ExerciseDaySummary {
  final String exerciseName;
  final String unit;
  final int todayReps;
  final int currentStreak;
  final int lifetimeTotal;

  const ExerciseDaySummary({
    required this.exerciseName,
    required this.unit,
    required this.todayReps,
    required this.currentStreak,
    required this.lifetimeTotal,
  });
}

class DailySummaryScreen extends StatelessWidget {
  final List<ExerciseDaySummary> completedExercises;
  final int overallStreak;  // NEW: consecutive days any exercise was done

  /// Swap for your real app store / dynamic link once you have one.
  static const String appLink = 'https://potatocouch.app/download';

  const DailySummaryScreen({
    super.key,
    required this.completedExercises,
    this.overallStreak = 0,
  });

  int get _totalRepsToday =>
      completedExercises.fold(0, (sum, e) => sum + e.todayReps);

  String get _todayLabel {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  void _shareSummary() {
    final lines = completedExercises
        .map((e) => '🔥 ${e.exerciseName}: ${e.todayReps} ${e.unit} (${e.currentStreak}-day streak)')
        .join('\n');

    final text =
        "Today's Potato Couch session 🥔\n\n$lines\n\nTotal: $_totalRepsToday reps done today.\n\nJoin me: $appLink";

    // ignore: deprecated_member_use
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PCColors.cream,
      appBar: AppBar(
        backgroundColor: PCColors.cream,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "TODAY'S SUMMARY",
          style: TextStyle(
            color: PCColors.brownDark,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              _todayLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PCColors.brown.withValues(alpha: 0.7),
              ),
            ),

            const SizedBox(height: 16),

            // ── Overall streak hero badge ────────────────────────────────
            if (overallStreak > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: PCColors.brownDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PCColors.brown, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OVERALL STREAK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: PCColors.yellow,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '$overallStreak Days',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ── Hero total reps ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [PCColors.yellow, PCColors.yellowDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: PCColors.brown, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('🥔', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 6),
                    Text(
                      '$_totalRepsToday',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: PCColors.brownDark,
                      ),
                    ),
                    const Text(
                      'TOTAL DONE TODAY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: PCColors.brownDark,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Per-exercise list ─────────────────────────────────────────
            Expanded(
              child: completedExercises.isEmpty
                  ? Center(
                      child: Text(
                        'No exercises completed today.',
                        style: TextStyle(color: PCColors.brown.withValues(alpha: 0.7)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: completedExercises.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _ExerciseSummaryCard(item: completedExercises[i]),
                    ),
            ),

            // ── Buttons ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _shareSummary,
                      icon: const Icon(Icons.ios_share_rounded, size: 20),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PCColors.green,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: PCColors.green.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: PCColors.brown, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: PCColors.brown,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One row per exercise: today's reps + streak + lifetime total
// ─────────────────────────────────────────────────────────────────────────────
class _ExerciseSummaryCard extends StatelessWidget {
  final ExerciseDaySummary item;

  const _ExerciseSummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PCColors.brown.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // Exercise name + streak
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.exerciseName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: PCColors.brownDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🔥 ${item.currentStreak}-Day Streak',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PCColors.brown.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Today's reps
          _MiniStat(label: 'TODAY', value: '${item.todayReps}'),
          const SizedBox(width: 16),
          // Lifetime total
          _MiniStat(label: 'LIFETIME', value: '${item.lifetimeTotal}', highlight: true),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MiniStat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: highlight ? PCColors.greenDark : PCColors.brownDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: PCColors.brown,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
