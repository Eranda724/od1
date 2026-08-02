import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/streak_service.dart';
import '../services/notification_service.dart';
import '../services/friends_service.dart';
import '../app_settings.dart';
import '../models/session_item.dart';
import 'celebration_screen.dart';
import 'exercise_start_screen.dart';
import 'daily_summary_screen.dart';
import '../models/exercise_item.dart';
import '../models/exercise_icons.dart';
import 'package:easy_localization/easy_localization.dart';

/// Shown right after the user hits Stop on an exercise session.
/// Lets them enter how many reps they completed, then saves to Firestore
/// (updating streak + lifetime total) and moves on to the Congratulation screen.
class RepEntryScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String unit; // e.g. "reps"
  final ExerciseItem? exerciseDef;
  final int defaultReps; // pre-fill suggestion (e.g. admin default or last entry)

  /// Optional — pass these through if you're tracking a multi-exercise session.
  final int? exerciseIndex;
  final int? totalExercises;
  final List<SessionItem>? sessionQueue;

  /// Called once the Firestore update succeeds and Congratulation screen
  /// is about to be shown — gives the caller a hook to advance its own
  /// session state if needed. Usually you can leave this null.
  final VoidCallback? onSaved;

  const RepEntryScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.unit = 'reps',
    this.exerciseDef,
    this.defaultReps = 10,
    this.exerciseIndex,
    this.totalExercises,
    this.sessionQueue,
    this.onSaved,
  });

  @override
  State<RepEntryScreen> createState() => _RepEntryScreenState();
}

class _RepEntryScreenState extends State<RepEntryScreen> {
  late int _reps;
  bool _isSaving = false;
  String? _error;

  final TextEditingController _controller = TextEditingController();
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _reps = widget.defaultReps;
    _controller.text = _reps.toString();
    _player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  }

  @override
  void dispose() {
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playClick() async {
    try {
      HapticFeedback.lightImpact();
      await _player.stop();
      await _player.setVolume(0.3); // Low-medium volume
      await _player.play(AssetSource('sounds/click.mp3'));
    } catch (e) {
      debugPrint('Error playing click sound: $e');
    }
  }

  void _changeReps(int delta) {
    _playClick();
    final next = (_reps + delta).clamp(0, 9999);
    setState(() {
      _reps = next;
      _controller.text = next.toString();
    });
  }

  // Removed unused key functions since they moved to service

  Future<void> _goToNextOrSummary(BuildContext navContext) async {
    final queue = widget.sessionQueue;
    if (queue != null && queue.isNotEmpty) {
      final next = queue.first;
      final tail = queue.skip(1).toList();
      Navigator.of(navContext).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExerciseStartScreen(
            exerciseId: next.exerciseId,
            exerciseName: next.exerciseName,
            description: next.description,
            streak: next.streak,
            lifetimeTotal: next.lifetimeTotal,
            defaultReps: next.defaultReps,
            defaultTimer: next.defaultTimer,
            unit: next.unit,
            exerciseDef: next.exerciseDef,
            sessionQueue: tail,
            exerciseIndex: (widget.exerciseIndex ?? 1) + 1,
            totalExercises: widget.totalExercises,
          ),
        ),
      );
    } else {
      // Proceed to summary
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final overallStreak = userDoc.data()?['overallStreak'] ?? 0;
        
        final exSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('exercises').get();
        final now = DateTime.now();
        final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        
        List<ExerciseDaySummary> summaryList = [];
        for (var doc in exSnap.docs) {
          final data = doc.data();
          if (data['lastCompletedDate'] == todayKey) {
             summaryList.add(ExerciseDaySummary(
                exerciseName: data['exerciseName'] ?? doc.id,
                unit: widget.unit, // Assuming similar units or using the last one
                todayReps: data['todayReps'] ?? 0,
                currentStreak: data['currentStreak'] ?? 0,
                lifetimeTotal: data['lifetimeTotal'] ?? 0,
             ));
          }
        }
        
        if (!navContext.mounted) return;
        Navigator.of(navContext).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DailySummaryScreen(
               completedExercises: summaryList,
               overallStreak: overallStreak,
            ),
          ),
        );
      } catch (e) {
        // Fallback
        if (!navContext.mounted) return;
        Navigator.of(navContext).popUntil((route) => route.isFirst);
      }
    }
  }

  /// Calls StreakService to update user + exercise stats, then navigates
  /// to the Congratulation screen.
  Future<void> _submit() async {
    if (_reps <= 0) {
      setState(() => _error = 'enter_at_least_1'.tr(args: [widget.unit]));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'not_signed_in_save'.tr());
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final result = await StreakService.logExercise(
        uid: user.uid,
        exerciseId: widget.exerciseId,
        exerciseName: widget.exerciseName,
        reps: _reps,
      );

      // overallStreak is now computed atomically inside logExercise().

      if (!mounted) return;

      // Cancel the evening streak-saver notification — user worked out today!
      // (Fire and forget, no need to await and block the UI)
      NotificationService.instance.cancelTodayEveningReminder();

      // Trigger Social/Friend updates asynchronously
      FriendsService.instance.recordExerciseDone(user.uid);


      if (!mounted) return;

      widget.onSaved?.call();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CelebrationScreen(
            exerciseName: widget.exerciseName,
            dayStreak: result['currentStreak']!,
            todayReps: result['todayReps']!,
            lifetimeTotal: result['lifetimeTotal']!,
            overallStreak: result['overallStreak']!,
            unit: widget.unit,
            exerciseIndex: widget.exerciseIndex,
            totalExercises: widget.totalExercises,
            onContinue: (navContext) {
              _goToNextOrSummary(navContext);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'error_saving'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              Text(
                widget.exerciseName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              if (widget.exerciseDef != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: buildExerciseVisual(widget.exerciseDef!, size: 48),
                ),
              const SizedBox(height: 8),
              Text(
                'how_many_completed'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                ),
              ),

              const SizedBox(height: 36),

              // ── Big numeric input with +/- ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundIconButton(
                    icon: Icons.remove_rounded,
                    onTap: () => _changeReps(-1),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.cardColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: context.borderColor, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: context.borderColor, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: PCColors.yellow, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        setState(() {
                          _reps = parsed ?? 0;
                          _error = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  _RoundIconButton(
                    icon: Icons.add_rounded,
                    onTap: () => _changeReps(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.unit,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                  letterSpacing: 1,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ],

              const Spacer(flex: 2),

              // ── Submit button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PCColors.green,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: PCColors.green.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: PCColors.brown, width: 1.5),
                    ),
                    disabledBackgroundColor: PCColors.green.withValues(alpha: 0.5),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'submit_btn'.tr(),
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.cardColor,
          border: Border.all(color: context.borderColor, width: 1.5),
        ),
        child: Icon(icon, color: context.textPrimary, size: 24),
      ),
    );
  }
}
