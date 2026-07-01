import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminAdBreakSettings extends StatefulWidget {
  const AdminAdBreakSettings({super.key});

  @override
  State<AdminAdBreakSettings> createState() => _AdminAdBreakSettingsState();
}

class _AdminAdBreakSettingsState extends State<AdminAdBreakSettings> {
  final _db = FirebaseFirestore.instance;
  bool _isUploading = false;
  
  DocumentReference get _adBreakRef => _db.collection('app_config').doc('ad_break');

  Future<void> _editMessage(String currentMessage) async {
    final controller = TextEditingController(text: currentMessage);
    final newMsg = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Ad Break Message'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Take a breather!'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()), 
            child: const Text('Save')
          ),
        ],
      ),
    );

    if (newMsg != null) {
      await _adBreakRef.set({'message': newMsg}, SetOptions(merge: true));
    }
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200, // Good size for backgrounds
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    setState(() => _isUploading = true);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      final ref = FirebaseStorage.instance.ref('ad_break/image.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      await _adBreakRef.set({'imageUrl': url}, SetOptions(merge: true));
      messenger.showSnackBar(const SnackBar(content: Text('Image uploaded successfully!')));
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('404') || msg.contains('-13010') || msg.contains('object-not-found')) {
        msg = 'Storage not enabled. Please click "Get Started" in Firebase Storage console.';
      } else if (msg.contains('unauthorized') || msg.contains('permission-denied')) {
        msg = 'Permission denied. Please configure Firebase Storage security rules.';
      } else {
        msg = 'Upload failed: $msg';
      }
      messenger.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeImage() async {
    await _adBreakRef.update({'imageUrl': FieldValue.delete()});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _adBreakRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final message = data['message'] as String? ?? 'Take a breather while we play this ad...';
        final imageUrl = data['imageUrl'] as String?;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ad Break Screen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Custom Message', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(message),
                      trailing: TextButton(
                        onPressed: () => _editMessage(message),
                        child: const Text('Edit'),
                      ),
                    ),
                    const Divider(),
                    const Text('Background Image', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (imageUrl != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: _removeImage,
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    if (imageUrl == null)
                      const Text('No background image selected.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _isUploading
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                              onPressed: _uploadImage,
                              icon: const Icon(Icons.upload),
                              label: const Text('Upload Image'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
