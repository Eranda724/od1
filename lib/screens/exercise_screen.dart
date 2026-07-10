import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
import '../models/exercise_icons.dart';
export '../models/exercise_item.dart' show ExerciseMedia;
import 'exercise_start_screen.dart';
import '../app_settings.dart';
import '../models/session_item.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/ad_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
    AdService.instance.loadBannerAd(onLoaded: () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    AdService.instance.disposeBannerAd();
    super.dispose();
  }

  String _fallbackName(String id) {
    switch (id) {
      case 'pushups': return 'Push-Up';
      case 'squats': return 'Squat';
      case 'situps': return 'Sit-Up';
      default: return id;
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _showManageSheet(
    BuildContext context,
    List<String> selectedExercises,
    Map<String, ExerciseItem> exerciseDefs,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ManageExercisesSheet(
        uid: widget.user!.uid,
        currentSelected: List<String>.from(selectedExercises),
        exerciseDefs: exerciseDefs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.user?.uid;
    if (uid == null) return Center(child: Text('please_sign_in'.tr()));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userDocSnap) {
        final userData = userDocSnap.data?.data() as Map<String, dynamic>? ?? {};
        // null means the field was never set (new user) — treat as "all selected".
        // An explicit empty list [] means the user deliberately deselected everything.
        final rawSelected = userData['selectedExercises'];
        final bool neverConfigured = rawSelected == null;
        final selectedExercises = neverConfigured ? null : List<String>.from(rawSelected);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(uid).collection('exercises').snapshots(),
          builder: (context, userExercisesSnap) {
            if (userExercisesSnap.hasError) {
              return Center(child: Text('error_loading'.tr(args: [userExercisesSnap.error.toString()])));
            }
            final exercises = <String, Map<String, dynamic>>{};
            if (userExercisesSnap.hasData) {
              for (final doc in userExercisesSnap.data!.docs) {
                exercises[doc.id] = doc.data() as Map<String, dynamic>;
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
              builder: (context, exerciseSnapshot) {
                if (exerciseSnapshot.hasError) {
                  return Center(child: Text('error_loading'.tr(args: [exerciseSnapshot.error.toString()])));
                }

                final exerciseDefs = <String, ExerciseItem>{};
                if (exerciseSnapshot.hasData) {
                  for (final doc in exerciseSnapshot.data!.docs) {
                    exerciseDefs[doc.id] = ExerciseItem.fromMap(
                        doc.id, doc.data() as Map<String, dynamic>);
                  }
                }

                final today = _todayKey();
                final todoExercises = <String>[];
                final doneExercises = <String>[];

                // If never configured, show all global exercises (new-user default).
                final idsToShow = neverConfigured
                    ? exerciseDefs.keys.toList()
                    : (selectedExercises ?? []);

                for (final id in idsToShow) {
                  if (!exerciseDefs.containsKey(id)) continue;
                  final exerciseData = Map<String, dynamic>.from(exercises[id] ?? {});
                  final lastCompleted = exerciseData['lastCompletedDate'] as String?;
                  if (lastCompleted == today) {
                    doneExercises.add(id);
                  } else {
                    todoExercises.add(id);
                  }
                }

                Widget buildCard(String id, bool isDone) {
                  final exerciseData = Map<String, dynamic>.from(exercises[id] ?? {});
                  final streak = exerciseData['currentStreak'] ?? 0;
                  final lifetime = exerciseData['lifetimeTotal'] ?? 0;
                  final def = exerciseDefs[id]!;
                  final displayName = def.name;
                  final icon = def.icon;
                  final unit = def.unit;

                  final hasGoals = (def?.defaultReps ?? 0) > 0 || (def?.defaultTimer ?? 0) > 0 || (def?.defaultDays ?? 0) > 0;
                  final goals = <String>[];
                  if ((def?.defaultReps ?? 0) > 0) goals.add('${def!.defaultReps} ' + 'reps_label'.tr());
                  if ((def?.defaultTimer ?? 0) > 0) goals.add('${def!.defaultTimer}s');
                  if ((def?.defaultDays ?? 0) > 0) goals.add('${def!.defaultDays} ' + 'days_label'.tr());

                  void startExercise() {
                    List<SessionItem> queue = [];
                    int startingIndex = 1;
                    int totalTodos = todoExercises.length;

                    if (!isDone) {
                      final index = todoExercises.indexOf(id);
                      if (index != -1) {
                        startingIndex = index + 1;
                        for (int i = index + 1; i < todoExercises.length; i++) {
                          final nextId = todoExercises[i];
                          final nEx = Map<String, dynamic>.from(exercises[nextId] ?? {});
                          final nDef = exerciseDefs[nextId];
                          queue.add(SessionItem(
                            exerciseId: nextId,
                            exerciseName: nDef?.name ?? _fallbackName(nextId),
                            description: (nDef?.description?.isNotEmpty == true) ? nDef!.description : 'Hold the position steadily and keep your core tight. Breathe naturally throughout the exercise.',
                            streak: nEx['currentStreak'] ?? 0,
                            lifetimeTotal: nEx['lifetimeTotal'] ?? 0,
                            defaultReps: nDef?.defaultReps ?? 0,
                            defaultTimer: nDef?.defaultTimer ?? 0,
                            unit: nDef?.unit ?? 'reps',
                            exerciseDef: nDef,
                          ));
                        }
                      }
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExerciseStartScreen(
                          exerciseId: id,
                          exerciseName: displayName,
                          description: (def?.description?.isNotEmpty == true) ? def!.description : 'Hold the position steadily and keep your core tight. Breathe naturally throughout the exercise.',
                          streak: streak,
                          lifetimeTotal: lifetime,
                          defaultReps: def?.defaultReps ?? 0,
                          defaultTimer: def?.defaultTimer ?? 0,
                          unit: unit,
                          exerciseDef: def,
                          sessionQueue: queue,
                          exerciseIndex: isDone ? 1 : startingIndex,
                          totalExercises: isDone ? 1 : totalTodos,
                        ),
                      ),
                    );
                  }

                  Widget gridCard() {
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isDone ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (isDone) const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              ],
                            ),
                            Expanded(child: Center(child: buildExerciseVisual(def, size: 48))),
                            if (hasGoals)
                              Text('?? ${goals.join('  ')}', style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.blueGrey, fontWeight: FontWeight.w600)),
                            if (streak > 0 || lifetime > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [Text('$lifetime ' + 'total_label'.tr() + ' ($unit)', style: const TextStyle(fontSize: 11))],
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: startExercise,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: const Size(0, 36),
                                ),
                                child: Text(isDone ? 'do_again_btn'.tr() : 'start_btn'.tr(), style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  Widget listCard() {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isDone ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
                      ),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: startExercise,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC72C).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(child: buildExerciseVisual(def, size: 28)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    if (hasGoals) ...[
                                      const SizedBox(height: 4),
                                      Text('?? ${goals.join('  ')}', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.blueGrey, fontWeight: FontWeight.w600)),
                                    ],
                                    if (streak > 0 || lifetime > 0) ...[
                                      const SizedBox(height: 4),
                                      Text('$lifetime ' + 'total_label'.tr() + ' ($unit)', style: const TextStyle(fontSize: 13)),
                                    ],
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: startExercise,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: Text(isDone ? 'again_btn'.tr() : 'start_btn'.tr()),
                              ),
                              if (isDone)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.check_circle, color: Colors.green, size: 28),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return _settings.isGridView ? gridCard() : listCard();
                }

                Widget buildSection(String title, List<String> ids, bool isDone, Color titleColor) {
                  if (ids.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
                        child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
                      ),
                      if (_settings.isGridView)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: ids.length,
                          itemBuilder: (context, index) => buildCard(ids[index], isDone),
                        )
                      else
                        Column(children: ids.map((id) => buildCard(id, isDone)).toList()),
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
                      child: Stack(
                        children: [
                          ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                            children: [
                              if (isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 48.0),
                                  child: Center(
                                    child: Text(
                                      'no_exercises_selected'.tr(),
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              buildSection('to_do_label'.tr(), todoExercises, false, Theme.of(context).colorScheme.onSurface),
                              buildSection('completed_today_label'.tr(), doneExercises, true, Colors.green),
                            ],
                          ),
                          Positioned(
                              top: 8,
                              right: 8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Toggle between list and grid view
                                  IconButton(
                                    tooltip: _settings.isGridView ? 'switch_list_view'.tr() : 'switch_grid_view'.tr(),
                                    icon: Icon(
                                      _settings.isGridView
                                          ? Icons.view_list_rounded
                                          : Icons.grid_view_rounded,
                                    ),
                                    onPressed: () => _settings.setGridView(!_settings.isGridView),
                                  ),
                                  if (exerciseDefs.isNotEmpty)
                                    IconButton(
                                      tooltip: 'manage_exercises_title'.tr(),
                                      icon: const Icon(Icons.edit_rounded),
                                      onPressed: () => _showManageSheet(
                                        context,
                                        neverConfigured
                                            ? exerciseDefs.keys.toList()
                                            : (selectedExercises ?? []),
                                        exerciseDefs,
                                      ),
                                    ),
                                ],
                              ),
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
                        final isPremium = snapshot.data?.data()?['isPremium'] == true;
                        if (isPremium) return const SizedBox(); // No space if premium
                        
                        final bannerAd = AdService.instance.bannerAd;
                        if (bannerAd != null) {
                          return Container(
                            alignment: Alignment.center,
                            width: bannerAd.size.width.toDouble(),
                            height: bannerAd.size.height.toDouble(),
                            child: AdWidget(ad: bannerAd),
                          );
                        }
                        
                        return const SizedBox(height: 50); // Reserved space for future banner ad
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

// -----------------------------------------------------------------------------
// Bottom sheet for managing selected exercises
// -----------------------------------------------------------------------------
class _ManageExercisesSheet extends StatefulWidget {
  final String uid;
  final List<String> currentSelected;
  final Map<String, ExerciseItem> exerciseDefs;

  const _ManageExercisesSheet({
    required this.uid,
    required this.currentSelected,
    required this.exerciseDefs,
  });

  @override
  State<_ManageExercisesSheet> createState() => _ManageExercisesSheetState();
}

class _ManageExercisesSheetState extends State<_ManageExercisesSheet> {
  late Set<String> _selected;
  bool _isSaving = false;
  String? _errorMessage;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.currentSelected);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selected.length == widget.exerciseDefs.length) {
        _selected.clear();
      } else {
        _selected = Set<String>.from(widget.exerciseDefs.keys);
      }
      if (_selected.isNotEmpty) {
        _errorMessage = null;
      }
    });
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      setState(() => _errorMessage = 'select_at_least_one'.tr());
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.uid);
      
      // Update the user's selected exercises list.
      await userRef.update({'selectedExercises': _selected.toList()});

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('could_not_save'.tr(args: [e.toString()]))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allIds = widget.exerciseDefs.keys.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('manage_exercises_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('manage_exercises_desc'.tr(), style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _toggleSelectAll,
                  icon: Icon(
                    _selected.length == widget.exerciseDefs.length ? Icons.remove_circle_outline : Icons.check_circle_outline,
                    color: const Color(0xFFFFC72C),
                  ),
                  label: Text(
                    _selected.length == widget.exerciseDefs.length ? 'deselect_all_btn'.tr() : 'select_all_btn'.tr(),
                    style: const TextStyle(color: Color(0xFF444444)),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[  
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: Stack(
                children: [
                  Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    radius: const Radius.circular(8),
                    child: ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      itemCount: allIds.length,
                      itemBuilder: (context, index) {
                        final id = allIds[index];
                        final def = widget.exerciseDefs[id]!;
                        final isSelected = _selected.contains(id);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(def.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) { _selected.add(id); } else { _selected.remove(id); }
                              if (_selected.isNotEmpty) _errorMessage = null;
                            });
                          },
                          activeColor: const Color(0xFFFFC72C),
                          checkColor: Colors.black,
                          contentPadding: EdgeInsets.zero,
                        );
                      },
                    ),
                  ),
                  // Bottom fade — visually hints there are more items to scroll
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Theme.of(context).colorScheme.surface.withOpacity(0.0),
                              Theme.of(context).colorScheme.surface.withOpacity(0.85),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('save_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
