import 'dart:async';
import 'package:flutter/material.dart';
import '../app_settings.dart';
// import 'rep_entry_screen.dart'; // ← point this at your actual rep entry screen

/// Shown after the 3-2-1 countdown finishes. The user is "in session":
/// a stopwatch runs, tips rotate, and Stop ends the session and moves
/// to rep entry.
class ActiveSessionScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String? backgroundImageUrl;
  final String unit; // e.g. "reps", "seconds"
  final int challengeSeconds;

  const ActiveSessionScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.backgroundImageUrl,
    this.unit = 'reps',
    required this.challengeSeconds,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  // ── Countdown Timer ──────────────────────────────────────────────────────
  Timer? _tickTimer;
  late int _remainingSeconds;

  // ── Rotating tips ────────────────────────────────────────────────────────
  // Swap this list for your real "during-session" message bank later —
  // same rotation mechanism, just a different content source.
  static const List<String> _tips = [
    "🥔 Your couch will still be there when you're done.",
    "💪 60 seconds. Less than a TikTok scroll.",
    "🔥 Future you is already proud of this one.",
    "😅 No one's watching. Except your streak.",
    "🥔 Small reps, big habit.",
    "💪 You showed up. That's the hard part.",
    "🔥 Consistency beats intensity. Keep going.",
  ];
  int _tipIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  void _startSession() {
    _remainingSeconds = widget.challengeSeconds;

    // Update displayed remaining time every second.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _stopSession();
      }
    });

    // Rotate tips every 5 seconds.
    _tipTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  void _stopSession() {
    _tickTimer?.cancel();
    _tipTimer?.cancel();

    final secondsCompleted = widget.challengeSeconds - _remainingSeconds;

    // TODO: replace with your actual rep-entry screen/route.
    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(
    //     builder: (_) => RepEntryScreen(
    //       exerciseId: widget.exerciseId,
    //       exerciseName: widget.exerciseName,
    //       secondsElapsed: secondsCompleted,
    //       unit: widget.unit,
    //     ),
    //   ),
    // );

    // Placeholder so this file compiles stand-alone — remove once wired up.
    Navigator.of(context).pop(secondsCompleted);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tipTimer?.cancel();
    super.dispose();
  }

  String _formatRemaining(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PCColors.brownDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image ──────────────────────────────────────────
          if (widget.backgroundImageUrl != null)
            Image.network(
              widget.backgroundImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: PCColors.brownDark),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [PCColors.brown, PCColors.brownDark],
                ),
              ),
            ),

          // ── Dark scrim for text legibility ────────────────────────────
          Container(color: Colors.black.withValues(alpha: 0.45)),

          // ── Foreground content ────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Exercise name
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    widget.exerciseName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const Spacer(),

                // Big remaining timer
                Text(
                  _formatRemaining(_remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TIME REMAINING',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 32),

                // Rotating tip — styled as a prominent tip card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: PCColors.yellow.withValues(alpha: 0.3), width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, color: PCColors.yellow, size: 22),
                            const SizedBox(width: 8),
                            Text('QUICK TIP', style: TextStyle(
                              color: PCColors.yellow.withValues(alpha: 0.9), 
                              fontWeight: FontWeight.w800, 
                              letterSpacing: 1.5,
                              fontSize: 14,
                            )),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                          child: Text(
                            _tips[_tipIndex],
                            key: ValueKey(_tipIndex),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Stop button
                Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: InkWell(
                    onTap: _stopSession,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Only non-PCColors color in this file — a clear
                        // "stop" red. Swap for PCColors.brown if you want
                        // to stay strictly on-palette.
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE25C5C), Color(0xFFB23A3A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB23A3A).withValues(alpha: 0.5),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'STOP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}