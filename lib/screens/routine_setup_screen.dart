import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/exercise_item.dart';
import '../main.dart';

class RoutineSetupScreen extends StatefulWidget {
  const RoutineSetupScreen({super.key});

  @override
  State<RoutineSetupScreen> createState() => _RoutineSetupScreenState();
}

class _RoutineSetupScreenState extends State<RoutineSetupScreen> {
  Set<String> _selected = {};
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _saveRoutine() async {
    if (_selected.isEmpty) {
      setState(() => _errorMessage = 'select_at_least_one'.tr());
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.set({
        'hasRoutine': true,
        'selectedExercises': _selected.toList(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const StartRouter()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('error_loading'.tr(args: [snapshot.error.toString()])));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFFFC72C)));
            }

            final exerciseDefs = <String, ExerciseItem>{};
            for (final doc in snapshot.data!.docs) {
              exerciseDefs[doc.id] = ExerciseItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
            }
            final allIds = exerciseDefs.keys.toList();

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Text(
                    'welcome'.tr(),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'create_routine_desc'.tr(),
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.builder(
                          itemCount: allIds.length,
                          itemBuilder: (context, index) {
                            final id = allIds[index];
                            final def = exerciseDefs[id]!;
                            final isSelected = _selected.contains(id);
                            
                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(def.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              subtitle: def.description != null && def.description!.isNotEmpty
                                  ? Text(def.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                                  : null,
                              activeColor: const Color(0xFFFFC72C),
                              checkColor: Colors.black,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                  if (_selected.isNotEmpty) _errorMessage = null;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveRoutine,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC72C),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Text(
                              'save_routine'.tr(),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
