import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Streaks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = userSnapshot.data!.data() as Map<String, dynamic>?;

          // ---- MOCK FALLBACK (for testing UI without real data) ----
          final selectedExercises = data == null || (data['selectedExercises'] ?? []).isEmpty
              ? ['pushups', 'squats', 'situps']
              : List<String>.from(data['selectedExercises']);

          final exercises = data == null
              ? {
                  'pushups': {'currentStreak': 47, 'lifetimeTotal': 12450},
                  'squats': {'currentStreak': 0, 'lifetimeTotal': 647},
                  'situps': {'currentStreak': 3, 'lifetimeTotal': 1210},
                }
              : Map<String, dynamic>.from(data['exercises'] ?? {});
          // ------------------------------------------------------------

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
            builder: (context, exerciseSnapshot) {
              // Map exercise id -> ExerciseItem (name, icon, unit)
              final exerciseDefs = <String, ExerciseItem>{};
              if (exerciseSnapshot.hasData) {
                for (final doc in exerciseSnapshot.data!.docs) {
                  exerciseDefs[doc.id] =
                      ExerciseItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                }
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: selectedExercises.length,
                itemBuilder: (context, index) {
                  final id = selectedExercises[index];
                  final exerciseData = Map<String, dynamic>.from(exercises[id] ?? {});
                  final streak = exerciseData['currentStreak'] ?? 0;
                  final lifetime = exerciseData['lifetimeTotal'] ?? 0;

                  // Fallback display name if exercise not yet in Firestore 'exercises' collection
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('$icon $lifetime Total $displayName ($unit)'),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              // Next step: navigate to exercise session screen
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
      ),
    );
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
}