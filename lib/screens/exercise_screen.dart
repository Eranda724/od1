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
                  int targetMonthlyTotal,
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
                            monthlyTotal: nEx['monthlyTotal'] ?? 0,
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
                        monthlyTotal: targetMonthlyTotal,
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

                Widget buildCard(String id, {bool isLibrary = false}) {
                  final isDone = isLibrary ? false : doneExercises.contains(id);
                  final exerciseData = Map<String, dynamic>.from(
                    exercises[id] ?? {},
                  );
                  final streak = exerciseData['currentStreak'] ?? 0;
                  final monthly = exerciseData['monthlyTotal'] ?? 0;
                  final todayReps = exerciseData['todayReps'] ?? 0;
                  final def = exerciseDefs[id];
                  if (def == null) return const SizedBox.shrink();
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
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
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
                                      height: double.infinity,
                                      iconSize: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
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
                                    const SizedBox(height: 8),
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
                                    const SizedBox(height: 8),
                                    if (isLibrary)
                                      Center(
                                        child: IconButton(
                                          icon: Icon(
                                            idsToShow.contains(id)
                                                ? Icons.check_circle
                                                : Icons.add_circle,
                                            color: PCColors.yellow,
                                            size: 36,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: idsToShow.contains(id)
                                              ? null
                                              : () => _addExerciseToRoutine(
                                                  id,
                                                  idsToShow,
                                                  exerciseDefs,
                                                ),
                                        ),
                                      )
                                    else
                                      Container(
                                        height: 36,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD6A000),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                            monthly,
                                            unit,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFFFC72C,
                                            ),
                                            foregroundColor: Colors.black,
                                            elevation: 6,
                                            shadowColor: Colors.black
                                                .withValues(alpha: 0.4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                              vertical: 0,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!isLibrary)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white70,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.black54,
                                    size: 18,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _removeExerciseFromRoutine(
                                    id,
                                    idsToShow,
                                    exerciseDefs,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  Widget listCard() {
                    Widget content = Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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
                                        )
                                      else if (!isLibrary)
                                        Text(
                                          'exercise_streak_label'.tr(
                                            args: [streak.toString()],
                                          ),
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
                                  ),
                                ),
                                const SizedBox(width: 16),
                                if (isLibrary)
                                  IconButton(
                                    icon: Icon(
                                      idsToShow.contains(id)
                                          ? Icons.check_circle
                                          : Icons.add_circle,
                                      color: PCColors.yellow,
                                      size: 32,
                                    ),
                                    onPressed: idsToShow.contains(id)
                                        ? null
                                        : () => _addExerciseToRoutine(
                                            id,
                                            idsToShow,
                                            exerciseDefs,
                                          ),
                                  )
                                else
                                  Container(
                                    width: 110,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDone
                                              ? Colors.green[800]!
                                              : PCColors.yellowDark,
                                          offset: const Offset(0, 4),
                                          blurRadius: 0,
                                        ),
                                        const BoxShadow(
                                          color: Colors.black12,
                                          offset: Offset(0, 6),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () => startExercise(
                                        id,
                                        isDone,
                                        displayName,
                                        def,
                                        streak,
                                        monthly,
                                        unit,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDone
                                            ? Colors.green
                                            : PCColors.yellow,
                                        foregroundColor: isDone
                                            ? Colors.white
                                            : Colors.black,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 0,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        isDone
                                            ? 'do_again_btn'.tr().toUpperCase()
                                            : 'start_btn'.tr().toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
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

                    content = InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: isLibrary
                          ? () => _addExerciseToRoutine(
                              id,
                              idsToShow,
                              exerciseDefs,
                            )
                          : () => startExercise(
                              id,
                              isDone,
                              displayName,
                              def,
                              streak,
                              monthly,
                              unit,
                            ),
                      child: content,
                    );

                    void handleRemove() async {
                      final oldSelected = List<String>.from(idsToShow);
                      await _removeExerciseFromRoutine(
                        id,
                        idsToShow,
                        exerciseDefs,
                      );
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 3),
                          content: Text('exercise_removed'.tr()),
                          action: SnackBarAction(
                            label: 'undo'.tr(),
                            onPressed: () {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.user!.uid)
                                  .update({'selectedExercises': oldSelected});
                            },
                          ),
                        ),
                      );
                    }

                    final cardContainer = Container(
                      margin: EdgeInsets.only(
                        bottom: 12,
                        top: isLibrary ? 0 : 4,
                        right: isLibrary ? 0 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDone
                            ? Colors.green.withValues(alpha: 0.05)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (!isDone)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: content,
                    );

                    if (isLibrary) return cardContainer;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        cardContainer,
                        Positioned(
                          top: -3,
                          right: -3,
                          child: GestureDetector(
                            onTap: handleRemove,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.redAccent,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: Colors.redAccent,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return _settings.isGridView ? gridCard() : listCard();
                }

                Widget buildSection(
                  String title,
                  List<String> ids,
                  Color titleColor, {
                  bool isLibrary = false,
                  Widget? trailing,
                  String? subtitle,
                  double bottomSpacing = 24.0,
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
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 260,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: ids.length,
                          itemBuilder: (context, index) =>
                              buildCard(ids[index], isLibrary: isLibrary),
                        )
                      else
                        Column(
                          children: ids
                              .map((id) => buildCard(id, isLibrary: isLibrary))
                              .toList(),
                        ),
                      SizedBox(height: bottomSpacing),
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
                              // Routine Card
                              if (todoExercises.isNotEmpty)
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 400,
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        top: 12,
                                        bottom: 0,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Theme.of(context).cardColor
                                            : const Color(0xFFF6F0E7),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            'todays_routine_title'.tr(),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'exercises_count'.tr(args: [todoExercises.length.toString()]),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF55AB78),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            width: double.infinity,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0xFF3D8B5D),
                                                  offset: Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                if (todoExercises.isNotEmpty) {
                                                  final targetId =
                                                      todoExercises.first;
                                                  final def =
                                                      exerciseDefs[targetId];
                                                  final exData =
                                                      Map<String, dynamic>.from(
                                                        exercises[targetId] ??
                                                            {},
                                                      );
                                                  if (def != null) {
                                                    startExercise(
                                                      targetId,
                                                      false,
                                                      def.name,
                                                      def,
                                                      exData['currentStreak'] ??
                                                          0,
                                                      exData['monthlyTotal'] ??
                                                          0,
                                                      def.unit,
                                                    );
                                                  }
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF55AB78),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              ),
                                              child: Text(
                                                'start_my_routine'.tr().toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'tap_to_finish_routine'.tr(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
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

                              // Routine Completed card (all done today)
                              if (todoExercises.isEmpty && doneExercises.isNotEmpty)
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 400,
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        top: 12,
                                        bottom: 0,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Theme.of(context).cardColor
                                            : const Color(0xFFF6F0E7),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'routine_completed_today'.tr(),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            width: double.infinity,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0xFF3D8B5D),
                                                  offset: Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                if (doneExercises.isNotEmpty) {
                                                  final targetId =
                                                      doneExercises.first;
                                                  final def =
                                                      exerciseDefs[targetId];
                                                  final exData =
                                                      Map<String, dynamic>.from(
                                                        exercises[targetId] ??
                                                            {},
                                                      );
                                                  if (def != null) {
                                                    startExercise(
                                                      targetId,
                                                      true,
                                                      def.name,
                                                      def,
                                                      exData['currentStreak'] ??
                                                          0,
                                                      exData['monthlyTotal'] ??
                                                          0,
                                                      def.unit,
                                                    );
                                                  }
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF55AB78,
                                                ),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              ),
                                              child: Text(
                                                'start_again'.tr().toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
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

                              // Grid/List toggle & Today's Routine Title Header
                              if (todoExercises.isNotEmpty ||
                                  doneExercises.isNotEmpty ||
                                  libraryIds.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 16.0,
                                    bottom: 1.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (todoExercises.isNotEmpty ||
                                          doneExercises.isNotEmpty)
                                        Text(
                                          'todays_routine_title'.tr(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        )
                                      else
                                        const SizedBox(),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
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
                                  ),
                                ),
                              buildSection(
                                '',
                                todoExercises,
                                Theme.of(context).colorScheme.onSurface,
                                bottomSpacing: 0.0,
                              ),
                              buildSection(
                                '',
                                doneExercises,
                                Theme.of(context).colorScheme.onSurface,
                                bottomSpacing: 16.0,
                              ),

                              buildSection(
                                'All', // The user requested "All" for the library section
                                libraryIds,
                                Theme.of(context).colorScheme.onSurface,
                                isLibrary: true,
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
