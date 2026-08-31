import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/network_or_asset_image.dart';
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

const List<Map<String, dynamic>> kDefaultExerciseCongratsImages = [
  {"url": "assets/images/login.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/register.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/streak.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p1.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p2.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p3.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p4.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p5.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p6.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p7.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/congrads_po1.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/congrads_po2.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/congrads_po3.png", "isAsset": true, "enabled": true},
];

const List<Map<String, dynamic>> kDefaultDailySummaryImages = [
  {"url": "assets/images/login.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/register.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/streak.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p1.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p2.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p3.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p4.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p5.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p6.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p7.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/fire-congrads.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/congrads_po1.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/congrads_po2.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/congrads_po3.png", "isAsset": true, "enabled": true},
];

const List<Map<String, dynamic>> kDefaultStreakCharacterImages = [
  {"url": "assets/images/login.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/register.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/streak.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p1.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p2.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p3.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p4.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p5.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p6.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/p7.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/congrads_po1.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/congrads_po2.png", "isAsset": true, "enabled": true},
  {"url": "assets/images/congrads_po3.png", "isAsset": true, "enabled": true},
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AdminCelebrationAssetsScreen extends StatefulWidget {
  const AdminCelebrationAssetsScreen({super.key});

  @override
  State<AdminCelebrationAssetsScreen> createState() =>
      _AdminCelebrationAssetsScreenState();
}

class _AdminCelebrationAssetsScreenState
    extends State<AdminCelebrationAssetsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _db = FirebaseFirestore.instance;

  // Each bank lives in a separate Firestore field inside the same doc.
  DocumentReference get _docRef =>
      _db.collection('app_config').doc('image_bank');

  bool _isUploading = false;
  bool _isLoading = true;
  bool _hasChanges = false;
  String? _error;

  Map<String, List<dynamic>> _localData = {};

  static const List<_BankDef> _banks = [
    _BankDef(
      label: 'streak_screen',
      field: 'streak_character',
      storageFolder: 'celebration_images/streak_character',
      defaults: kDefaultStreakCharacterImages,
    ),
    _BankDef(
      label: 'congrats_screen',
      field: 'exercise_congrats',
      storageFolder: 'celebration_images/exercise_congrats',
      defaults: kDefaultExerciseCongratsImages,
    ),
    _BankDef(
      label: 'summary_screen',
      field: 'daily_summary',
      storageFolder: 'celebration_images/daily_summary',
      defaults: kDefaultDailySummaryImages,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _banks.length, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final snap = await _docRef.get();
      final data = snap.data() as Map<String, dynamic>? ?? {};
      _localData = {};
      for (final bank in _banks) {
        _localData[bank.field] = List<dynamic>.from(
          data[bank.field] ?? bank.defaults,
        );
      }
      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  void _updateLocalField(String field, List<dynamic> newList) {
    setState(() {
      _localData[field] = newList;
      _hasChanges = true;
    });
  }

  Future<void> _saveAll() async {
    setState(() => _isUploading = true);
    try {
      await _docRef.set(_localData, SetOptions(merge: true));
      setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('changes_saved_successfully'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_failed'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadImage(
    String field,
    String storageFolder,
    List<dynamic> current,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(picked.path);
      final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child(storageFolder)
          .child(filename);
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();

      final newList = List<dynamic>.from(current);
      newList.add({"url": url, "isAsset": false, "enabled": true});
      _updateLocalField(field, newList);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('upload_failed'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── GRID VIEW (per tab) ──────────────────────────────────────────────────

  Widget _buildGrid(_BankDef bank, List<dynamic> images) {
    images.sort((a, b) {
      final aEnabled = (a as Map<String, dynamic>)['enabled'] == true;
      final bEnabled = (b as Map<String, dynamic>)['enabled'] == true;
      if (aEnabled && !bEnabled) return -1;
      if (!aEnabled && bEnabled) return 1;
      return 0;
    });

    return Scaffold(
      key: ValueKey(bank.field),
      // FAB to upload new image
      floatingActionButton: FloatingActionButton(
        heroTag: bank.field,
        backgroundColor: const Color(0xFFFFC72C),
        onPressed: _isUploading
            ? null
            : () => _uploadImage(bank.field, bank.storageFolder, images),
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'tap_to_enable_disable'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Select All / Deselect All toggle
                Builder(
                  builder: (context) {
                    final allEnabled = images.every(
                      (i) => (i as Map<String, dynamic>)['enabled'] == true,
                    );
                    return TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      icon: Icon(
                        allEnabled
                            ? Icons.check_box_rounded
                            : Icons.indeterminate_check_box_rounded,
                        size: 20,
                        color: Colors.blue,
                      ),
                      label: Text(
                        allEnabled ? 'deselect_all'.tr() : 'select_all'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      onPressed: () {
                        final newEnabled = !allEnabled;
                        final newList = images
                            .map(
                              (i) => Map<String, dynamic>.from(
                                i as Map<String, dynamic>,
                              )..['enabled'] = newEnabled,
                            )
                            .toList();
                        _updateLocalField(bank.field, newList);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final item = images[index] as Map<String, dynamic>;
                final url = item['url'] as String? ?? '';
                final isAsset = item['isAsset'] as bool? ?? false;
                final enabled = item['enabled'] as bool? ?? true;

                return Card(
                  elevation: 3,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: enabled ? PCColors.green : Colors.grey.shade400,
                      width: enabled ? 2.5 : 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      NetworkOrAssetImage(
                        url,
                        fit: BoxFit.contain,
                      ),

                      // Disabled overlay
                      if (!enabled)
                        Container(color: Colors.black.withValues(alpha: 0.45)),

                      // Default badge
                      if (isAsset)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'default_caps'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                      // Delete (uploaded only)
                      if (!isAsset)
                        Positioned(
                          top: 2,
                          left: 2,
                          child: InkWell(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text('delete_btn'.tr()),
                                  content: Text('delete_image_confirm'.tr()),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: Text('cancel_btn'.tr()),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: Text(
                                        'delete_btn'.tr(),
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final newList = List<dynamic>.from(images)
                                  ..removeAt(index);
                                _updateLocalField(bank.field, newList);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                            ),
                          ),
                        ),

                      // Enable/Disable toggle
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () {
                            final newList = List<dynamic>.from(images);
                            newList[index] = Map<String, dynamic>.from(item)
                              ..['enabled'] = !enabled;
                            _updateLocalField(bank.field, newList);
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              enabled
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: enabled ? PCColors.green : Colors.white,
                              size: 26,
                            ),
                          ),
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

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AdminUI.buildAppBar(
          context,
          title: 'image_bank_title'.tr(),
          actions: [
            if (_hasChanges)
              TextButton.icon(
                onPressed: _isUploading ? null : _saveAll,
                icon: _isUploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text('save_btn'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFFC72C),
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: _banks.map((b) => Tab(text: b.label.tr())).toList(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text('error_loading'.tr(args: [_error ?? ''])))
            : TabBarView(
                controller: _tabController,
                children: _banks.map((bank) {
                  final raw = _localData[bank.field] ?? bank.defaults;
                  return _buildGrid(bank, raw.toList());
                }).toList(),
              ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────

class _BankDef {
  final String label;
  final String field;
  final String storageFolder;
  final List<Map<String, dynamic>> defaults;

  const _BankDef({
    required this.label,
    required this.field,
    required this.storageFolder,
    required this.defaults,
  });
}
