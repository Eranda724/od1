import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_settings.dart';
import '../models/session_item.dart';
import '../models/exercise_item.dart';
import 'session_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/network_or_asset_image.dart';
import '../services/ad_service.dart';

// Design Tokens
class _PCSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
}

class _PCRadii {
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

  static TextStyle bodyText(BuildContext context) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

// Widget
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
  late final String _randomImage;

  @override
  void initState() {
    super.initState();

    // Preload the interstitial ad so it's ready for the session screen
    AdService.instance.loadInterstitialAd();

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

  @override
  void dispose() {
    super.dispose();
  }

  void _startExercise() {
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

  // Detail Card
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

  // Start Button
  Widget _buildStartButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _PCSpacing.xl),
      child: InkWell(
        onTap: _startExercise,
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
          child: Row(
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
    );
  }

  // Build
  @override
  Widget build(BuildContext context) {
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Header Section
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
                            if (def.descriptions != null &&
                                def.descriptions!.containsKey(langCode) &&
                                def.descriptions![langCode]!.isNotEmpty) {
                              displayDesc = def.descriptions![langCode]!;
                            } else if (def.description != null &&
                                def.description!.isNotEmpty) {
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
                            displayDesc =
                                fallbacks[widget.exerciseName.hashCode.abs() %
                                    fallbacks.length];
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

                // Stats Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _PCSpacing.xl,
                  ),
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
                        // Streak Stat
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/fire_3d.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${widget.streak}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'day_streak_caps'.tr(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  letterSpacing: 0.6,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: PCColors.brown.withValues(alpha: 0.35),
                        ),
                        // Monthly Stat
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/trophy.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${widget.monthlyTotal}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'this_month_label'.tr(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  letterSpacing: 0.6,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: _PCSpacing.xl),

                // Detail Cards
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _PCSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      if (widget.defaultReps > 0 ||
                          widget.defaultTimer > 0) ...[
                        Row(
                          children: [
                            if (widget.defaultReps > 0)
                              Expanded(child: _buildRepCounter()),
                            if (widget.defaultReps > 0 &&
                                widget.defaultTimer > 0)
                              const SizedBox(width: _PCSpacing.md),
                            if (widget.defaultTimer > 0)
                              Expanded(child: _buildExerciseTimer()),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Random Image Spacer
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
                                NetworkOrAssetImage(
                                  _randomImage,
                                  fit: BoxFit.contain,
                                ),
                          )
                        : NetworkOrAssetImage(
                            _randomImage,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ],
            ),
          ),

          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Large Start Button
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: _PCSpacing.xl * 4,
                  ), // Move it up slightly from the bottom edge
                  child: _buildStartButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
