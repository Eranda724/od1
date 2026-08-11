import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_settings.dart';
import 'admin_ui.dart';

const List<Map<String, dynamic>> kDefaultCelebrationImages = [
  {"url": "assets/images/p1.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p2.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p3.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p4.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p5.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p6.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p7.png", "isAsset": true, "enabled": true},
];

class AdminCelebrationAssetsScreen extends StatefulWidget {
  const AdminCelebrationAssetsScreen({super.key});

  @override
  State<AdminCelebrationAssetsScreen> createState() => _AdminCelebrationAssetsScreenState();
}

class _AdminCelebrationAssetsScreenState extends State<AdminCelebrationAssetsScreen> {
  final _db = FirebaseFirestore.instance;
  DocumentReference get _docRef => _db.collection('app_config').doc('celebration_assets');
  bool _isUploading = false;

  Future<void> _updateArray(String field, List<dynamic> newList) async {
    try {
      await _docRef.set({field: newList}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _uploadImage(List<dynamic> currentImages) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(pickedFile.path);
      final filename = 'celeb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('celebration_images').child(filename);
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final newList = List<dynamic>.from(currentImages);
      newList.add({
        "url": downloadUrl,
        "isAsset": false,
        "enabled": true,
      });
      await _updateArray('images', newList);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  // Add by URL options removed as requested

  Widget _buildImagesGrid(List<dynamic> images) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : () => _uploadImage(images),
        child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Add images to be shown on the celebration screen. They should be general and not contain exercise names. If none are enabled, default app assets will be used.",
              style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final item = images[index] as Map<String, dynamic>;
                final url = item['url'] as String? ?? '';
                final isAsset = item['isAsset'] as bool? ?? false;
                final enabled = item['enabled'] as bool? ?? true;

                return Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: enabled ? PCColors.green : Colors.grey,
                      width: enabled ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      isAsset
                          ? Image.asset(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error))
                          : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.error)),
                      
                      // Overlay for disabled state
                      if (!enabled)
                        Container(color: Colors.black.withValues(alpha: 0.5)),

                      // Top-left Delete
                      // Top-left Delete (Only for uploaded images, not default assets)
                      if (!isAsset)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: IconButton(
                            iconSize: 20,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text('delete_btn'.tr()),
                                  content: const Text('Are you sure you want to delete this image?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text('cancel_btn'.tr())),
                                    TextButton(onPressed: () => Navigator.pop(c, true), child: Text('delete_btn'.tr(), style: const TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final newList = List<dynamic>.from(images)..removeAt(index);
                                _updateArray('images', newList);
                              }
                            },
                          ),
                        ),
                      
                      // Top-right Toggle (Round Tick)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          iconSize: 28,
                          padding: EdgeInsets.zero,
                          icon: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                            ),
                            child: Icon(
                              enabled ? Icons.check_circle : Icons.circle_outlined,
                              color: enabled ? PCColors.green : Colors.white,
                            ),
                          ),
                          onPressed: () {
                            final newList = List<dynamic>.from(images);
                            newList[index] = Map<String, dynamic>.from(item)..['enabled'] = !enabled;
                            _updateArray('images', newList);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AdminUI.buildAppBar(
        context,
        title: 'Celebration Image Bank',
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('error_loading'.tr(args: [snapshot.error.toString()])));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final rawImages = data['images'] as List<dynamic>? ?? kDefaultCelebrationImages;
          final images = rawImages.toList();

          return _buildImagesGrid(images);
        },
      ),
    );
  }
}
