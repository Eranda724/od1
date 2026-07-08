import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // add share_plus to pubspec.yaml if not already present
import '../app_settings.dart';
import 'package:easy_localization/easy_localization.dart';

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

  String _todayLabel(BuildContext context) {
    return DateFormat.yMMMd(context.locale.languageCode).format(DateTime.now());
  }

  void _shareSummary(BuildContext context) {
    final lines = completedExercises
        .map((e) => '🔥 ${e.exerciseName}: ${e.todayReps} ${e.unit} (' + 'day_streak_count'.tr(args: [e.currentStreak.toString()]) + ')')
        .join('\n');

    final text = 'share_summary_text'.tr(args: [lines, _totalRepsToday.toString(), appLink]);

    // ignore: deprecated_member_use
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'todays_summary_title'.tr(),
          style: TextStyle(
            color: context.textPrimary,
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
              _todayLabel(context),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.textSecondary,
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
                          Text(
                            'overall_streak_label'.tr(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: PCColors.yellow,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'days_count'.tr(args: [overallStreak.toString()]),
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
                    Text(
                      'total_done_today_label'.tr(),
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
                        'no_exercises_completed'.tr(),
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
                      onPressed: () => _shareSummary(context),
                      icon: const Icon(Icons.ios_share_rounded, size: 20),
                      label: Text('share_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
                      'done_btn'.tr(),
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
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 1.5),
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🔥 ' + 'day_streak_count'.tr(args: [item.currentStreak.toString()]),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Today's reps
          _MiniStat(label: 'today_label'.tr(), value: '${item.todayReps}'),
          const SizedBox(width: 16),
          // Lifetime total
          _MiniStat(label: 'lifetime_label'.tr(), value: '${item.lifetimeTotal}', highlight: true),
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
            color: highlight ? PCColors.green : context.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: context.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
