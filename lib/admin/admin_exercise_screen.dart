import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/exercise_item.dart';
import '../app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:translator/translator.dart';
import 'admin_ui.dart';

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

  File? _labelImageFile;
  String? _existingLabelImage;

  File? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _existingLabelImage = e?.labelImage;
    _repsController = TextEditingController(
      text: (e?.defaultReps ?? 0).toString(),
    );
    _timerController = TextEditingController(
      text: (e?.defaultTimer ?? 0).toString(),
    );
    _daysController = TextEditingController(
      text: (e?.defaultDays ?? 0).toString(),
    );

    if ((e?.defaultReps ?? 0) > 0 ||
        (e?.defaultTimer ?? 0) > 0 ||
        (e?.defaultDays ?? 0) > 0) {
      _isDetailsCustom = true;
    }

    _existingImageUrl = (e?.mediaItems.isNotEmpty == true)
        ? e!.mediaItems.first.url
        : null;
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
        : name
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), '_')
              .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    if (id.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final originalDesc = _descController.text.trim();
      Map<String, String>? descMap;

      if (originalDesc.isNotEmpty) {
        descMap = {};
        final translator = GoogleTranslator();
        // Translate to 'en' to detect the source language
        final translationResult = await translator.translate(
          originalDesc,
          to: 'en',
        );
        final sourceCode = translationResult.sourceLanguage.code;

        final targetLangs = ['en', 'fr', 'es'];

        for (final lang in targetLangs) {
          if (sourceCode == lang) {
            descMap[lang] = originalDesc;
          } else {
            final result = await translator.translate(originalDesc, to: lang);
            descMap[lang] = result.text;
          }
        }
      }

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

      String? finalLabelImage = _existingLabelImage;
      if (_labelImageFile != null) {
        final ref = FirebaseStorage.instance.ref('exercises/$id/label.jpg');
        await ref.putFile(_labelImageFile!);
        finalLabelImage = await ref.getDownloadURL();
      } else if (_existingLabelImage == null) {
        finalLabelImage = null; // User removed the label image
      }

      final item = ExerciseItem(
        id: id,
        name: name,
        description: originalDesc,
        descriptions: descMap,
        icon:
            widget.existing?.icon ??
            '💪', // Keep legacy icon intact for older versions
        labelImage: finalLabelImage,
        unit: 'reps',
        defaultReps: _isDetailsCustom
            ? (int.tryParse(_repsController.text.trim()) ?? 0)
            : 0,
        defaultTimer: _isDetailsCustom
            ? (int.tryParse(_timerController.text.trim()) ?? 0)
            : 0,
        defaultDays: _isDetailsCustom
            ? (int.tryParse(_daysController.text.trim()) ?? 0)
            : 0,
        mediaItems: media,
      );

      await FirebaseFirestore.instance
          .collection('exercises')
          .doc(id)
          .set(item.toMap(), SetOptions(merge: true));

      // For new exercises (not edits), push the new exercise id into every
      // user's selectedExercises list so it appears enabled in their Manage
      // Exercises sheet and shows in their to-do list.
      // Users who have never configured (no selectedExercises field) already
      // see all exercises by default, so we only update those who have the
      // field set.
      if (!isEdit) {
        final usersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('selectedExercises', isNotEqualTo: null)
            .get();

        if (usersSnap.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final userDoc in usersSnap.docs) {
            batch.update(userDoc.reference, {
              'selectedExercises': FieldValue.arrayUnion([id]),
            });
            // Also seed the exercise stats doc so the card can load smoothly.
            batch.set(
              userDoc.reference.collection('exercises').doc(id),
              {
                'currentStreak': 0,
                'lifetimeTotal': 0,
                'lastCompletedDate': null,
              },
              SetOptions(merge: true),
            );
          }
          await batch.commit();
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('404') ||
            msg.contains('-13010') ||
            msg.contains('object-not-found')) {
          msg = 'storage_error_message'.tr();
        } else if (msg.contains('unauthorized') ||
            msg.contains('permission-denied')) {
          msg = 'permission_error_message'.tr();
        } else {
          msg = 'failed_to_save'.tr(args: [msg]);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AdminUI.buildAppBar(
        context,
        title: isEdit ? 'edit_exercise_title'.tr() : 'add_exercise_title'.tr(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info
            Text(
              'basic_info_title'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'exercise_name_label'.tr(),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v!.trim().isEmpty ? 'required_error'.tr() : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Exercise Label (Icon Image)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '1:1 Aspect Ratio Recommended',
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'Recommended size: 1:1 Aspect Ratio',
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: context.cardColor,
                    ),
                    child: _labelImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.file(
                              _labelImageFile!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : _existingLabelImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: CachedNetworkImage(
                              imageUrl: _existingLabelImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.image, color: context.textSecondary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Label'),
                        onPressed: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 75,
                          );
                          if (picked != null) {
                            setState(() => _labelImageFile = File(picked.path));
                          }
                        },
                      ),
                      if (_labelImageFile != null ||
                          _existingLabelImage != null) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 18,
                          ),
                          label: const Text(
                            'Remove',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () {
                            setState(() {
                              _labelImageFile = null;
                              _existingLabelImage = null;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text(
              'Main Image',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              )
            else if (_existingImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _existingImageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.image,
                  color: context.textSecondary,
                  size: 48,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload),
                  label: Text('upload_image_btn'.tr()),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _existingImageUrl = null;
                        });
                      },
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            Text(
              'exercise_desc_label'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              maxLines: 2,
            ),

            // Details (Exercise Settings)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text(
                  'Exercise Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                initiallyExpanded: _isDetailsCustom,
                tilePadding: EdgeInsets.zero,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ), // Spacer to push button right
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isDetailsCustom = !_isDetailsCustom;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDetailsCustom
                              ? PCColors.yellow
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          foregroundColor: context.textPrimary,
                          elevation: 0,
                        ),
                        child: Text(
                          _isDetailsCustom ? 'save_btn'.tr() : 'edit_btn'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDetailCounter('reps_label'.tr(), _repsController),
                  const SizedBox(height: 8),
                  _buildDetailCounter(
                    'timer_seconds_label'.tr(),
                    _timerController,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailCounter('days_label'.tr(), _daysController),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC72C),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'save_exercise_btn'.tr(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: _isDetailsCustom ? context.textPrimary : context.textSecondary,
          onPressed: _isDetailsCustom
              ? () {
                  int val = int.tryParse(controller.text) ?? 0;
                  if (val > 0) controller.text = (val - 1).toString();
                }
              : null,
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
          onPressed: _isDetailsCustom
              ? () {
                  int val = int.tryParse(controller.text) ?? 0;
                  controller.text = (val + 1).toString();
                }
              : null,
        ),
      ],
    );
  }
}
