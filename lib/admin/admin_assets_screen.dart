import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_settings.dart';
import 'admin_ui.dart';

const List<Map<String, dynamic>> kDefaultSessionImages = [];

const List<Map<String, dynamic>> kDefaultSessionTips = [
  {"text": "couch_tip_1", "isKey": true, "enabled": true},
  {"text": "couch_tip_2", "isKey": true, "enabled": true},
  {"text": "couch_tip_3", "isKey": true, "enabled": true},
  {"text": "couch_tip_4", "isKey": true, "enabled": true},
  {"text": "couch_tip_5", "isKey": true, "enabled": true},
  {"text": "couch_tip_6", "isKey": true, "enabled": true},
  {"text": "couch_tip_7", "isKey": true, "enabled": true},
];

class AdminAssetsScreen extends StatefulWidget {
  const AdminAssetsScreen({super.key});

  @override
  State<AdminAssetsScreen> createState() => _AdminAssetsScreenState();
}

class _AdminAssetsScreenState extends State<AdminAssetsScreen> {
  final _db = FirebaseFirestore.instance;
  DocumentReference get _docRef => _db.collection('app_config').doc('session_assets');
  bool _isUploading = false;

  Future<void> _updateArray(String field, List<dynamic> newList) async {
    try {
      await _docRef.set({field: newList}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('update_failed'.tr(args: [e.toString()]))));
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
      final filename = 'session_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('session_images').child(filename);
      
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('upload_failed'.tr(args: [e.toString()]))));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Add by URL options removed

  void _showAddTipDialog(List<dynamic> currentTips) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('add_custom_tip'.tr()),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'enter_tip_text_hint'.tr()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel_btn'.tr())),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                final newList = List<dynamic>.from(currentTips);
                newList.add({
                  "text": ctrl.text.trim(),
                  "isKey": false, // custom texts are not localization keys
                  "enabled": true,
                });
                _updateArray('tips', newList);
              }
              Navigator.pop(ctx);
            },
            child: Text('add_btn'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesGrid(List<dynamic> images) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_assets_images_fab',
        onPressed: _isUploading ? null : () => _uploadImage(images),
        child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'admin_enabled_images_desc'.tr(),
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
        itemCount: images.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final noImagesActive = images.where((i) => i['enabled'] == true).isEmpty;
            return Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: noImagesActive ? PCColors.green : Colors.grey,
                  width: noImagesActive ? 2 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [PCColors.yellow, PCColors.yellowDark],
                      ),
                    ),
                  ),
                  if (!noImagesActive)
                    Container(color: Colors.black.withValues(alpha: 0.5)),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.black54,
                      child: Text(
                        'default_gradient_label'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final imageIndex = index - 1;
          final item = images[imageIndex] as Map<String, dynamic>;
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
                    ? Image.asset(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.error))
                    : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.error)),
                
                // Overlay for disabled state
                if (!enabled)
                  Container(color: Colors.black.withValues(alpha: 0.5)),

                // Top-left Delete (Only for uploaded images)
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
                            content: Text('delete_image_confirm'.tr()),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text('cancel_btn'.tr())),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: Text('delete_btn'.tr(), style: const TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final newList = List<dynamic>.from(images)..removeAt(imageIndex);
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
                        color: Colors.black45, // visibility on light images
                      ),
                      child: Icon(
                        enabled ? Icons.check_circle : Icons.circle_outlined,
                        color: enabled ? PCColors.green : Colors.white,
                      ),
                    ),
                    onPressed: () {
                      final newList = List<dynamic>.from(images);
                      newList[imageIndex] = Map<String, dynamic>.from(item)..['enabled'] = !enabled;
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

  Widget _buildTipsList(List<dynamic> tips) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_assets_tips_fab',
        onPressed: () => _showAddTipDialog(tips),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          final item = tips[index] as Map<String, dynamic>;
          final text = item['text'] as String? ?? '';
          final isKey = item['isKey'] as bool? ?? false;
          final enabled = item['enabled'] as bool? ?? true;

          final displayText = isKey ? text.tr() : text;

          return AdminUI.buildCard(
            context,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(displayText),
              subtitle: Text(isKey ? 'local_translation_label'.tr() : 'custom_text_label'.tr(), style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 20,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('delete_btn'.tr()),
                          content: Text('delete_tip_confirm'.tr()),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text('cancel_btn'.tr())),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: Text('delete_btn'.tr(), style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final newList = List<dynamic>.from(tips)..removeAt(index);
                        _updateArray('tips', newList);
                      }
                    },
                  ),
                  IconButton(
                    iconSize: 28,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      enabled ? Icons.check_circle : Icons.circle_outlined,
                      color: enabled ? PCColors.green : Colors.grey,
                    ),
                    onPressed: () {
                      final newList = List<dynamic>.from(tips);
                      newList[index] = Map<String, dynamic>.from(item)..['enabled'] = !enabled;
                      _updateArray('tips', newList);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AdminUI.buildAppBar(
          context,
          title: 'Session Backgrounds & Tips',
          bottom: TabBar(
            indicatorColor: Colors.blueGrey,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Background Overrides'),
              Tab(text: 'Tips'),
            ],
          ),
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
            
            final rawImages = data['images'] as List<dynamic>? ?? [];
            final images = rawImages.where((i) => i['isAsset'] != true).toList();
            final tips = data['tips'] as List<dynamic>? ?? kDefaultSessionTips;

            return TabBarView(
              children: [
                _buildImagesGrid(images),
                _buildTipsList(tips),
              ],
            );
          },
        ),
      ),
    );
  }
}
