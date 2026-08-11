import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../models/session_item.dart';
import '../models/exercise_item.dart';
import 'session_screen.dart';
import 'package:easy_localization/easy_localization.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class _PCSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class _PCRadii {
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double lg = 20.0;
}

class _PCTextStyles {
  static TextStyle screenTitle(BuildContext context) => TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle sectionLabel(BuildContext context) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
    letterSpacing: 0.8,
  );

  static TextStyle heroNumber(BuildContext context) => TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w900,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle statLabel(BuildContext context) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static const TextStyle startButton = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 1.2,
  );

  static const TextStyle countdownNumber = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  );

  static TextStyle bodyText(BuildContext context) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class ExerciseStartScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String? description;
  final int streak;
  final int monthlyTotal;
  final int defaultReps;
  final int defaultTimer;
  final String unit;
  final ExerciseItem? exerciseDef;

  final List<SessionItem>? sessionQueue;
  final int? exerciseIndex;
  final int? totalExercises;

  const ExerciseStartScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.description,
    required this.streak,
    required this.monthlyTotal,
    this.defaultReps = 10,
    this.defaultTimer = 30,
    this.unit = 'reps',
    this.exerciseDef,
    this.sessionQueue,
    this.exerciseIndex,
    this.totalExercises,
  });

  @override
  State<ExerciseStartScreen> createState() => _ExerciseStartScreenState();
}

class _ExerciseStartScreenState extends State<ExerciseStartScreen> {
  // ── Ready Time ─────────────────────────────────────────────────────────────
  bool _wantsReadyTime = false;
  int _readyTimeSeconds = 3;
  final GlobalKey _timerKey = GlobalKey();

  late final AudioPlayer _player;

  // ── Countdown ───────────────────────────────────────────────────────────────
  bool _isCountingDown = false;
  int _currentCount = 3;
  Timer? _countdownTimer;

  late final String _randomImage;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
    _loadSavedPrefs();

    final images = [
      'assets/images/p1.png',
      'assets/images/p2.png',
      'assets/images/p3.png',
      'assets/images/p4.png',
      'assets/images/p5.png',
      'assets/images/p6.png',
      'assets/images/p7.png',
    ];
    _randomImage = images[Random().nextInt(images.length)];
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _loadSavedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getInt('globalReadyTime');
    final wantsTime = prefs.getBool('globalWantsReadyTime');
    if (mounted) {
      setState(() {
        if (savedTime != null) _readyTimeSeconds = savedTime;
        if (wantsTime != null) _wantsReadyTime = wantsTime;
      });
    }
  }

  Future<void> _saveTime(int t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('globalReadyTime', t);
  }

  Future<void> _saveWantsReadyTime(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('globalWantsReadyTime', v);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  // ── Countdown ──────────────────────────────────────────────────────────────
  void _stopCountdown() {
    if (!_isCountingDown) return;
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _isCountingDown = false;
      });
    }
    try {
      _player.stop();
    } catch (_) {}
  }

  void _startCountdown() async {
    if (_isCountingDown) return;

    try {
      await _player.stop();
      await _player.setVolume(0.25);
      await _player.play(AssetSource('sounds/stop.mp3'));
    } catch (_) {}

    void navigate() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(
            exerciseId: widget.exerciseId,
            exerciseName: widget.exerciseName,
            backgroundImageUrl: _randomImage,
            unit: widget.unit,
            exerciseDef: widget.exerciseDef,
            challengeSeconds: widget.defaultTimer,
            streak: widget.streak,
            monthlyTotal: widget.monthlyTotal,
            defaultReps: widget.defaultReps,
            sessionQueue: widget.sessionQueue,
            exerciseIndex: widget.exerciseIndex,
            totalExercises: widget.totalExercises,
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
          try {
            _player.stop().then((_) {
              _player.play(AssetSource('sounds/pope.mp3'));
            });
          } catch (_) {}
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) navigate();
          });
        } else {
          try {
            _player.stop().then((_) {
              _player.play(AssetSource('sounds/pops.mp3'));
            });
          } catch (_) {}
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
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: PCColors.brown, width: 1.5),
      ),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 6,
        offset.dx + size.width,
        0,
      ),
      items: [
        for (final s in [3, 5, 10])
          PopupMenuItem<int>(
            value: s,
            height: 48,
            child: _TimerOption(seconds: s, selected: _readyTimeSeconds == s),
          ),
        PopupMenuItem<int>(
          value: -1,
          height: 48,
          child: _TimerOption(
            label: 'custom_label'.tr(),
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
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: PCColors.brown, width: 2),
        ),
        title: Text(
          'ready_time_dialog_title'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            suffixText: 's',
            suffixStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PCColors.brown, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'cancel_btn'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PCColors.yellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v > 0) {
                setState(() => _readyTimeSeconds = v);
                _saveTime(v);
              }
              Navigator.pop(ctx);
            },
            child: Text(
              'set_btn'.tr(),
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail Card ────────────────────────────────────────────────────────────
  Widget _buildDetailCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: _PCSpacing.xs),
            Text(
              label,
              style: _PCTextStyles.sectionLabel(context).copyWith(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: _PCSpacing.xs),
        Text(
          value,
          style: _PCTextStyles.heroNumber(context).copyWith(
            fontSize: 42,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildRepCounter() {
    return _buildDetailCard(
      label: widget.unit.toUpperCase(),
      value: '${widget.defaultReps}',
      icon: Icons.fitness_center_rounded,
    );
  }

  Widget _buildExerciseTimer() {
    return _buildDetailCard(
      label: 'timer_label'.tr(),
      value: '${widget.defaultTimer}s',
      icon: Icons.timer_outlined,
    );
  }

  void _showReadyTimeBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ready_time_label'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      'Enable Ready Time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    value: _wantsReadyTime,
                    activeColor: PCColors.green,
                    onChanged: (val) {
                      setSheetState(() => _wantsReadyTime = val);
                      setState(() => _wantsReadyTime = val);
                      _saveWantsReadyTime(val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_wantsReadyTime) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [3, 5, 10, 15].map((seconds) {
                        final isSelected = _readyTimeSeconds == seconds;
                        return ChoiceChip(
                          label: Text('${seconds}s'),
                          selected: isSelected,
                          selectedColor: PCColors.yellow,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() => _readyTimeSeconds = seconds);
                              setState(() => _readyTimeSeconds = seconds);
                              _saveTime(seconds);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Ready Time widget ─────────────────────────────────────────────────────
  Widget _buildReadyTimeWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            'PARAMÈTRES',
            style: _PCTextStyles.sectionLabel(context).copyWith(
              fontSize: 14,
              letterSpacing: 0,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        InkWell(
          onTap: _showReadyTimeBottomSheet,
          borderRadius: BorderRadius.circular(_PCRadii.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: _PCSpacing.lg,
              vertical: _PCSpacing.lg,
            ),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).cardTheme.color ??
                  Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(_PCRadii.md),
              border: Border.all(
                color: PCColors.brown.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 24,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: _PCSpacing.md),
                    Text(
                      'ready_time_label'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      _wantsReadyTime
                          ? '${_readyTimeSeconds}s'
                          : 'off_label'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _wantsReadyTime
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Start Button ──────────────────────────────────────────────────────────
  Widget _buildStartButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _PCSpacing.xl),
      child: InkWell(
        onTap: _isCountingDown ? _stopCountdown : _startCountdown,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            color: PCColors.yellow,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: PCColors.yellowDark,
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 10),
                blurRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _isCountingDown
                ? Row(
                    key: const ValueKey('countdown_row'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_currentCount',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'cancel_btn'.tr().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('start_row'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 32,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'start_btn'.tr().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [SizedBox(width: 8)],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header Section ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _PCSpacing.xl,
                _PCSpacing.lg,
                _PCSpacing.xl,
                _PCSpacing.sm,
              ),
              child: Column(
                children: [
                  // Exercise name
                  Text(
                    widget.exerciseName.toUpperCase(),
                    style: _PCTextStyles.screenTitle(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: _PCSpacing.sm),
                  Builder(
                    builder: (context) {
                      String displayDesc = '';
                      final langCode = context.locale.languageCode;
                      
                      if (widget.exerciseDef != null) {
                         final def = widget.exerciseDef!;
                         if (def.descriptions != null && def.descriptions!.containsKey(langCode) && def.descriptions![langCode]!.isNotEmpty) {
                           displayDesc = def.descriptions![langCode]!;
                         } else if (def.description != null && def.description!.isNotEmpty) {
                           displayDesc = def.description!;
                         }
                      }
                      
                      if (displayDesc.isEmpty) {
                        final fallbacks = [
                          'Get ready to crush this exercise! 💪',
                          'Push yourself to the limit! 🔥',
                          'Consistency is key to results! 💯',
                          'Let\'s make every rep count! 🎯',
                        ];
                        // Consistent pseudo-random based on exercise name
                        displayDesc = fallbacks[widget.exerciseName.hashCode.abs() % fallbacks.length];
                      }

                      return Text(
                        displayDesc,
                        style: _PCTextStyles.bodyText(context).copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: _PCSpacing.lg),

            // ── Stats Bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _PCSpacing.xl),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).cardTheme.color ??
                      Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(_PCRadii.lg),
                  border: Border.all(
                    color: PCColors.brown.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: _PCSpacing.lg,
                  vertical: _PCSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatPill(
                      iconWidget: Image.asset('assets/images/fire_3d.png', width: 24, height: 24),
                      label: 'day_streak_count'.tr(
                        args: [widget.streak.toString()],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: PCColors.brown.withValues(alpha: 0.35),
                    ),
                    _StatPill(
                      iconWidget: Image.asset('assets/images/trophy.png', width: 24, height: 24),
                      label: 'this_month_count'.tr(
                        args: [widget.monthlyTotal.toString()],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: _PCSpacing.xl),

            // ── Detail Cards ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _PCSpacing.xl),
              child: Column(
                children: [
                  if (widget.defaultReps > 0 || widget.defaultTimer > 0) ...[
                    Row(
                      children: [
                        if (widget.defaultReps > 0)
                          Expanded(child: _buildRepCounter()),
                        if (widget.defaultReps > 0 && widget.defaultTimer > 0)
                          const SizedBox(width: _PCSpacing.md),
                        if (widget.defaultTimer > 0)
                          Expanded(child: _buildExerciseTimer()),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Random Image Spacer ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: _PCSpacing.xl,
                horizontal: _PCSpacing.xl,
              ),
              child: SizedBox(
                height: 220,
                child:
                    (widget.exerciseDef != null &&
                        widget.exerciseDef!.mediaItems.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: widget.exerciseDef!.mediaItems.first.url,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: PCColors.yellow,
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            Image.asset(_randomImage, fit: BoxFit.contain),
                      )
                    : Image.asset(_randomImage, fit: BoxFit.contain),
              ),
            ),

            // ── Ready Time Widget ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _PCSpacing.xl),
              child: _buildReadyTimeWidget(),
            ),

            const SizedBox(height: _PCSpacing.xl),

            // ── Large Start Button ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: _PCSpacing.xl),
              child: _buildStartButton(),
            ),
          ],
        ),
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

  const _TimerOption({
    this.seconds,
    this.label,
    this.icon,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = label ?? '${seconds}s';
    return Row(
      children: [
        Icon(
          icon ?? Icons.timer_rounded,
          size: 20,
          color: selected
              ? PCColors.yellowDark
              : Theme.of(context).colorScheme.onSurface,
        ),
        const SizedBox(width: _PCSpacing.md),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        if (selected) ...[
          const Spacer(),
          const Icon(Icons.check_rounded, size: 20, color: PCColors.green),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat pill
// ─────────────────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final Widget iconWidget;
  final String label;

  const _StatPill({required this.iconWidget, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      iconWidget,
      const SizedBox(width: _PCSpacing.sm),
      Text(label, style: _PCTextStyles.statLabel(context)),
    ],
  );
}
