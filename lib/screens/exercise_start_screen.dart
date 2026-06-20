import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../app_settings.dart';
import '../models/exercise_item.dart';
import 'session_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared sizing tokens (no color changes — just reusing PCColors consistently)
// ─────────────────────────────────────────────────────────────────────────────
class _ControlStyle {
  static const double cardRadius = 14;

  static const TextStyle smallLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: PCColors.brown,
    letterSpacing: 0.8,
  );

  // One subtle border used by every secondary/content card
  // (description box, rep box, timer box, ready-time dropdown).
  static Border subtleBorder() =>
      Border.all(color: PCColors.brown.withValues(alpha: 0.3), width: 1.5);

  // One bold border used by hero/emphasis elements (stats bar, popups, dialogs).
  static Border boldBorder() => Border.all(color: PCColors.brown, width: 1.5);
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class ExerciseStartScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String? description;
  final int streak;
  final int lifetimeTotal;
  final int defaultReps;
  final int defaultTimer;
  final String unit;

  /// All media assets for this exercise (images + videos).
  /// If empty the screen shows a placeholder.
  final List<ExerciseMedia> mediaItems;

  const ExerciseStartScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.description,
    required this.streak,
    required this.lifetimeTotal,
    this.defaultReps = 10,
    this.defaultTimer = 30,
    this.unit = 'reps',
    this.mediaItems = const [],
  });

  @override
  State<ExerciseStartScreen> createState() => _ExerciseStartScreenState();
}

class _ExerciseStartScreenState extends State<ExerciseStartScreen> {
  // ── Active media index ─────────────────────────────────────────────────────
  int _activeIndex = 0;

  // ── Video controllers & Slideshow ──────────────────────────────────────────
  final Map<int, VideoPlayerController> _videoControllers = {};
  Timer? _slideshowTimer;

  // ── Ready Time ─────────────────────────────────────────────────────────────
  bool _wantsReadyTime = false;
  int _readyTimeSeconds = 3;
  final GlobalKey _timerKey = GlobalKey();

  // ── 3-2-1 countdown ────────────────────────────────────────────────────────
  bool _isCountingDown = false;
  int _currentCount = 0;
  Timer? _countdownTimer;
  // Logic moved to countdown_screen.dart

  @override
  void initState() {
    super.initState();
    _loadSavedPrefs();
    _initVideoAt(0); // pre-load first item if it's a video
    _scheduleSlideshowForCurrentMedia();
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _loadSavedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getInt('readyTime_${widget.exerciseId}');
    final wantsTime = prefs.getBool('wantsReadyTime_${widget.exerciseId}');
    if (mounted) {
      setState(() {
        if (savedTime != null) _readyTimeSeconds = savedTime;
        if (wantsTime != null) _wantsReadyTime = wantsTime;
      });
    }
  }

  Future<void> _saveTime(int t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('readyTime_${widget.exerciseId}', t);
  }

  Future<void> _saveWantsReadyTime(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wantsReadyTime_${widget.exerciseId}', v);
  }

  // ── Video management & Slideshow ───────────────────────────────────────────
  void _scheduleSlideshowForCurrentMedia() {
    _slideshowTimer?.cancel();
    if (widget.mediaItems.isEmpty || widget.mediaItems.length == 1) return;

    final item = widget.mediaItems[_activeIndex];
    if (!item.isVideo) {
      // It's an image, wait 3 seconds then go to next
      _slideshowTimer = Timer(const Duration(seconds: 3), _nextMedia);
    } else {
      // It's a video. We handle the transition in the video listener below,
      // but if the video is already finished, schedule it here.
      final ctrl = _videoControllers[_activeIndex];
      if (ctrl != null && ctrl.value.isInitialized) {
        if (ctrl.value.position >= ctrl.value.duration && ctrl.value.duration != Duration.zero) {
          _slideshowTimer = Timer(const Duration(seconds: 3), _nextMedia);
        }
      }
    }
  }

  void _nextMedia() {
    if (!mounted || widget.mediaItems.isEmpty) return;
    final nextIndex = (_activeIndex + 1) % widget.mediaItems.length;
    _selectMedia(nextIndex);
  }

  void _initVideoAt(int index) {
    if (index >= widget.mediaItems.length) return;
    final item = widget.mediaItems[index];
    if (!item.isVideo) return;
    if (_videoControllers.containsKey(index)) return; // already init

    final ctrl = VideoPlayerController.networkUrl(Uri.parse(item.url));
    ctrl.initialize().then((_) {
      if (mounted) {
        setState(() {});
        if (index == _activeIndex) _scheduleSlideshowForCurrentMedia();
      }
      ctrl.play();
    });

    ctrl.addListener(() {
      if (ctrl.value.position >= ctrl.value.duration &&
          ctrl.value.duration != Duration.zero) {
        // Video finished. Pause it and start 3s timer to switch.
        ctrl.pause();
        if (index == _activeIndex && (_slideshowTimer == null || !_slideshowTimer!.isActive)) {
          _slideshowTimer = Timer(const Duration(seconds: 3), _nextMedia);
        }
      }
    });

    _videoControllers[index] = ctrl;
  }

  void _selectMedia(int index) {
    if (index == _activeIndex) return;
    _slideshowTimer?.cancel();

    // Pause the previous video if any
    _videoControllers[_activeIndex]?.pause();
    setState(() {
      _activeIndex = index;
    });

    // Init & play the new one
    _initVideoAt(index);
    final ctrl = _videoControllers[index];
    if (ctrl != null) {
      ctrl.seekTo(Duration.zero);
      ctrl.play();
    }

    _scheduleSlideshowForCurrentMedia();
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _countdownTimer?.cancel();
    for (final ctrl in _videoControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Countdown ──────────────────────────────────────────────────────────────
  void _startCountdown() {
    if (_isCountingDown) return; // already counting

    _slideshowTimer?.cancel();
    for (final ctrl in _videoControllers.values) {
      ctrl.pause();
    }

    String? bgUrl;
    try {
      bgUrl = widget.mediaItems.firstWhere((m) => !m.isVideo).url;
    } catch (_) {}

    void navigate() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(
            exerciseId: widget.exerciseId,
            exerciseName: widget.exerciseName,
            backgroundImageUrl: bgUrl,
            unit: widget.unit,
            challengeSeconds: widget.defaultTimer,
            streak: widget.streak,
            lifetimeTotal: widget.lifetimeTotal,
            defaultReps: widget.defaultReps,
          ),
        ),
      );
    }

    if (_wantsReadyTime && _readyTimeSeconds > 0) {
      setState(() {
        _isCountingDown = true;
        _currentCount = _readyTimeSeconds;
      });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _currentCount--;
        });
        if (_currentCount <= 0) {
          timer.cancel();
          navigate();
        }
      });
    } else {
      navigate();
    }
  }

  // ── Timer popup menu ───────────────────────────────────────────────────────
  void _showTimerMenu() async {
    final box = _timerKey.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    final result = await showMenu<int>(
      context: context,
      color: PCColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: PCColors.brown, width: 1.5),
      ),
      position: RelativeRect.fromLTRB(
        offset.dx, offset.dy + size.height + 6, offset.dx + size.width, 0,
      ),
      items: [
        for (final s in [3, 5, 10])
          PopupMenuItem<int>(
            value: s,
            height: 44,
            child: _TimerOption(seconds: s, selected: _readyTimeSeconds == s),
          ),
        PopupMenuItem<int>(
          value: -1,
          height: 44,
          child: _TimerOption(
            label: 'Custom…',
            icon: Icons.edit_rounded,
            selected: ![3, 5, 10].contains(_readyTimeSeconds),
          ),
        ),
      ],
    );

    if (!mounted || result == null) return;
    if (result == -1) {
      _showCustomTimeDialog();
    } else {
      setState(() => _readyTimeSeconds = result);
      _saveTime(result);
    }
  }

  void _showCustomTimeDialog() {
    final ctrl = TextEditingController(
      text: [3, 5, 10].contains(_readyTimeSeconds) ? '' : '$_readyTimeSeconds',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PCColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: PCColors.brown, width: 2),
        ),
        title: const Text('Ready Time',
            style: TextStyle(fontWeight: FontWeight.w900, color: PCColors.brownDark)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: PCColors.brownDark),
          decoration: InputDecoration(
            suffixText: 's',
            suffixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: PCColors.brown),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PCColors.brown, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: PCColors.brown))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PCColors.yellow, foregroundColor: PCColors.brownDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v > 0) { setState(() => _readyTimeSeconds = v); _saveTime(v); }
              Navigator.pop(ctx);
            },
            child: const Text('Set', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Main media display for [index].
  Widget _buildMainMedia(int index) {
    if (widget.mediaItems.isEmpty) {
      return _placeholder();
    }
    final item = widget.mediaItems[index];
    if (item.isVideo) {
      final ctrl = _videoControllers[index];
      if (ctrl != null && ctrl.value.isInitialized) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: ctrl.value.size.width,
                  height: ctrl.value.size.height,
                  child: VideoPlayer(ctrl),
                ),
              ),
            ),
            // Scrim
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Play/pause
            IconButton(
              icon: Icon(
                ctrl.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 56, color: Colors.white.withValues(alpha: 0.85),
              ),
              onPressed: () => setState(() {
                ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
                if (!ctrl.value.isPlaying) _slideshowTimer?.cancel();
              }),
            ),
          ],
        );
      }
      // Loading spinner while video initialises
      return Container(
        color: PCColors.brownDark.withValues(alpha: 0.1),
        child: const Center(child: CircularProgressIndicator(color: PCColors.yellow)),
      );
    }
    // Image
    return Image.network(item.url, fit: BoxFit.cover, width: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder());
  }

  Widget _placeholder() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [PCColors.yellow.withValues(alpha: 0.3), PCColors.cream],
      ),
    ),
    child: Center(child: Icon(Icons.fitness_center, size: 80,
        color: PCColors.brown.withValues(alpha: 0.35))),
  );

  /// Horizontal thumbnail strip — shown only when there are ≥ 2 media items.
  Widget _buildThumbnailStrip() {
    if (widget.mediaItems.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.mediaItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = widget.mediaItems[i];
          final active = i == _activeIndex;
          return GestureDetector(
            onTap: () => _selectMedia(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? PCColors.yellow : PCColors.brown.withValues(alpha: 0.35),
                  width: active ? 2.5 : 1.5,
                ),
                boxShadow: active
                    ? [BoxShadow(color: PCColors.yellow.withValues(alpha: 0.55),
                                 blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail background
                    item.isVideo
                        ? _videoThumbnail(i)
                        : Image.network(item.url, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _thumbnailPlaceholder(item.isVideo)),
                    // Video icon overlay
                    if (item.isVideo)
                      Center(
                        child: Icon(Icons.play_circle_rounded,
                            size: 24,
                            color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    // Active highlight overlay
                    if (active)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.5),
                          color: PCColors.yellow.withValues(alpha: 0.18),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// For a video thumbnail we show a dark placeholder with number badge
  Widget _videoThumbnail(int index) {
    final ctrl = _videoControllers[index];
    if (ctrl != null && ctrl.value.isInitialized) {
      // Show first frame via VideoPlayer (tiny)
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      );
    }
    return _thumbnailPlaceholder(true);
  }

  Widget _thumbnailPlaceholder(bool isVideo) => Container(
    color: PCColors.brownDark.withValues(alpha: 0.12),
    child: Center(
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.image_rounded,
        size: 22, color: PCColors.brown.withValues(alpha: 0.5),
      ),
    ),
  );

  Widget _buildRepCounter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.unit.toUpperCase(), style: _ControlStyle.smallLabel),
        const SizedBox(height: 6),
        Text('${widget.defaultReps}', style: const TextStyle(
            fontSize: 36, fontWeight: FontWeight.w900, color: PCColors.brownDark)),
      ],
    );
  }

  Widget _buildExerciseTimer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('TIMER', style: _ControlStyle.smallLabel),
        const SizedBox(height: 6),
        Text('${widget.defaultTimer}s', style: const TextStyle(
            fontSize: 36, fontWeight: FontWeight.w900, color: PCColors.brownDark)),
      ],
    );
  }

  // ── Ready Time widget ──────────────────────────────────────────────────────
  Widget _buildReadyTimeWidget() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        // Checkbox
        Checkbox(
          value: _wantsReadyTime,
          activeColor: PCColors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: PCColors.brown, width: 1.5),
          onChanged: (val) {
            if (val != null) {
              setState(() => _wantsReadyTime = val);
              _saveWantsReadyTime(val);
            }
          },
        ),
        Text('Ready time(${_readyTimeSeconds}s)', style: const TextStyle(
            fontWeight: FontWeight.w800, color: PCColors.brownDark, fontSize: 13)),
        const SizedBox(width: 8),
        // Dropdown — same subtle border style as rep/timer boxes
        if (_wantsReadyTime)
          GestureDetector(
            key: _timerKey,
            onTap: _showTimerMenu,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_ControlStyle.cardRadius),
                border: _ControlStyle.subtleBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${_readyTimeSeconds}s', style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: PCColors.brownDark)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down_rounded, size: 20, color: PCColors.brown),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PCColors.cream,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: PCColors.yellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: PCColors.brownDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: PCColors.brownDark),
            onPressed: () {},
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: h),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Exercise name
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Text(
                        widget.exerciseName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          letterSpacing: 1.5, color: PCColors.brownDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Main media
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        height: h * 0.32,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_ControlStyle.cardRadius + 10),
                          child: _buildMainMedia(_activeIndex),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Thumbnail strip (only if >1 media)
                    _buildThumbnailStrip(),
                    if (widget.mediaItems.length >= 2) const SizedBox(height: 10),


                    // Stats bar — bold border (hero element), unchanged colors
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_ControlStyle.cardRadius + 6),
                          gradient: const LinearGradient(
                            colors: [PCColors.yellow, PCColors.yellowDark],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          border: _ControlStyle.boldBorder(),
                          boxShadow: const [BoxShadow(
                              color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatPill(icon: '🔥', label: '${widget.streak}-Day Streak'),
                            Container(width: 1, height: 24,
                                color: PCColors.brown.withValues(alpha: 0.35)),
                            _StatPill(icon: '💪', label: '${widget.lifetimeTotal} Lifetime'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Controls: [Rep box] [Ready Time] [Timer box]
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.defaultReps > 0) Expanded(flex: 3, child: _buildRepCounter()),
                          if (widget.defaultReps <= 0 && widget.defaultTimer > 0) const Expanded(flex: 3, child: SizedBox()),
                          
                          Expanded(
                            flex: 5,
                            child: _buildReadyTimeWidget(),
                          ),
                          
                          if (widget.defaultTimer > 0) Expanded(flex: 3, child: _buildExerciseTimer()),
                          if (widget.defaultTimer <= 0 && widget.defaultReps > 0) const Expanded(flex: 3, child: SizedBox()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // START NOW Button
                    InkWell(
                      onTap: _startCountdown,
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 130, height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [PCColors.green, PCColors.greenDark],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          boxShadow: [BoxShadow(
                            color: PCColors.greenDark.withValues(alpha: 0.45),
                            blurRadius: 18, offset: const Offset(0, 6),
                          )],
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                          child: _isCountingDown
                              ? Text(
                                  '$_currentCount',
                                  key: const ValueKey('count'),
                                  style: const TextStyle(
                                    fontSize: 60, fontWeight: FontWeight.w900,
                                    color: Colors.white, height: 1.1,
                                  ),
                                )
                              : const Text(
                                  'START\nNOW',
                                  key: ValueKey('start'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.w900,
                                    color: Colors.white, letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer popup option row
// ─────────────────────────────────────────────────────────────────────────────
class _TimerOption extends StatelessWidget {
  final int? seconds;
  final String? label;
  final IconData? icon;
  final bool selected;
  const _TimerOption({this.seconds, this.label, this.icon, this.selected = false});
  @override
  Widget build(BuildContext context) {
    final text = label ?? '${seconds}s';
    return Row(
      children: [
        Icon(icon ?? Icons.timer_rounded, size: 18,
            color: selected ? PCColors.yellowDark : PCColors.brown),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            color: selected ? PCColors.brownDark : PCColors.brown)),
        if (selected) ...[const Spacer(), const Icon(Icons.check_rounded, size: 18, color: PCColors.green)],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat pill
// ─────────────────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String icon;
  final String label;
  const _StatPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: PCColors.brownDark)),
    ],
  );
}