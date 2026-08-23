import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // add share_plus to pubspec.yaml if not already present
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
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
  final int monthlyTotal;

  const ExerciseDaySummary({
    required this.exerciseName,
    required this.unit,
    required this.todayReps,
    required this.currentStreak,
    required this.monthlyTotal,
  });
}

class DailySummaryScreen extends StatefulWidget {
  final List<ExerciseDaySummary> completedExercises;
  final int overallStreak; // NEW: consecutive days any exercise was done

  /// Swap for your real app store / dynamic link once you have one.
  static const String appLink = 'https://potatocouch.app/download';

  const DailySummaryScreen({
    super.key,
    required this.completedExercises,
    this.overallStreak = 0,
  });

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final String _celebrationImage;

  static const List<String> _celebrationImages = [
    'assets/images/congrads_po1.png',
    'assets/images/congrads_po2.png',
    'assets/images/congrads_po3.png',
    'assets/images/p5.png',
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    // Pick a random celebration character for this session
    _celebrationImage = (_celebrationImages..shuffle()).first;
    // Play the full routine finish sound and start confetti
    _audioPlayer.play(AssetSource('sounds/routin-finish.mp3'));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  int get _totalRepsToday =>
      widget.completedExercises.fold(0, (sum, e) => sum + e.todayReps);

  void _shareSummary(BuildContext context) {
    final lines = widget.completedExercises
        .map(
          (e) =>
              '🔥 ${e.exerciseName}: ${e.todayReps} ${e.unit} (' +
              'day_streak_count'.tr(args: [e.currentStreak.toString()]) +
              ')',
        )
        .join('\n');

    final text = 'share_summary_text'.tr(
      args: [lines, _totalRepsToday.toString(), DailySummaryScreen.appLink],
    );

    // ignore: deprecated_member_use
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Yellow Hero Card ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFffc226),
                    borderRadius: BorderRadius.all(Radius.circular(32)),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Image.asset(
                          _celebrationImage,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'PERSONAL',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5A3D00),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.overallStreak}',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF332200),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'DAY STREAK',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5A3D00),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Per-exercise list ─────────────────────────────────────────
              Expanded(
                child: widget.completedExercises.isEmpty
                    ? Center(
                        child: Text(
                          'no_exercises_completed'.tr(),
                          style: TextStyle(
                            color: PCColors.brown.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: widget.completedExercises.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) => _ExerciseSummaryCard(
                          item: widget.completedExercises[i],
                        ),
                      ),
              ),

              // ── Buttons ───────────────────────────────────────────────────
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  decoration: BoxDecoration(
                    color: context.surface,
                    border: Border(
                      top: BorderSide(color: context.borderColor, width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: PCColors.greenDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ElevatedButton.icon(
                          onPressed: () => _shareSummary(context),
                          icon: const Icon(Icons.ios_share_rounded, size: 20),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'share_btn'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PCColors.green,
                            foregroundColor: Colors.white,
                            elevation: 6,
                            shadowColor: Colors.black.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'done_btn'.tr(),
                            style: TextStyle(
                              color: PCColors.brown,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.bottomCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.directional,
              blastDirection: -1.5708, // straight up
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 100,
              minBlastForce: 80,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/fire_3d.png',
                      width: 14,
                      height: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'day_streak_count'.tr(
                        args: [item.currentStreak.toString()],
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),

          // Today's reps
          _MiniStat(label: 'today_label'.tr(), value: '${item.todayReps}'),
          const SizedBox(width: 16),
          // Lifetime total
          _MiniStat(
            label: 'this_month_label'.tr(),
            value: '${item.monthlyTotal}',
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

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
