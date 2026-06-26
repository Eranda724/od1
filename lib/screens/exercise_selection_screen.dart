import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
import 'home_screen.dart';

class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  final Set<String> _selected = {};
  bool _isSaving = false;

  Future<void> _saveAndContinue(List<ExerciseItem> exercises) async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one exercise')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    batch.set(userRef, {
      'email': user.email,
      'selectedExercises': _selected.toList(),
      'freezesAvailable': 0,
      'freezeLastRefillDate': null,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final id in _selected) {
      batch.set(userRef.collection('exercises').doc(id), {
        'currentStreak': 0,
        'lifetimeTotal': 0,
        'lastCompletedDate': null,
      }, SetOptions(merge: true));
    }

    await batch.commit();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Exercises')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final exercises = snapshot.data!.docs
              .map((doc) => ExerciseItem.fromMap(doc.id, doc.data() as Map<String, dynamic>))
              .toList();

          if (exercises.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No exercises available yet. Please contact support.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick the exercises you want to build a streak with:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: exercises.map((exercise) {
                      final isSelected = _selected.contains(exercise.id);
                      return CheckboxListTile(
                        title: Text('${exercise.icon}  ${exercise.name}'),
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(exercise.id);
                            } else {
                              _selected.remove(exercise.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () => _saveAndContinue(exercises),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Continue'),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}