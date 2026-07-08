import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import '../app_settings.dart';

/// Shown right after a user submits reps for one exercise.
/// Celebrates the streak, shows today's + lifetime stats, then either
/// moves to the next selected exercise or to the final daily summary.
class CongratulationScreen extends StatefulWidget {
  final String exerciseName;
  final int dayStreak;
  final int todayReps;
  final int lifetimeTotal;
  final String unit;
  final int overallStreak;  // NEW: consecutive days any exercise was done

  /// 1-based index of this exercise in the user's session (e.g. 2 of 3).
  /// Pass null (or totalExercises == 1) to hide the progress indicator.
  final int? exerciseIndex;
  final int? totalExercises;

  /// Called when the button is pressed.
  final void Function(BuildContext) onContinue;

  const CongratulationScreen({
    super.key,
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
      exerciseIndex == null || totalExercises == null || exerciseIndex! >= totalExercises!;

  @override
  State<CongratulationScreen> createState() => _CongratulationScreenState();
}

class _CongratulationScreenState extends State<CongratulationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final ConfettiController _confettiController;
  AudioPlayer? _player;
  Timer? _confettiTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Slight overshoot then settle — a small "pop" on the streak number.
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.15)
          .chain(CurveTween(curve: Curves.easeOutBack)), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(_controller);
    _controller.forward();

    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _confettiController.play(); // fireworks start immediately

    // ── Play sound after 3s ────────────────────────────────────────────────
    _confettiTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) _playSound();
    });
  }

  @override
  void dispose() {
    _confettiTimer?.cancel();
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
                children: [
              const SizedBox(height: 16),

              // ── Progress indicator ("Exercise 2 of 3") ──────────────────
              if (widget.totalExercises != null && widget.totalExercises! > 1)
                Text(
                  'EXERCISE ${widget.exerciseIndex} OF ${widget.totalExercises}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),

              const Spacer(),

              // ── "Nice work" headline ─────────────────────────────────────
              const Text(
                'Nice work! 🎉',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: PCColors.yellow,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.exerciseName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PCColors.yellow,
                ),
              ),

              const SizedBox(height: 28),

              // ── Animated exercise streak ──────────────────────────────────
              ScaleTransition(
                scale: _scale,
                child: Column(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.dayStreak}-Day Streak',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.exerciseName} streak',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Overall streak badge ───────────────────────────────────────
              if (widget.overallStreak > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: PCColors.yellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PCColors.yellow.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.overallStreak}-Day Overall Streak',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Stats row: today's reps + lifetime total ────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'TODAY',
                      value: '${widget.todayReps}',
                      sub: widget.unit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'LIFETIME',
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
                    shadowColor: (isLast ? PCColors.yellow : PCColors.green).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: PCColors.brown, width: 1.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLast ? 'Finish & Summary' : 'Next Exercise',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 6),
                      Icon(isLast ? Icons.flag_rounded : Icons.list_rounded, size: 20),
                    ],
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
                Colors.purple
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
      path.lineTo(halfWidth + externalRadius * math.cos(step),
          halfWidth + externalRadius * math.sin(step));
      path.lineTo(halfWidth + internalRadius * math.cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * math.sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
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
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: highlight ? PCColors.yellow.withValues(alpha: 0.2) : context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? PCColors.yellow.withValues(alpha: 0.6) : context.borderColor,
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
              fontSize: 30,
              fontWeight: FontWeight.w900,
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
