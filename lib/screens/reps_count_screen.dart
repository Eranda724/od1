import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/streak_service.dart';
import '../app_settings.dart';
import 'celebration_screen.dart';

/// Shown right after the user hits Stop on an exercise session.
/// Lets them enter how many reps they completed, then saves to Firestore
/// (updating streak + lifetime total) and moves on to the Congratulation screen.
class RepEntryScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String unit; // e.g. "reps"
  final int defaultReps; // pre-fill suggestion (e.g. admin default or last entry)

  /// Optional — pass these through if you're tracking a multi-exercise session.
  final int? exerciseIndex;
  final int? totalExercises;

  /// Called once the Firestore update succeeds and Congratulation screen
  /// is about to be shown — gives the caller a hook to advance its own
  /// session state if needed. Usually you can leave this null.
  final VoidCallback? onSaved;

  const RepEntryScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.unit = 'reps',
    this.defaultReps = 10,
    this.exerciseIndex,
    this.totalExercises,
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

  @override
  void initState() {
    super.initState();
    _reps = widget.defaultReps;
    _controller.text = _reps.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeReps(int delta) {
    final next = (_reps + delta).clamp(0, 9999);
    setState(() {
      _reps = next;
      _controller.text = next.toString();
    });
  }

  // Removed unused key functions since they moved to service

  /// Calls StreakService to update user + exercise stats, then navigates
  /// to the Congratulation screen.
  Future<void> _submit() async {
    if (_reps <= 0) {
      setState(() => _error = 'Enter at least 1 ${widget.unit}.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'You need to be signed in to save this.');
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
              Navigator.of(navContext).popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = "Couldn't save — check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PCColors.cream,
      appBar: AppBar(
        backgroundColor: PCColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: PCColors.brownDark),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PCColors.brown,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'How many did you complete?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: PCColors.brownDark,
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
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: PCColors.brownDark,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: PCColors.brown, width: 2),
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
                  color: PCColors.brown.withValues(alpha: 0.7),
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
                      : const Text(
                          'Submit',
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
          color: Colors.white,
          border: Border.all(color: PCColors.brown, width: 1.5),
        ),
        child: Icon(icon, color: PCColors.brownDark, size: 24),
      ),
    );
  }
}
