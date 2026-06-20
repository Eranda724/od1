import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
export '../models/exercise_item.dart' show ExerciseMedia;
import 'exercise_start_screen.dart';

class ExerciseScreen extends StatelessWidget {
  final User? user;
  const ExerciseScreen({super.key, required this.user});

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = userSnapshot.data!.data() as Map<String, dynamic>?;

        final selectedExercises =
            data == null || (data['selectedExercises'] ?? []).isEmpty
                ? ['pushups', 'squats', 'situps']
                : List<String>.from(data['selectedExercises']);

        final exercises = data == null
            ? {
                'pushups': {'currentStreak': 47, 'lifetimeTotal': 12450},
                'squats': {'currentStreak': 0, 'lifetimeTotal': 647},
                'situps': {'currentStreak': 3, 'lifetimeTotal': 1210},
              }
            : Map<String, dynamic>.from(data['exercises'] ?? {});

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

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: selectedExercises.length,
              itemBuilder: (context, index) {
                final id = selectedExercises[index];
                final exerciseData =
                    Map<String, dynamic>.from(exercises[id] ?? {});
                final streak = exerciseData['currentStreak'] ?? 0;
                final lifetime = exerciseData['lifetimeTotal'] ?? 0;

                final def = exerciseDefs[id];
                final displayName = def?.name ?? _fallbackName(id);
                final icon = def?.icon ?? '💪';
                final unit = def?.unit ?? 'reps';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          streak > 0
                              ? '🔥 $streak-Day $displayName Streak'
                              : '😔 0-Day $displayName Streak',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('$icon $lifetime Total $displayName ($unit)'),
                        const SizedBox(height: 12),
                        ElevatedButton(
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
                                  // Use Firestore media list if available,
                                  // otherwise fall back to a mock list of multiple items
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
                          child: const Text('Start Exercise'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
