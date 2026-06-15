import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('No data found'));
          }

          final selectedExercises = List<String>.from(data['selectedExercises'] ?? []);
          final exercises = Map<String, dynamic>.from(data['exercises'] ?? {});

          if (selectedExercises.isEmpty) {
            return const Center(child: Text('No exercises selected yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: selectedExercises.length,
            itemBuilder: (context, index) {
              final id = selectedExercises[index];
              final exerciseData = Map<String, dynamic>.from(exercises[id] ?? {});
              final streak = exerciseData['currentStreak'] ?? 0;
              final lifetime = exerciseData['lifetimeTotal'] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streak > 0 ? '🔥 $streak-Day $id Streak' : '😔 0-Day $id Streak',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('💪 $lifetime Total Reps'),
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
      ),
    );
  }
}