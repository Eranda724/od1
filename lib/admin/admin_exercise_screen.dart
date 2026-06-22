import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';

class AdminExerciseScreen extends StatefulWidget {
  final ExerciseItem? existing;

  const AdminExerciseScreen({super.key, this.existing});

  @override
  State<AdminExerciseScreen> createState() => _AdminExerciseScreenState();
}

class _AdminExerciseScreenState extends State<AdminExerciseScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _unitController;
  late TextEditingController _repsController;
  late TextEditingController _timerController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _unitController = TextEditingController(text: e?.unit ?? 'reps');
    _repsController = TextEditingController(text: (e?.defaultReps ?? 10).toString());
    _timerController = TextEditingController(text: (e?.defaultTimer ?? 30).toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _unitController.dispose();
    _repsController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final isEdit = widget.existing != null;
    final id = isEdit 
        ? widget.existing!.id 
        : name.toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
        
    if (id.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final item = ExerciseItem(
        id: id,
        name: name,
        description: _descController.text.trim(),
        icon: widget.existing?.icon ?? '💪',
        unit: _unitController.text.trim(),
        defaultReps: int.tryParse(_repsController.text.trim()) ?? 0,
        defaultTimer: int.tryParse(_timerController.text.trim()) ?? 0,
        mediaItems: [],
      );

      await FirebaseFirestore.instance
          .collection('exercises')
          .doc(id)
          .set(item.toMap(), SetOptions(merge: true));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Exercise' : 'Add Exercise'),
        backgroundColor: const Color(0xFFFFC72C),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_rounded, size: 28),
              onPressed: _save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info
            const Text('Basic Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Exercise Name (e.g. Push-Ups)', border: OutlineInputBorder()),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),

            const SizedBox(height: 24),

            // Settings
            const Text('Default Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repsController,
              decoration: const InputDecoration(labelText: 'Default Reps', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _timerController,
              decoration: const InputDecoration(labelText: 'Default Timer (s)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(labelText: 'Unit (reps/s)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text('Description (Optional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                initiallyExpanded: _descController.text.isNotEmpty,
                tilePadding: EdgeInsets.zero,
                children: [
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Exercise Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
