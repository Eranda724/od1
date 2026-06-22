import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
export '../models/exercise_item.dart' show ExerciseMedia;
import 'exercise_start_screen.dart';
import '../app_settings.dart';

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
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user?.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = userSnapshot.data!.data() as Map<String, dynamic>?;

        final selectedExercises = List<String>.from(data?['selectedExercises'] ?? []);
        final exercises = Map<String, dynamic>.from(data?['exercises'] ?? {});

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('exercises')
              .snapshots(),
          builder: (context, exerciseSnapshot) {
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

            for (final id in selectedExercises) {
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

              final def = exerciseDefs[id];
              final displayName = def?.name ?? _fallbackName(id);
              final icon = def?.icon ?? '💪';
              final unit = def?.unit ?? 'reps';

              return Card(
                margin: _settings.isGridView ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDone ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              streak > 0
                                  ? '🔥 $streak-Day\n$displayName Streak'
                                  : '😔 0-Day\n$displayName Streak',
                              style: TextStyle(
                                  fontSize: _settings.isGridView ? 14 : 18, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDone)
                            const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                      if (_settings.isGridView) const Spacer() else const SizedBox(height: 8),
                      Text('$icon $lifetime Total ($unit)', style: TextStyle(fontSize: _settings.isGridView ? 12 : 14)),
                      if (_settings.isGridView) const Spacer() else const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
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
                                  mediaItems: (def?.mediaItems.isNotEmpty == true)
                                      ? def!.mediaItems
                                      : [
                                          const ExerciseMedia(
                                            url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
                                            isVideo: true,
                                          ),
                                          const ExerciseMedia(
                                            url: 'https://picsum.photos/seed/workout1/800/600',
                                            isVideo: false,
                                          ),
                                          const ExerciseMedia(
                                            url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
                                            isVideo: true,
                                          ),
                                        ],
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(isDone ? 'Do Again' : 'Start', style: TextStyle(fontSize: _settings.isGridView ? 12 : 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
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
                    Column(
                      children: ids.map((id) => buildCard(id, isDone)).toList(),
                    ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (todoExercises.isEmpty && doneExercises.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32.0),
                    child: Center(child: Text('No exercises selected.')),
                  ),
                buildSection('To Do', todoExercises, false, Colors.black),
                buildSection('Completed Today', doneExercises, true, Colors.green),
              ],
            );
          },
        );
      },
    );
  }
}
