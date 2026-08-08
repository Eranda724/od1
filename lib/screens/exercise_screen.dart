import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
export '../models/exercise_item.dart' show ExerciseMedia;
import 'exercise_start_screen.dart';
import '../app_settings.dart';
import '../models/session_item.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/ad_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../widgets/exercise_thumbnail.dart';

class ExerciseScreen extends StatefulWidget {
  final User? user;
  const ExerciseScreen({super.key, required this.user});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    AdService.instance.loadBannerAd(
      onLoaded: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    AdService.instance.disposeBannerAd();
    super.dispose();
  }

  String _fallbackName(String id) {
    switch (id) {
      case 'pushups':
        return 'Push-Up';
      case 'squats':
        return 'Squat';
      case 'situps':
        return 'Sit-Up';
      default:
        return id;
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _addExerciseToRoutine(
    String id,
    List<String> currentSelected,
    Map<String, ExerciseItem> defs,
  ) async {
    final uid = widget.user?.uid;
    if (uid == null) return;
    final newSelected = List<String>.from(currentSelected)..add(id);
    await _saveRoutine(uid, newSelected, defs);
  }

  Future<void> _removeExerciseFromRoutine(
    String id,
    List<String> currentSelected,
    Map<String, ExerciseItem> defs,
  ) async {
    final uid = widget.user?.uid;
    if (uid == null) return;
    final newSelected = List<String>.from(currentSelected)..remove(id);
    await _saveRoutine(uid, newSelected, defs);
  }

  Future<void> _saveRoutine(
    String uid,
    List<String> newSelected,
    Map<String, ExerciseItem> defs,
  ) async {
    int totalTime = 0;
    for (String id in newSelected) {
      final def = defs[id];
      if (def != null && def.defaultTimer > 0) {
        totalTime += def.defaultTimer;
      } else {
        totalTime += 60; // default 1 min
      }
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'selectedExercises': newSelected,
      'routineEstimatedTime': totalTime,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.user?.uid;
    if (uid == null) return Center(child: Text('please_sign_in'.tr()));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userDocSnap) {
        final userData =
            userDocSnap.data?.data() as Map<String, dynamic>? ?? {};
        // null means the field was never set (new user) — treat as "all selected".
        // An explicit empty list [] means the user deliberately deselected everything.
        final rawSelected = userData['selectedExercises'];
        final bool neverConfigured = rawSelected == null;
        final selectedExercises = neverConfigured
            ? null
            : List<String>.from(rawSelected);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('exercises')
              .snapshots(),
          builder: (context, userExercisesSnap) {
            if (userExercisesSnap.hasError) {
              return Center(
                child: Text(
                  'error_loading'.tr(
                    args: [userExercisesSnap.error.toString()],
                  ),
                ),
              );
            }
            final exercises = <String, Map<String, dynamic>>{};
            if (userExercisesSnap.hasData) {
              for (final doc in userExercisesSnap.data!.docs) {
                exercises[doc.id] = doc.data() as Map<String, dynamic>;
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('exercises')
                  .snapshots(),
              builder: (context, exerciseSnapshot) {
                if (exerciseSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'error_loading'.tr(
                        args: [exerciseSnapshot.error.toString()],
                      ),
                    ),
                  );
                }

                final exerciseDefs = <String, ExerciseItem>{};
                if (exerciseSnapshot.hasData) {
                  for (final doc in exerciseSnapshot.data!.docs) {
                    exerciseDefs[doc.id] = ExerciseItem.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    );
                  }
                }

                final today = _todayKey();
                final todoExercises = <String>[];
                final doneExercises = <String>[];

                final idsToShow = neverConfigured
                    ? exerciseDefs.keys.toList()
                    : (selectedExercises ?? []);

                final libraryIds = exerciseDefs.keys
                    .where((id) => !idsToShow.contains(id))
                    .toList();

                for (final id in idsToShow) {
                  if (!exerciseDefs.containsKey(id)) continue;
                  final exerciseData = Map<String, dynamic>.from(
                    exercises[id] ?? {},
                  );
                  final lastCompleted =
                      exerciseData['lastCompletedDate'] as String?;
                  if (lastCompleted == today) {
                    doneExercises.add(id);
                  } else {
                    todoExercises.add(id);
                  }
                }

                void startExercise(
                  String targetId,
                  bool isDoneTarget,
                  String targetDisplayName,
                  ExerciseItem? targetDef,
                  int targetStreak,
                  int targetLifetime,
                  String targetUnit,
                ) {
                  List<SessionItem> queue = [];
                  int startingIndex = 1;
                  int totalTodos = todoExercises.length;

                  if (!isDoneTarget) {
                    final index = todoExercises.indexOf(targetId);
                    if (index != -1) {
                      startingIndex = index + 1;
                      for (int i = index + 1; i < todoExercises.length; i++) {
                        final nextId = todoExercises[i];
                        final nEx = Map<String, dynamic>.from(
                          exercises[nextId] ?? {},
                        );
                        final nDef = exerciseDefs[nextId];
                        queue.add(
                          SessionItem(
                            exerciseId: nextId,
                            exerciseName: nDef?.name ?? _fallbackName(nextId),
                            description: (nDef?.description?.isNotEmpty == true)
                                ? nDef!.description
                                : 'default_exercise_description'.tr(),
                            streak: nEx['currentStreak'] ?? 0,
                            lifetimeTotal: nEx['lifetimeTotal'] ?? 0,
                            defaultReps: nDef?.defaultReps ?? 0,
                            defaultTimer: nDef?.defaultTimer ?? 0,
                            unit: nDef?.unit ?? 'reps',
                            exerciseDef: nDef,
                          ),
                        );
                      }
                    }
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExerciseStartScreen(
                        exerciseId: targetId,
                        exerciseName: targetDisplayName,
                        description:
                            (targetDef?.description?.isNotEmpty == true)
                            ? targetDef!.description
                            : 'default_exercise_description'.tr(),
                        streak: targetStreak,
                        lifetimeTotal: targetLifetime,
                        defaultReps: targetDef?.defaultReps ?? 0,
                        defaultTimer: targetDef?.defaultTimer ?? 0,
                        unit: targetUnit,
                        exerciseDef: targetDef,
                        sessionQueue: queue,
                        exerciseIndex: isDoneTarget ? 1 : startingIndex,
                        totalExercises: isDoneTarget ? 1 : totalTodos,
                      ),
                    ),
                  );
                }

                Widget buildCard(
                  String id,
                  bool isDone, {
                  bool isLibrary = false,
                }) {
                  final exerciseData = Map<String, dynamic>.from(
                    exercises[id] ?? {},
                  );
                  final streak = exerciseData['currentStreak'] ?? 0;
                  final lifetime = exerciseData['lifetimeTotal'] ?? 0;
                  final todayReps = exerciseData['todayReps'] ?? 0;
                  final def = exerciseDefs[id]!;
                  final displayName = def.name;
                  final unit = def.unit;

                  Widget gridCard() {
                    return Card(
                      margin: EdgeInsets.zero,
                      color: isDone
                          ? Colors.green.withValues(alpha: 0.05)
                          : null,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide.none,
                      ),
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 100,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: Center(
                              child: ExerciseThumbnail(
                                def: def,
                                width: double.infinity,
                                height: 100,
                                iconSize: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      if (isDone)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Spacer(),
                                  if (isDone)
                                    Text(
                                      '$todayReps $unit',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.blueGrey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  const SizedBox(height: 4),
                                  if (isLibrary) ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: idsToShow.contains(id)
                                          ? ElevatedButton(
                                              onPressed: null,
                                              style: ElevatedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 0,
                                                    ),
                                                minimumSize: const Size(0, 32),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                'added_btn'.tr(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD6A000),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding: const EdgeInsets.only(
                                                bottom: 3,
                                              ),
                                              child: ElevatedButton(
                                                onPressed: () =>
                                                    _addExerciseToRoutine(
                                                      id,
                                                      idsToShow,
                                                      exerciseDefs,
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFFFFC72C,
                                                  ),
                                                  foregroundColor: Colors.black,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 0,
                                                      ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  'add_btn'.tr(),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD6A000),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.only(
                                              bottom: 3,
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () => startExercise(
                                                id,
                                                isDone,
                                                displayName,
                                                def,
                                                streak,
                                                lifetime,
                                                unit,
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFFFC72C,
                                                ),
                                                foregroundColor: Colors.black,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 2,
                                                      vertical: 0,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                isDone
                                                    ? 'do_again_btn'
                                                          .tr()
                                                          .toUpperCase()
                                                    : 'start_btn'
                                                          .tr()
                                                          .toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (!isDone) ...[
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () =>
                                                _removeExerciseFromRoutine(
                                                  id,
                                                  idsToShow,
                                                  exerciseDefs,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  Widget listCard() {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isDone
                          ? Colors.green.withValues(alpha: 0.05)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide.none,
                      ),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: isLibrary
                            ? null
                            : () => startExercise(
                                id,
                                isDone,
                                displayName,
                                def,
                                streak,
                                lifetime,
                                unit,
                              ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 16.0,
                          ),
                          child: Row(
                            children: [
                              ExerciseThumbnail(
                                def: def,
                                width: 64,
                                height: 64,
                                iconSize: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isDone) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '$todayReps $unit',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white70
                                              : Colors.blueGrey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isLibrary) ...[
                                idsToShow.contains(id)
                                    ? ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'added_btn'.tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD6A000),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _addExerciseToRoutine(
                                                id,
                                                idsToShow,
                                                exerciseDefs,
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFFFC72C,
                                            ),
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 0,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            'add_btn'.tr(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                              ] else ...[
                                Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD6A000),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: ElevatedButton(
                                    onPressed: () => startExercise(
                                      id,
                                      isDone,
                                      displayName,
                                      def,
                                      streak,
                                      lifetime,
                                      unit,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFC72C),
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 0,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      isDone
                                          ? 'again_btn'.tr().toUpperCase()
                                          : 'start_btn'.tr().toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                if (!isDone)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeExerciseFromRoutine(
                                      id,
                                      idsToShow,
                                      exerciseDefs,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return _settings.isGridView ? gridCard() : listCard();
                }

                Widget buildSection(
                  String title,
                  List<String> ids,
                  bool isDone,
                  Color titleColor, {
                  bool isLibrary = false,
                  Widget? trailing,
                  String? subtitle,
                }) {
                  if (ids.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty || trailing != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 0.0, bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (title.isNotEmpty)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize:
                                              16, // Adjusted to match mockup size better
                                          fontWeight: FontWeight.bold,
                                          color: titleColor,
                                        ),
                                      ),
                                      if (subtitle != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              if (trailing != null) ...[
                                const SizedBox(width: 8),
                                trailing,
                              ],
                            ],
                          ),
                        ),
                      if (_settings.isGridView)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: isDone ? 0.82 : 0.9,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: ids.length,
                          itemBuilder: (context, index) => buildCard(
                            ids[index],
                            isDone,
                            isLibrary: isLibrary,
                          ),
                        )
                      else
                        Column(
                          children: ids
                              .map(
                                (id) =>
                                    buildCard(id, isDone, isLibrary: isLibrary),
                              )
                              .toList(),
                        ),
                    ],
                  );
                }

                final isEmpty = todoExercises.isEmpty && doneExercises.isEmpty;

                return AnimatedBuilder(
                  animation: _settings.gridViewNotifier,
                  builder: (context, _) {
                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            children: [
                              // COMMENCER MA ROUTINE BUTTON
                              if (todoExercises.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green[800]!,
                                        offset: const Offset(0, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      final firstId = todoExercises.first;
                                      final def = exerciseDefs[firstId];
                                      final exData = Map<String, dynamic>.from(
                                        exercises[firstId] ?? {},
                                      );
                                      startExercise(
                                        firstId,
                                        false,
                                        def?.name ?? _fallbackName(firstId),
                                        def,
                                        exData['currentStreak'] ?? 0,
                                        exData['lifetimeTotal'] ?? 0,
                                        def?.unit ?? 'reps',
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'start_my_routine'.tr().toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              buildSection(
                                'today_label'.tr().toUpperCase(),
                                todoExercises,
                                false,
                                PCColors.yellow,
                              ),
                              const SizedBox(height: 24),

                              // 3. AUJOURD'HUI TEXT
                              Builder(
                                builder: (context) {
                                  int estimatedSeconds = 0;
                                  for (String id in todoExercises) {
                                    final def = exerciseDefs[id];
                                    if (def != null && def.defaultTimer > 0) {
                                      estimatedSeconds += def.defaultTimer;
                                    } else {
                                      estimatedSeconds += 60; // 1 min default
                                    }
                                  }
                                  final estimatedMins = (estimatedSeconds / 60).ceil();
                                  final totalCount = todoExercises.length + doneExercises.length;
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'todays_routine_title'.tr().toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ' ${'exercises_count'.tr(args: [totalCount.toString()])} - ~$estimatedMins min',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              if (isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24.0,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'choose_first_exercise'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),

                              buildSection(
                                'to_do_label'.tr(),
                                todoExercises,
                                false,
                                Theme.of(context).colorScheme.onSurface,
                                trailing: IconButton(
                                  tooltip: _settings.isGridView
                                      ? 'switch_list_view'.tr()
                                      : 'switch_grid_view'.tr(),
                                  icon: Icon(
                                    _settings.isGridView
                                        ? Icons.view_list_rounded
                                        : Icons.grid_view_rounded,
                                  ),
                                  onPressed: () => _settings.setGridView(
                                    !_settings.isGridView,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'exercises_title'.tr(),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (todoExercises.isEmpty) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: _settings.isGridView
                                          ? 'switch_list_view'.tr()
                                          : 'switch_grid_view'.tr(),
                                      icon: Icon(
                                        _settings.isGridView
                                            ? Icons.view_list_rounded
                                            : Icons.grid_view_rounded,
                                      ),
                                      onPressed: () => _settings.setGridView(
                                        !_settings.isGridView,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 0),
                              buildSection(
                                '',
                                libraryIds,
                                false,
                                Colors.transparent,
                                isLibrary: true,
                              ),

                              buildSection(
                                'completed_today_label'.tr(),
                                doneExercises,
                                true,
                                Colors.green,
                              ),
                            ],
                          ),
                        ),
                        //>>>>>>for ad
                        StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser?.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final isPremium =
                                snapshot.data?.data()?['isPremium'] == true;
                            if (isPremium) {
                              return const SizedBox(); // No space if premium
                            }

                            final bannerAd = AdService.instance.bannerAd;
                            if (bannerAd != null) {
                              return Container(
                                alignment: Alignment.center,
                                width: bannerAd.size.width.toDouble(),
                                height: bannerAd.size.height.toDouble(),
                                child: AdWidget(ad: bannerAd),
                              );
                            }

                            return const SizedBox(
                              height: 50,
                            ); // Reserved space for future banner ad
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
