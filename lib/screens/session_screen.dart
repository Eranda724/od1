import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../app_settings.dart';
import '../models/session_item.dart';
import 'reps_count_screen.dart';
import '../widgets/notification_bell.dart';
import '../services/ad_service.dart';
import '../models/exercise_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/exercise_icons.dart';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin/admin_assets_screen.dart';

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
  final int monthlyTotal;
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
    required this.monthlyTotal,
    required this.defaultReps,
    this.sessionQueue,
    this.exerciseIndex,
    this.totalExercises,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  // Countdown/Stopwatch Timer
  Timer? _tickTimer;
  late int _seconds;
  late final AudioPlayer _player;

  // Rotating tips
  List<Map<String, dynamic>> _activeTips = [];
  int _tipIndex = 0;
  Timer? _tipTimer;

  DateTime? _sessionStartTime;
  bool _adTriggered = false;
  bool _isAdPlaying = false;

  bool _showAdOverlay = false;
  int _adSkipCountdown = 5;
  Timer? _adSkipTimer;

  String? _randomSessionImage;
  bool _isAssetImage = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

    _loadAssetsAndStart();
  }

  Future<void> _loadAssetsAndStart() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('session_assets')
          .get();
      final data = doc.data() ?? {};

      final rawImages = data['images'] as List<dynamic>? ?? [];
      final rawTips = data['tips'] as List<dynamic>? ?? kDefaultSessionTips;

      final enabledImages = rawImages
          .where((i) => i['enabled'] == true && i['isAsset'] != true)
          .toList();
      final enabledTips = rawTips
          .where((t) => t['enabled'] == true)
          .map((t) => t as Map<String, dynamic>)
          .toList();

      if (enabledImages.isNotEmpty) {
        final img = enabledImages[Random().nextInt(enabledImages.length)];
        _randomSessionImage = img['url'];
        _isAssetImage = img['isAsset'] == true;
      } else {
        _randomSessionImage = null; // Use gradient
      }

      if (enabledTips.isNotEmpty) {
        _activeTips = enabledTips;
      }
    } catch (e) {
      // Fallback
      _activeTips = kDefaultSessionTips;
      _randomSessionImage = null;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _startSession();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AdService.instance.loadInterstitialAd();
  }

  void _startAdCountdown() {
    _adSkipCountdown = 3;
    _adSkipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_adSkipCountdown > 1) {
          _adSkipCountdown--;
        } else {
          timer.cancel();
          _isAdPlaying = true;
          AdService.instance.showInterstitialAd(
            onAdDismissed: () {
              if (!mounted) return;
              setState(() {
                _isAdPlaying = false;
                _showAdOverlay = false;
              });
            },
          );
        }
      });
    });
  }

  Future<void> _playTick() async {
    // Tick sound removed per client request
  }

  Future<void> _playStop() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/stop.mp3'));
    } catch (_) {}
  }

  void _startSession() {
    _sessionStartTime = DateTime.now();
    _seconds = widget.challengeSeconds;

    // Update displayed time every second.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sessionStartTime == null) return;

      final elapsedSeconds = DateTime.now()
          .difference(_sessionStartTime!)
          .inSeconds;

      if (elapsedSeconds >= 2 &&
          !_adTriggered &&
          !AdService.instance.isPremium) {
        _adTriggered = true;
        setState(() {
          _showAdOverlay = true;
        });
        _startAdCountdown();
      }

      if (widget.challengeSeconds > 0) {
        final remaining = widget.challengeSeconds - elapsedSeconds;
        if (remaining > 0) {
          setState(() => _seconds = remaining);
          if (!_isAdPlaying) _playTick();
        } else {
          setState(() => _seconds = 0);
          _stopSession();
        }
      } else {
        setState(() => _seconds = elapsedSeconds);
        if (!_isAdPlaying) _playTick();
      }
    });

    // Rotate tips every 5 seconds.
    _tipTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_activeTips.isNotEmpty) {
        setState(() => _tipIndex = (_tipIndex + 1) % _activeTips.length);
      }
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

    final todayAmount =
        widget.unit.toLowerCase() == 'seconds' ||
            widget.unit.toLowerCase() == 'time'
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
          actualSecondsSpent: secondsCompleted,
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
    super.dispose();
  }

  String _formatRemaining(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: PCColors.brownDark,
        body: Center(child: CircularProgressIndicator(color: PCColors.yellow)),
      );
    }

    final textColor = _randomSessionImage == null
        ? Colors.black87
        : Colors.white;

    return Scaffold(
      backgroundColor: PCColors.brownDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient (Default)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [PCColors.yellow, PCColors.yellowDark],
              ),
            ),
          ),
          // Background image (Admin Override)
          if (_randomSessionImage != null)
            _isAssetImage
                ? Image.asset(
                    _randomSessionImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  )
                : CachedNetworkImage(
                    imageUrl: _randomSessionImage!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        const SizedBox.shrink(),
                  ),

          // Dark scrim for text legibility (Only for image)
          if (_randomSessionImage != null)
            Container(color: Colors.black.withValues(alpha: 0.45)),

          // Foreground content
          SafeArea(
            child: Column(
              children: [
                // Header (Back arrow and Bell)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: textColor),
                        onPressed: _stopSession,
                      ),
                      NotificationBell(iconColor: textColor),
                    ],
                  ),
                ),

                // Tips Text
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'quick_tip'.tr().toUpperCase(),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: const Interval(
                              0.5,
                              1.0,
                              curve: Curves.easeIn,
                            ),
                          ),
                          child: child,
                        ),
                        child: Text(
                          _activeTips.isNotEmpty
                              ? (_activeTips[_tipIndex]['isKey'] == true
                                    ? (_activeTips[_tipIndex]['text'] as String)
                                          .tr()
                                    : _activeTips[_tipIndex]['text'] as String)
                              : '',
                          key: ValueKey(_tipIndex),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Exercise name
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.exerciseName.toUpperCase(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                if (widget.exerciseDef != null &&
                    widget.exerciseDef!.mediaItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: buildExerciseVisual(
                      widget.exerciseDef!,
                      size: 48,
                      iconColor: textColor,
                    ),
                  ),

                const Spacer(),

                // Big timer with Progress Ring
                SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: widget.challengeSeconds > 0
                            ? (_seconds / widget.challengeSeconds)
                            : ((_seconds % 60) / 60.0),
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        color: Colors.white,
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatRemaining(_seconds),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.challengeSeconds > 0
                                ? 'time_remaining'.tr()
                                : 'time_elapsed'.tr(),
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Stop button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 48,
                  ),
                  child: InkWell(
                    onTap: _stopSession,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE25C5C),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(
                              0xFFB23A3A,
                            ), // Darker red for 3D effect
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
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'stop_btn'.tr().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Pre-Ad Popup Overlay
          if (_showAdOverlay)
            Align(
              alignment: const Alignment(-1.0, -0.1),
              child: Container(
                margin: const EdgeInsets.only(left: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        'Ad in $_adSkipCountdown',
                        key: ValueKey(_adSkipCountdown),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
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
