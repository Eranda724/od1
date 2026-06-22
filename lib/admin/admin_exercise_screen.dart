import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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

  List<ExerciseMedia> _mediaItems = [];
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
    
    if (e != null) {
      _mediaItems = List.from(e.mediaItems);
    }
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

  Future<void> _pickMedia() async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickMedia();
    
    if (media != null) {
      final name = media.name.toLowerCase();
      final isVideo = name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.avi') || media.mimeType?.startsWith('video/') == true;
      setState(() {
        _mediaItems.add(ExerciseMedia(url: media.path, isVideo: isVideo));
      });
    }
  }

  void _removeMediaItem(int index) {
    setState(() {
      _mediaItems.removeAt(index);
    });
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
      List<ExerciseMedia> uploadedMedia = [];
      for (var m in _mediaItems) {
        if (m.url.startsWith('http') || m.url.startsWith('https')) {
          uploadedMedia.add(m);
        } else {
          final fileName = m.url.split('/').last.split('\\').last;
          final ref = FirebaseStorage.instance.ref().child('exercises').child(id).child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
          
          try {
            await ref.putFile(File(m.url));
          } catch (e) {
            throw Exception('Upload failed. Please ensure Firebase Storage is enabled in your Firebase Console and you have restarted the app. Details: $e');
          }
          
          final downloadUrl = await ref.getDownloadURL();
          uploadedMedia.add(ExerciseMedia(url: downloadUrl, isVideo: m.isVideo));
        }
      }

      final item = ExerciseItem(
        id: id,
        name: name,
        description: _descController.text.trim(),
        icon: widget.existing?.icon ?? '💪',
        unit: _unitController.text.trim(),
        defaultReps: int.tryParse(_repsController.text.trim()) ?? 0,
        defaultTimer: int.tryParse(_timerController.text.trim()) ?? 0,
        mediaItems: uploadedMedia,
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

            // Media
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Media Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Media'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_mediaItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No media items added. Exercise will show a placeholder.', style: TextStyle(color: Colors.grey)),
              ),
            for (int i = 0; i < _mediaItems.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_mediaItems[i].isVideo ? Icons.videocam : Icons.image, color: Colors.blueGrey),
                title: Text(_mediaItems[i].url.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_mediaItems[i].isVideo ? 'Video' : 'Image'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeMediaItem(i),
                ),
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
