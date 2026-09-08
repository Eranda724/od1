import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/week_streak_row.dart';
import '../widgets/network_or_asset_image.dart';
import '../services/streak_service.dart';
import '../services/image_bank.dart';

/// Shown right after a user submits reps for one exercise.
/// Celebrates the streak with mascot, confetti, and sound, displays 3-column
/// stats (streak, today, this month), the live 7-day week streak row, and
/// a 3D yellow button to advance to the next exercise or summary.
class CongratulationScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final int dayStreak;
  final int todayReps;
  final int monthlyTotal;
  final int lifetimeTotal;
  final String unit;
  final int overallStreak;

  /// 1-based index of this exercise in the user's session (e.g. 2 of 3).
  /// Pass null (or totalExercises == 1) to hide the progress indicator.
  final int? exerciseIndex;
  final int? totalExercises;

  /// Called when the button is pressed.
  final void Function(BuildContext) onContinue;

  const CongratulationScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.dayStreak,
    required this.todayReps,
    required this.monthlyTotal,
    this.lifetimeTotal = 0,
    this.unit = 'reps',
    this.overallStreak = 0,
    this.exerciseIndex,
    this.totalExercises,
    required this.onContinue,
  });

  bool get isLastExercise =>
      exerciseIndex == null ||
      totalExercises == null ||
      exerciseIndex! >= totalExercises!;

  @override
  State<CongratulationScreen> createState() => _CongratulationScreenState();
}

class _CongratulationScreenState extends State<CongratulationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final ConfettiController _confettiController;
  AudioPlayer? _player;
  late final String _randomImage;

  @override
  void initState() {
    super.initState();

    _randomImage = ImageBank.randomExerciseCongrats();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Slight overshoot then settle — a small "pop" on the hero mascot & badge.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.4,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);
    _controller.forward();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );
    _confettiController.play(); // fireworks start immediately

    _playSound();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _controller.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _playSound() async {
    try {
      _player = AudioPlayer();
      await _player!.play(AssetSource('sounds/congradulation.mp3'));
    } catch (_) {
      // Sound failure is non-critical — silently ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = widget.isLastExercise;

    return Scaffold(
      backgroundColor: context.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Hero Graphic (Potato Mascot + Star Badge)
                  ScaleTransition(
                    scale: _scale,
                    child: SizedBox(
                      height: 290,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          NetworkOrAssetImage(
                            _randomImage,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Headline: "EXCELLENT !" + Exercise Name
                  Text(
                    'excellent_title'.tr(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.exerciseName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Unified 3-Column Stats Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: context.borderColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // 1. Overall Day Streak
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 24,
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/fire_3d.png',
                                      height: 20,
                                      width: 20,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${widget.dayStreak}',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'streak_days_label'.tr().toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          VerticalDivider(
                            color: context.borderColor,
                            thickness: 1,
                            indent: 6,
                            endIndent: 6,
                          ),
                          // 2. Today's Reps
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 24,
                                  child: Center(
                                    child: Text(
                                      'today_text'.tr().toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${widget.todayReps}',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.unit.toLowerCase() == 'seconds' || widget.unit.toLowerCase() == 'time'
                                      ? 'seconds_count'.tr(args: ['']).trim().toUpperCase()
                                      : 'repetitions'.tr().toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          VerticalDivider(
                            color: context.borderColor,
                            thickness: 1,
                            indent: 6,
                            endIndent: 6,
                          ),
                          // 3. Lifetime Reps Total
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 24,
                                  child: Center(
                                    child: Text(
                                      'lifetime_label'.tr().toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${widget.lifetimeTotal}',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.unit.toLowerCase() == 'seconds' || widget.unit.toLowerCase() == 'time'
                                      ? 'seconds_count'.tr(args: ['']).trim().toUpperCase()
                                      : 'repetitions'.tr().toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Live 7-Day Activity Row
                  Text(
                    'exercise_week_streak'
                        .tr(args: [widget.exerciseName])
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLiveWeekStreakRow(),

                  const Spacer(flex: 2),

                  // 3D Yellow Action Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: PCColors
                              .yellowDark, // Darker yellow for 3D effect
                          offset: Offset(0, 5),
                          blurRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => widget.onContinue(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PCColors.yellow,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        isLast
                            ? 'finish_and_summary'.tr().toUpperCase()
                            : 'next_exercise'.tr().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Confetti Animation
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                PCColors.green,
                PCColors.yellow,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
              createParticlePath: drawStar,
            ),
          ),
        ],
      ),
    );
  }

  /// A custom Path to paint stars.
  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (math.pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * math.cos(step),
        halfWidth + externalRadius * math.sin(step),
      );
      path.lineTo(
        halfWidth + internalRadius * math.cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * math.sin(step + halfDegreesPerStep),
      );
    }
    path.close();
    return path;
  }

  Widget _buildLiveWeekStreakRow() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    // Fetch both the user doc (for frozenDates) and the exercise doc in parallel
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: Stream.fromFuture(
        Future.wait([
          FirebaseFirestore.instance.collection('users').doc(uid).get(),
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('exercises')
              .doc(widget.exerciseId)
              .get(),
        ]),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 70); // Placeholder
        }

        final userDoc = snapshot.data![0];
        final exDoc = snapshot.data![1];

        if (!exDoc.exists) return const SizedBox(height: 70);

        final userData =
            userDoc.exists ? userDoc.data() as Map<String, dynamic> : {};
        final exData = exDoc.data() as Map<String, dynamic>;

        // Global frozen dates live on the user document (same source as streak screen)
        final frozenDates =
            List<String>.from(userData['frozenDates'] ?? []);

        final rawCurrentStreak = (exData['currentStreak'] ?? 0) as int;
        final rawLastEvaluatedDate = exData['lastEvaluatedDate'] as String?;
        final activeDatesList = List<String>.from(exData['activeDates'] ?? []);

        final effectiveData = StreakService.getEffectiveExerciseStreakData(
          streak: rawCurrentStreak,
          lastEvaluatedDate: rawLastEvaluatedDate,
          globalFrozenDates: frozenDates,
        );

        return WeekStreakRow(
          activeDates: activeDatesList,
          frozenDates: frozenDates,
          today: DateTime.now(),
          streak: effectiveData.streak,
        );
      },
    );
  }
}
