import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'congradulation_screen.dart';
import '../app_settings.dart';
import 'package:easy_localization/easy_localization.dart';

/// Shown immediately after the Firestore save in RepEntryScreen.
/// Plays a celebration sound, shows a random potato image, then
/// auto-advances (or advances on tap) to CongratulationScreen.
class CelebrationScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final int dayStreak;
  final int todayReps;
  final int monthlyTotal;
  final int overallStreak;
  final String unit;
  final int? exerciseIndex;
  final int? totalExercises;
  final void Function(BuildContext) onContinue;

  const CelebrationScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.dayStreak,
    required this.todayReps,
    required this.monthlyTotal,
    this.overallStreak = 0,
    this.unit = 'reps',
    this.exerciseIndex,
    this.totalExercises,
    required this.onContinue,
  });

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with SingleTickerProviderStateMixin {
  // ── Image pool ────────────────────────────────────────────────────────────
  static const _images = [
    'assets/images/po1.png',
    'assets/images/po2.png',
    'assets/images/po3.png',
    'assets/images/bascket.png',
    'assets/images/bicy.png',
    'assets/images/dance.png',
    'assets/images/foot.png',
    'assets/images/jump.png',
    'assets/images/plank.png',
    'assets/images/put.png',
    'assets/images/tennis.png',
    'assets/images/weight.png',
  ];

  // ── Fun messages ──────────────────────────────────────────────────────────
  static const _messageKeys = [
    'crushed_it',
    'potato_power',
    'keep_it_up',
    'amazing_work',
    'on_fire',
    'thats_the_way',
    'killing_it',
  ];

  late final String _image;
  late final String _messageKey;
  late final AudioPlayer _player;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;
  Timer? _autoTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    final rng = Random();
    _image = _images[rng.nextInt(_images.length)];
    _messageKey = _messageKeys[rng.nextInt(_messageKeys.length)];

    // ── Scale-in animation ───────────────────────────────────────────────
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.1).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_scaleCtrl);
    _scaleCtrl.forward();

    // ── Sound ────────────────────────────────────────────────────────────
    _player = AudioPlayer();
    _playSound();

    // ── Auto-advance after 2.5 s ─────────────────────────────────────────
    _autoTimer = Timer(const Duration(milliseconds: 5000), _advance);
  }

  Future<void> _playSound() async {
    try {
      await _player.play(AssetSource('sounds/celebrate.mp3'));
    } catch (_) {
      // Sound failure is non-critical — silently ignore
    }
  }

  void _advance() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _autoTimer?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CongratulationScreen(
          exerciseId: widget.exerciseId,
          exerciseName: widget.exerciseName,
          dayStreak: widget.dayStreak,
          todayReps: widget.todayReps,
          monthlyTotal: widget.monthlyTotal,
          unit: widget.unit,
          exerciseIndex: widget.exerciseIndex,
          totalExercises: widget.totalExercises,
          onContinue: widget.onContinue,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _scaleCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _advance,
      child: Scaffold(
        backgroundColor: PCColors.yellow,
        body: SafeArea(
          child: Column(
            children: [
              // ── Tap to skip hint ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 16, right: 20),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    'tap_to_skip'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PCColors.brownDark,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // ── Animated potato image ──────────────────────────────────
              ScaleTransition(
                scale: _scale,
                child: Image.asset(
                  _image,
                  height: 260,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 28),

              // ── Fun message ────────────────────────────────────────────
              Text(
                _messageKey.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: PCColors.brownDark,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                widget.exerciseName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PCColors.brownDark.withValues(alpha: 0.6),
                ),
              ),

              const Spacer(flex: 2),

              // ── Progress dots ──────────────────────────────────────────
              _AutoProgressBar(durationMs: 5000),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin animated progress bar that fills over the auto-advance duration
// ─────────────────────────────────────────────────────────────────────────────
class _AutoProgressBar extends StatefulWidget {
  final int durationMs;
  const _AutoProgressBar({required this.durationMs});

  @override
  State<_AutoProgressBar> createState() => _AutoProgressBarState();
}

class _AutoProgressBarState extends State<_AutoProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) => LinearProgressIndicator(
          value: _ctrl.value,
          backgroundColor: PCColors.brownDark.withValues(alpha: 0.15),
          valueColor: const AlwaysStoppedAnimation<Color>(PCColors.brownDark),
          borderRadius: BorderRadius.circular(4),
          minHeight: 5,
        ),
      ),
    );
  }
}
