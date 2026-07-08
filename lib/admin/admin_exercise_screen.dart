import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/exercise_item.dart';
import '../models/exercise_icons.dart';
import '../app_settings.dart';

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
  String _selectedIcon = 'default';

  File? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _selectedIcon = e?.icon ?? 'default';
    if (!exerciseIcons.any((item) => item.id == _selectedIcon)) {
      _selectedIcon = 'default';
    }
    _repsController = TextEditingController(text: (e?.defaultReps ?? 0).toString());
    _timerController = TextEditingController(text: (e?.defaultTimer ?? 0).toString());
    _daysController = TextEditingController(text: (e?.defaultDays ?? 0).toString());

    if ((e?.defaultReps ?? 0) > 0 || (e?.defaultTimer ?? 0) > 0 || (e?.defaultDays ?? 0) > 0) {
      _isDetailsCustom = true;
    }

    _existingImageUrl = (e?.mediaItems.isNotEmpty == true) ? e!.mediaItems.first.url : null;
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
      List<ExerciseMedia> media = widget.existing?.mediaItems.toList() ?? [];

      // If a new image was selected from gallery, upload it
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance.ref('exercises/$id/thumbnail.jpg');
        await ref.putFile(_selectedImage!);
        final url = await ref.getDownloadURL();
        media = [ExerciseMedia(url: url, isVideo: false)];
      } 
      // If image was removed
      else if (_existingImageUrl == null) {
        media = [];
      }

      final item = ExerciseItem(
        id: id,
        name: name,
        description: _descController.text.trim(),
        icon: _selectedIcon,
        unit: 'reps',
        defaultReps: _isDetailsCustom ? (int.tryParse(_repsController.text.trim()) ?? 0) : 0,
        defaultTimer: _isDetailsCustom ? (int.tryParse(_timerController.text.trim()) ?? 0) : 0,
        defaultDays: _isDetailsCustom ? (int.tryParse(_daysController.text.trim()) ?? 0) : 0,
        mediaItems: media,
      );

      await FirebaseFirestore.instance
          .collection('exercises')
          .doc(id)
          .set(item.toMap(), SetOptions(merge: true));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('404') || msg.contains('-13010') || msg.contains('object-not-found')) {
          msg = 'Storage not enough or not enabled. Please click "Get Started" in Firebase Storage console.';
        } else if (msg.contains('unauthorized') || msg.contains('permission-denied')) {
          msg = 'Permission denied. Please configure Firebase Storage security rules.';
        } else {
          msg = 'Failed to save: $msg';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
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
        backgroundColor: context.appBarColor,
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
            Row(
              children: [
                const Expanded(
                  child: Text('Exercise Icon', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedIcon,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      // ── Material Icons section ──────────────────────────────
                      const DropdownMenuItem<String>(
                        enabled: false,
                        value: '__header_icons__',
                        child: Text('Material Icons', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      ...exerciseIcons.map((item) {
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Row(
                            children: [
                              Icon(item.icon, size: 20),
                              const SizedBox(width: 8),
                              Text(item.label, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }),
                      // ── Emoji section ───────────────────────────────────────
                      const DropdownMenuItem<String>(
                        enabled: false,
                        value: '__header_emojis__',
                        child: Text('Emojis', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      ...exerciseEmojis.map((emoji) {
                        return DropdownMenuItem<String>(
                          value: emoji,
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedIcon = val);
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Text('Custom Image (Overrides Icon)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!, width: 64, height: 64, fit: BoxFit.cover),
                  )
                else if (_existingImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: _existingImageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image, color: context.textSecondary),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload),
                        label: const Text('Upload Image'),
                        onPressed: () async {
                          final img = await _picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 75,
                          );
                          if (img != null) {
                            setState(() {
                              _selectedImage = File(img.path);
                              _existingImageUrl = null;
                            });
                          }
                        },
                      ),
                      if (_selectedImage != null || _existingImageUrl != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedImage = null;
                              _existingImageUrl = null;
                            });
                          },
                          child: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
              ],
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
                    backgroundColor: _isDetailsCustom
                        ? PCColors.yellow
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: context.textPrimary,
                    elevation: 0,
                  ),
                  child: Text(_isDetailsCustom ? 'Save' : 'Edit', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailCounter('Reps', _repsController),
            const SizedBox(height: 16),
            _buildDetailCounter('Timer(seconds)', _timerController),
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
          color: _isDetailsCustom ? context.textPrimary : context.textSecondary,
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
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: context.borderColor),
              ),
              filled: !_isDetailsCustom,
              fillColor: context.cardColor,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: _isDetailsCustom ? context.textPrimary : context.textSecondary,
          onPressed: _isDetailsCustom ? () {
            int val = int.tryParse(controller.text) ?? 0;
            controller.text = (val + 1).toString();
          } : null,
        ),
      ],
    );
  }
}

