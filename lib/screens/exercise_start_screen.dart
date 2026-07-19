import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
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
  final int lifetimeTotal;
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
    required this.lifetimeTotal,
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
      'assets/images/po1.png',
      'assets/images/po2.png',
      'assets/images/po3.png',
      'assets/images/login.png',
      'assets/images/register.png',
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
            lifetimeTotal: widget.lifetimeTotal,
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
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface),
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
          style: _PCTextStyles.heroNumber(context).copyWith(fontSize: 42, color: Theme.of(context).colorScheme.onSurface),
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

  // ── Ready Time widget ─────────────────────────────────────────────────────
  Widget _buildReadyTimeWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: _PCSpacing.lg,
        vertical: _PCSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(_PCRadii.md),
        border: Border.all(
          color: PCColors.brown.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: _PCSpacing.xs),
              Text('ready_time_label'.tr(), style: _PCTextStyles.sectionLabel(context).copyWith(fontSize: 16)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _wantsReadyTime ? '${_readyTimeSeconds}s' : 'off_label'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _wantsReadyTime ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: _PCSpacing.sm),
              Checkbox(
                value: _wantsReadyTime,
                activeColor: PCColors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: PCColors.brown, width: 1.5),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _wantsReadyTime = val);
                    _saveWantsReadyTime(val);
                  }
                },
              ),
              if (_wantsReadyTime) ...[
                const SizedBox(width: _PCSpacing.sm),
                GestureDetector(
                  key: _timerKey,
                  onTap: _showTimerMenu,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _PCSpacing.md,
                      vertical: _PCSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(_PCRadii.sm),
                      border: Border.all(color: PCColors.brown.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Start Button ──────────────────────────────────────────────────────────
  Widget _buildStartButton() {
    return InkWell(
      onTap: _isCountingDown ? _stopCountdown : _startCountdown,
      customBorder: const CircleBorder(),
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [PCColors.green, PCColors.greenDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: PCColors.greenDark.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: PCColors.green.withValues(alpha: 0.3),
              blurRadius: 48,
              offset: const Offset(0, 0),
            ),
          ],
          border: Border.all(color: Colors.white, width: 4),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _isCountingDown
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_currentCount',
                      key: const ValueKey('count'),
                      style: _PCTextStyles.countdownNumber,
                    ),
                    Text(
                      'cancel_btn'.tr().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'start_now'.tr(),
                      textAlign: TextAlign.center,
                      style: _PCTextStyles.startButton,
                    ),
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                    
                  ],
                ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: PCColors.yellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
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
                    if (widget.description != null &&
                        widget.description!.isNotEmpty) ...[
                      const SizedBox(height: _PCSpacing.sm),
                      Text(
                        widget.description!,
                        style: _PCTextStyles.bodyText(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
                    borderRadius: BorderRadius.circular(_PCRadii.lg),
                    gradient: const LinearGradient(
                      colors: [PCColors.yellow, PCColors.yellowDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: PCColors.brown, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
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
                      _StatPill(icon: '🔥', label: 'day_streak_count'.tr(args: [widget.streak.toString()])),
                      Container(
                        width: 1,
                        height: 28,
                        color: PCColors.brown.withValues(alpha: 0.35),
                      ),
                      _StatPill(
                        icon: '💪',
                        label: 'lifetime_total_count'.tr(args: [widget.lifetimeTotal.toString()]),
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
                      const SizedBox(height: _PCSpacing.md),
                    ],
                    _buildReadyTimeWidget(),
                  ],
                ),
              ),

              // ── Random Image Spacer ───────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: _PCSpacing.md, horizontal: _PCSpacing.xl),
                  child: Image.asset(
                    _randomImage,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // ── Large Start Button ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: _PCSpacing.xxxl),
                child: _buildStartButton(),
              ),
            ],
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
          color: selected ? PCColors.yellowDark : Theme.of(context).colorScheme.onSurface,
        ),
        const SizedBox(width: _PCSpacing.md),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        if (selected) ...[
          const Spacer(),
          const Icon(
            Icons.check_rounded,
            size: 20,
            color: PCColors.green,
          ),
        ],
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
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: _PCSpacing.sm),
          Text(
            label,
            style: _PCTextStyles.statLabel(context),
          ),
        ],
      );
}