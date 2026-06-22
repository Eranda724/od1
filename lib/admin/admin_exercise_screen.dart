import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
import '../models/exercise_icons.dart';

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
  late TextEditingController _repsController;
  late TextEditingController _timerController;
  late TextEditingController _daysController;

  bool _isLoading = false;
  bool _isDetailsCustom = false;
  String _selectedIcon = '💪';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _selectedIcon = e?.icon ?? '💪';
    if (!exerciseEmojis.contains(_selectedIcon)) _selectedIcon = '💪';
    _repsController = TextEditingController(text: (e?.defaultReps ?? 0).toString());
    _timerController = TextEditingController(text: (e?.defaultTimer ?? 0).toString());
    _daysController = TextEditingController(text: (e?.defaultDays ?? 0).toString());

    if ((e?.defaultReps ?? 0) > 0 || (e?.defaultTimer ?? 0) > 0 || (e?.defaultDays ?? 0) > 0) {
      _isDetailsCustom = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _repsController.dispose();
    _timerController.dispose();
    _daysController.dispose();
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
        icon: _selectedIcon,
        unit: 'reps',
        defaultReps: _isDetailsCustom ? (int.tryParse(_repsController.text.trim()) ?? 0) : 0,
        defaultTimer: _isDetailsCustom ? (int.tryParse(_timerController.text.trim()) ?? 0) : 0,
        defaultDays: _isDetailsCustom ? (int.tryParse(_daysController.text.trim()) ?? 0) : 0,
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
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedIcon,
              decoration: const InputDecoration(labelText: 'Exercise Icon', border: OutlineInputBorder()),
              items: exerciseEmojis.map((emoji) {
                return DropdownMenuItem(
                  value: emoji,
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedIcon = val);
                }
              },
            ),

            const SizedBox(height: 24),

            // Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isDetailsCustom = !_isDetailsCustom;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDetailsCustom ? const Color(0xFFFFC72C) : Colors.grey.shade200,
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  child: Text(_isDetailsCustom ? 'Save' : 'Edit', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailCounter('Reps', _repsController),
            const SizedBox(height: 16),
            _buildDetailCounter('Timer', _timerController),
            const SizedBox(height: 16),
            _buildDetailCounter('Days', _daysController),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC72C),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Save Exercise', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCounter(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: _isDetailsCustom ? Colors.black : Colors.grey,
          onPressed: _isDetailsCustom ? () {
            int val = int.tryParse(controller.text) ?? 0;
            if (val > 0) controller.text = (val - 1).toString();
          } : null,
        ),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            enabled: _isDetailsCustom,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: const OutlineInputBorder(),
              disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
              filled: !_isDetailsCustom,
              fillColor: Colors.grey.shade200,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: _isDetailsCustom ? Colors.black : Colors.grey,
          onPressed: _isDetailsCustom ? () {
            int val = int.tryParse(controller.text) ?? 0;
            controller.text = (val + 1).toString();
          } : null,
        ),
      ],
    );
  }
}
