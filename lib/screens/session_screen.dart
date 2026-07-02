import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../app_settings.dart';
import '../models/session_item.dart';
import 'reps_count_screen.dart';
import '../services/ad_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'premium_upgrade_screen.dart';
import '../models/exercise_item.dart';
import '../models/exercise_icons.dart';
import 'dart:math';

/// Shown after the 3-2-1 countdown finishes. The user is "in session":
/// a stopwatch runs, tips rotate, and Stop ends the session and moves
/// to rep entry.
class ActiveSessionScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String? backgroundImageUrl;
  final String unit; // e.g. "reps", "seconds"
  final ExerciseItem? exerciseDef;
  final int challengeSeconds;
  final int streak;
  final int lifetimeTotal;
  final int defaultReps;
  final List<SessionItem>? sessionQueue;
  final int? exerciseIndex;
  final int? totalExercises;

  const ActiveSessionScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.backgroundImageUrl,
    this.unit = 'reps',
    this.exerciseDef,
    required this.challengeSeconds,
    required this.streak,
    required this.lifetimeTotal,
    required this.defaultReps,
    this.sessionQueue,
    this.exerciseIndex,
    this.totalExercises,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  // ── Countdown/Stopwatch Timer ────────────────────────────────────────────
  Timer? _tickTimer;
  late int _seconds;
  late final AudioPlayer _player;

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
  
  bool _showAdOverlay = false;
  int _adSkipCountdown = 5;
  Timer? _adSkipTimer;
  bool _canSkip = false;
  bool _isAdLoadingStarted = false;
  late final String _randomSessionImage;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    
    final images = [
      'assets/images/screen1.png',
      'assets/images/screen2.png',
      'assets/images/screen3.png',
      'assets/images/screen4.png',
      'assets/images/screen5.png',
      'assets/images/screen6.png',
      'assets/images/screen7.png',
      'assets/images/screen8.png',
      'assets/images/screen9.png',
      'assets/images/screen10.png',
    ];
    _randomSessionImage = images[Random().nextInt(images.length)];
    
    _startSession();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAdLoadingStarted) {
      _isAdLoadingStarted = true;
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final size = MediaQuery.of(context).size;
    final maxWidth = size.width.truncate();
    final maxHeight = (size.height - 200).truncate().clamp(50, size.height.truncate());

    AdSize adSize = AdSize.getInlineAdaptiveBannerAdSize(maxWidth, maxHeight);

    AdService.instance.loadSessionAd(size: adSize, onLoaded: () {
      if (mounted) setState(() {});
    });
  }

  void _startAdCountdown() {
    _adSkipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_adSkipCountdown > 1) {
          _adSkipCountdown--;
        } else {
          _canSkip = true;
          timer.cancel();
        }
      });
    });
  }

  void _skipAd() {
    if (!_canSkip) return;
    setState(() {
      _showAdOverlay = false;
    });
    AdService.instance.disposeSessionAd();
  }

  Future<void> _playTick() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/tick.mp3'));
    } catch (_) {}
  }

  Future<void> _playStop() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/stop.mp3'));
    } catch (_) {}
  }

  void _startSession() {
    _seconds = widget.challengeSeconds;
    int elapsed = 0;

    // Update displayed time every second.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsed++;
      if (elapsed == 5 && !AdService.instance.isPremium) {
        setState(() {
          _showAdOverlay = true;
        });
        _startAdCountdown();
      }

      if (widget.challengeSeconds > 0) {
        if (_seconds > 0) {
          setState(() => _seconds--);
          if (!_showAdOverlay) _playTick();
        } else {
          _stopSession();
        }
      } else {
        setState(() => _seconds++);
        if (!_showAdOverlay) _playTick();
      }
    });

    // Rotate tips every 5 seconds.
    _tipTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  void _stopSession() async {
    _tickTimer?.cancel();
    _tipTimer?.cancel();
    
    await _playStop();
    await Future.delayed(const Duration(milliseconds: 200));

    final secondsCompleted = widget.challengeSeconds > 0 
        ? widget.challengeSeconds - _seconds 
        : _seconds;
        
    final todayAmount = widget.unit.toLowerCase() == 'seconds' || widget.unit.toLowerCase() == 'time' 
        ? secondsCompleted 
        : widget.defaultReps;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RepEntryScreen(
          exerciseId: widget.exerciseId,
          exerciseName: widget.exerciseName,
          unit: widget.unit,
          exerciseDef: widget.exerciseDef,
          defaultReps: todayAmount,
          sessionQueue: widget.sessionQueue,
          exerciseIndex: widget.exerciseIndex,
          totalExercises: widget.totalExercises,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tipTimer?.cancel();
    _adSkipTimer?.cancel();
    _player.dispose();
    AdService.instance.disposeSessionAd();
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
          Image.asset(
            _randomSessionImage,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [PCColors.brown, PCColors.brownDark],
                ),
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
                
                if (widget.exerciseDef != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: buildExerciseVisual(widget.exerciseDef!, size: 64, iconColor: Colors.white),
                  ),

                const Spacer(),

                // Big timer
                Text(
                  _formatRemaining(_seconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.challengeSeconds > 0 ? 'TIME REMAINING' : 'TIME ELAPSED',
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
          
          // ── Ad Overlay ────────────────────────────────────────────────
          if (_showAdOverlay)
            Container(
              color: PCColors.brownDark,
              child: SafeArea(
                child: Column(
                  children: [
                    // Header with Remove Ads button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ad Break',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.star, color: PCColors.yellow, size: 16),
                            label: const Text(
                              'REMOVE ADS',
                              style: TextStyle(
                                color: PCColors.yellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const PremiumUpgradeScreen()),
                              ).then((_) {
                                if (mounted && AdService.instance.isPremium) {
                                  _canSkip = true;
                                  _skipAd();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),


                    // Ad Space
                    Expanded(
                      child: Center(
                        child: AdService.instance.sessionAd != null
                            ? SizedBox(
                                width: AdService.instance.sessionAd!.size.width.toDouble(),
                                height: AdService.instance.sessionAd!.size.height.toDouble(),
                                child: AdWidget(ad: AdService.instance.sessionAd!),
                              )
                            : const CircularProgressIndicator(color: PCColors.yellow),
                      ),
                    ),

                    // Skip Button
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _canSkip ? _skipAd : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canSkip ? Colors.white : Colors.white24,
                            foregroundColor: _canSkip ? Colors.black : Colors.white54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _canSkip ? 'SKIP' : 'SKIP IN $_adSkipCountdown...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
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
    );
  }
}