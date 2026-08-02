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
import '../services/streak_service.dart';

/// Shown right after a user submits reps for one exercise.
/// Celebrates the streak, shows today's + lifetime stats, then either
/// moves to the next selected exercise or to the final daily summary.
class CongratulationScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final int dayStreak;
  final int todayReps;
  final int lifetimeTotal;
  final String unit;
  final int overallStreak; // NEW: consecutive days any exercise was done

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
    required this.lifetimeTotal,
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
  late final String _heroImage;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    const images = ['assets/images/po1.png', 'assets/images/po2.png', 'assets/images/po3.png'];
    _heroImage = images[rng.nextInt(images.length)];
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Slight overshoot then settle — a small "pop" on the streak number.
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

    // ── Play sound immediately ──────────────────────────────────────────────
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

                  // ── Hero Graphic (Potato) ───────────────────────────────────
                  ScaleTransition(
                    scale: _scale,
                    child: Image.asset(
                      _heroImage,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Exercise Name ───────────────────────────────────────────
                  Text(
                    widget.exerciseName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: PCColors.yellow,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ── Huge Streak Number ──────────────────────────────────────
                  ScaleTransition(
                    scale: _scale,
                    child: Text(
                      '${widget.dayStreak}',
                      style: TextStyle(
                        fontSize: 100,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                        color: PCColors.yellow,
                        shadows: [
                          Shadow(
                            color: PCColors.yellow.withValues(alpha: 0.4),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ── "Day Streak!" ───────────────────────────────────────────
                  Text(
                    'day streak!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text(
                    'exercise_week_streak'.tr(args: [widget.exerciseName]).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Live 7-Day Activity Row ─────────────────────────────────
                  _buildLiveWeekStreakRow(),

                  const SizedBox(height: 32),
                  
                  Divider(color: context.borderColor.withValues(alpha: 0.3), thickness: 1),
                  
                  const SizedBox(height: 20),

                  // ── Stats row: today's reps / lifetime total ────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'today_label'.tr(),
                          value: '${widget.todayReps}',
                          sub: widget.unit,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'lifetime_label'.tr(),
                          value: '${widget.lifetimeTotal}',
                          sub: widget.unit,
                          highlight: true,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // ── Continue button ──────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => widget.onContinue(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLast ? PCColors.yellow : PCColors.green,
                        foregroundColor: isLast ? PCColors.brownDark : Colors.white,
                        elevation: 4,
                        shadowColor: (isLast ? PCColors.yellow : PCColors.green)
                            .withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100), // Pill shape
                        ),
                      ),
                      child: Text(
                        isLast
                            ? 'finish_and_summary'.tr().toUpperCase()
                            : 'next_exercise'.tr().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // ── Confetti Animation ──────────────────────────────────────────
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
    // Method to convert degree to radians
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('exercises')
          .doc(widget.exerciseId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox(height: 70); // Placeholder
        }

        final exData = snapshot.data!.data() as Map<String, dynamic>;
        
        final rawCurrentStreak = (exData['currentStreak'] ?? 0) as int;
        final rawFreezesAvailable = (exData['freezesAvailable'] ?? 2) as int;
        final rawFrozenDates = List<String>.from(exData['frozenDates'] ?? []);
        final rawLastEvaluatedDate = exData['lastEvaluatedDate'] as String?;
        final activeDatesList = List<String>.from(exData['activeDates'] ?? []);

        final effectiveData = StreakService.getEffectiveStreakData(
          streak: rawCurrentStreak,
          freezesAvailable: rawFreezesAvailable,
          frozenDates: rawFrozenDates,
          lastEvaluatedDate: rawLastEvaluatedDate,
        );

        return WeekStreakRow(
          activeDates: activeDatesList,
          frozenDates: effectiveData.frozenDates.toList(),
          today: DateTime.now(),
          freezesAvailable: effectiveData.freezesAvailable,
          streak: effectiveData.streak,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card — same white-card + border language used across the app.
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: highlight
            ? PCColors.yellow.withValues(alpha: 0.2)
            : context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? PCColors.yellow.withValues(alpha: 0.6)
              : context.borderColor,
          width: highlight ? 1.8 : 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
