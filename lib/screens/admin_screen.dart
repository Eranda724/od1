import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  void _showExerciseDialog(BuildContext context, {ExerciseItem? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final iconController = TextEditingController(text: existing?.icon ?? '');
    final unitController = TextEditingController(text: existing?.unit ?? 'reps');
    final idController = TextEditingController(text: existing?.id ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Exercise' : 'Edit Exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              enabled: existing == null,
              decoration: const InputDecoration(
                labelText: 'ID (e.g. pushups, no spaces)',
              ),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Display Name (e.g. Push-Ups)'),
            ),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(labelText: 'Icon (emoji, e.g. 💪)'),
            ),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(labelText: 'Unit (e.g. reps)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = idController.text.trim();
              if (id.isEmpty || nameController.text.trim().isEmpty) return;

              await FirebaseFirestore.instance.collection('exercises').doc(id).set({
                'name': nameController.text.trim(),
                'icon': iconController.text.trim(),
                'unit': unitController.text.trim(),
              });

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin — Manage Exercises')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExerciseDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final exercises = snapshot.data!.docs
              .map((doc) => ExerciseItem.fromMap(doc.id, doc.data() as Map<String, dynamic>))
              .toList();

          if (exercises.isEmpty) {
            return const Center(child: Text('No exercises yet. Tap + to add one.'));
          }

          return ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return ListTile(
                leading: Text(exercise.icon, style: const TextStyle(fontSize: 24)),
                title: Text(exercise.name),
                subtitle: Text('ID: ${exercise.id}  •  Unit: ${exercise.unit}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showExerciseDialog(context, existing: exercise),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('exercises')
                            .doc(exercise.id)
                            .delete();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}