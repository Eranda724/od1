import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
import 'home_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  final Set<String> _selected = {};
  bool _isSaving = false;

  Future<void> _saveAndContinue(List<ExerciseItem> exercises) async {
    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    batch.set(userRef, {
      'email': user.email,
      // Do NOT write selectedExercises — null means "all selected" (default).
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
      appBar: AppBar(title: Text('choose_exercises_title'.tr())),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('error_loading'.tr(args: [snapshot.error.toString()])));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final exercises = snapshot.data!.docs
              .map((doc) => ExerciseItem.fromMap(doc.id, doc.data() as Map<String, dynamic>))
              .toList();

          // Pre-tick all exercises so the user starts with everything selected.
          if (_selected.isEmpty) {
            for (final e in exercises) {
              _selected.add(e.id);
            }
          }

          if (exercises.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'no_exercises_available'.tr(),
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
                Text(
                  'pick_exercises_desc'.tr(),
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
                        child: Text('continue_btn'.tr()),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}