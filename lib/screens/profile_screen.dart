import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';
import 'package:image_picker/image_picker.dart';

import '../app_settings.dart';
import '../services/account_deletion_service.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;

  const ProfileScreen({super.key, this.isTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // FORMS

  final _formKeyProfile = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();

  // CONTROLLERS

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _deletePasswordController = TextEditingController();

  // STATE

  bool _isLoadingProfile = false;
  bool _isLoadingPassword = false;
  bool _isLoadingDelete = false;

  bool _isSuperAdmin = false;

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _obscureDeletePassword = true;

  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;

  bool _isUploadingImage = false;

  Timer? _debounceTimer;

  final ImagePicker _picker = ImagePicker();

  // INIT

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';

      _checkSuperAdmin(user.uid);
    }
  }

  // DISPOSE

  @override
  void dispose() {
    _debounceTimer?.cancel();

    _displayNameController.dispose();
    _emailController.dispose();

    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _deletePasswordController.dispose();

    super.dispose();
  }

  // PROFILE IMAGE

  Future<void> _pickAndUploadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final file = File(pickedFile.path);

      final ref = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/profile.jpg',
      );

      await ref.putFile(file);

      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': downloadUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  // SUPER ADMIN

  Future<void> _checkSuperAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted || !doc.exists) return;

      setState(() {
        _isSuperAdmin = doc.data()?['adminRole'] == 'super';
      });
    } catch (_) {}
  }

  // USERNAME CHECK

  void _onUsernameChanged(String value) {
    final user = FirebaseAuth.instance.currentUser;

    if (value.trim() == user?.displayName) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
      });

      return;
    }

    setState(() {
      _isUsernameAvailable = null;
      _isCheckingUsername = true;
    });

    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    if (value.trim().isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
      });

      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _checkUsernameAvailability(value.trim());
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    try {
      final isTaken = await _isUsernameTaken(username);

      if (!mounted) return;

      setState(() {
        _isUsernameAvailable = !isTaken;
        _isCheckingUsername = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
      });
    }
  }

  Future<bool> _isUsernameTaken(String username) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    var snap = await usersRef
        .where('displayName', isEqualTo: username)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      if (snap.docs.first.id != currentUserId) {
        return true;
      }
    }

    snap = await usersRef.where('username', isEqualTo: username).limit(1).get();

    if (snap.docs.isNotEmpty) {
      if (snap.docs.first.id != currentUserId) {
        return true;
      }
    }

    return false;
  }

  // UPDATE PROFILE

  Future<void> _updateProfile() async {
    if (!_formKeyProfile.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final newName = _displayNameController.text.trim();

      if (newName != user.displayName) {
        if (newName.isEmpty) {
          throw FirebaseAuthException(
            code: 'invalid-username',
            message: 'username_required'.tr(),
          );
        }

        final isTaken = await _isUsernameTaken(newName);

        if (isTaken) {
          throw FirebaseAuthException(
            code: 'username-taken',
            message: 'username_taken'.tr(),
          );
        }

        await user.updateDisplayName(newName);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': newName,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile_updated'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'failed_update_profile'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  // CHANGE PASSWORD

  Future<void> _updatePassword() async {
    if (!_formKeyPassword.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoadingPassword = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.email == null) return;

      final oldPassword = _oldPasswordController.text;
      final newPassword = _newPasswordController.text;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPassword,
      );

      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(newPassword);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('password_updated'.tr()),
          backgroundColor: Colors.green,
        ),
      );

      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          message = 'err_wrong_password'.tr();
          break;

        case 'weak-password':
          message = 'err_weak_password'.tr();
          break;

        case 'requires-recent-login':
          message = 'err_requires_recent_login'.tr();
          break;

        case 'network-request-failed':
          message = 'err_network'.tr();
          break;

        default:
          message = 'failed_update_password'.tr();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPassword = false;
        });
      }
    }
  }

  // DELETE ACCOUNT

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 40,
          ),
          title: Text(
            'delete_account_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text('delete_account_confirm_msg'.tr()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
              },
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('yes_delete_my_account'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    String? password;

    if (AccountDeletionService.isEmailPasswordUser) {
      _deletePasswordController.clear();

      password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text('confirm_your_password'.tr()),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'enter_password_confirm_delete'.tr(),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _deletePasswordController,
                      obscureText: _obscureDeletePassword,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'password_label'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureDeletePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _obscureDeletePassword = !_obscureDeletePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx, null);
                    },
                    child: Text('cancel'.tr()),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx, _deletePasswordController.text);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text('delete_forever'.tr()),
                  ),
                ],
              );
            },
          );
        },
      );

      if (password == null || password.isEmpty || !mounted) {
        return;
      }
    }

    setState(() {
      _isLoadingDelete = true;
    });

    try {
      await AccountDeletionService.deleteAccount(password: password);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          message = 'err_wrong_password'.tr();
          break;

        case 'requires-recent-login':
          message = 'err_requires_recent_login'.tr();
          break;

        case 'network-request-failed':
          message = 'err_network'.tr();
          break;

        default:
          message = 'failed_delete_account'.tr();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('error_msg'.tr(args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDelete = false;
        });
      }
    }
  }

  // INPUT DECORATION

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      hintText: hint,

      prefixIcon: prefixIcon,

      suffixIcon: suffixIcon,

      filled: true,

      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF4F2EC),

      isDense: true,

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PCColors.yellow, width: 1.5),
      ),
    );
  }

  // SMALL SECTION TITLE

  Widget _sectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: PCColors.yellowDark),
          const SizedBox(width: 7),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // APP BAR
      appBar: widget.isTab
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: theme.scaffoldBackgroundColor,

              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),

              title: Text(
                'profile_menu'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_rounded, size: 22),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                const NotificationBell(),
                const SizedBox(width: 4),
              ],
            ),

      // BODY
      //
      // No SingleChildScrollView here.
      // The normal collapsed profile fits on screen.
      // Password and Delete Account expand only when the user taps them.
      body: SafeArea(
        child: user == null
            ? const Center(child: Icon(Icons.person_off_rounded, size: 40))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();

                  final isPremium = data?['isPremium'] == true;

                  final photoUrl = data?['photoUrl'] as String?;

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        // PROFILE HEADER
                        _buildProfileHeader(
                          photoUrl: photoUrl,
                          isPremium: isPremium,
                        ),

                        const SizedBox(height: 12),

                        // PROFILE INFORMATION
                        _sectionTitle(
                          'profile_information'.tr(),
                          icon: Icons.person_outline_rounded,
                        ),

                        const SizedBox(height: 8),

                        Form(
                          key: _formKeyProfile,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // USERNAME
                              TextFormField(
                                controller: _displayNameController,
                                onChanged: _onUsernameChanged,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: _inputDecoration(
                                  hint: 'username_label'.tr(),
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                  ),
                                  suffixIcon: _usernameStatusIcon(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'please_enter_username'.tr();
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 7),

                              // EMAIL
                              TextFormField(
                                controller: _emailController,
                                readOnly: true,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: _inputDecoration(
                                  hint: 'email_label'.tr(),
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    size: 20,
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),

                              if (_isUsernameAvailable == false)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 3,
                                    left: 8,
                                  ),
                                  child: Text(
                                    'err_username_taken'.tr(),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // UPDATE BUTTON
                              SizedBox(
                                height: 44,
                                child: _isLoadingProfile
                                    ? const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: PCColors.yellowDark,
                                          ),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _updateProfile,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: PCColors.yellow,
                                          foregroundColor: Colors.black,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'update_profile'.tr().toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // CHANGE PASSWORD
                        // COLLAPSED BY DEFAULT
                        _buildChangePasswordSection(isDark: isDark),

                        // DELETE ACCOUNT
                        // COLLAPSED BY DEFAULT
                        if (!_isSuperAdmin)
                          _buildDeleteAccountSection(isDark: isDark),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  // PROFILE HEADER

  Widget _buildProfileHeader({
    required String? photoUrl,
    required bool isPremium,
  }) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 82,
      child: Row(
        children: [
          // AVATAR
          GestureDetector(
            onTap: _pickAndUploadProfileImage,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PCColors.yellow,
                    boxShadow: [
                      BoxShadow(
                        color: PCColors.yellow.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _isUploadingImage
                        ? Container(
                            color: Colors.white,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.person_rounded,
                                  size: 38,
                                  color: Colors.black45,
                                ),
                              );
                            },
                            errorWidget: (context, url, error) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.person_rounded,
                                  size: 38,
                                  color: Colors.black45,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade100,
                            child: const Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: Colors.black54,
                            ),
                          ),
                  ),
                ),

                // CAMERA BUTTON
                Positioned(
                  right: -1,
                  bottom: 0,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 13),

          // USER INFORMATION
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayNameController.text.isEmpty
                      ? 'profile_menu'.tr()
                      : _displayNameController.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _emailController.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
                  ),
                ),

                if (isPremium) ...[
                  const SizedBox(height: 5),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: PCColors.yellow.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: PCColors.yellowDark,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'premium_member'.tr(),
                          style: const TextStyle(
                            color: PCColors.yellowDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (widget.isTab)
            IconButton(
              icon: const Icon(Icons.settings_rounded, size: 24),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // USERNAME STATUS

  Widget? _usernameStatusIcon() {
    if (_isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_isUsernameAvailable == true) {
      return const Icon(
        Icons.check_circle_rounded,
        color: Colors.green,
        size: 20,
      );
    }

    if (_isUsernameAvailable == false) {
      return const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
    }

    return null;
  }

  // CHANGE PASSWORD SECTION
  //
  // CLOSED BY DEFAULT

  Widget _buildChangePasswordSection({required bool isDark}) {
    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.035)
          : Colors.white.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: PCColors.yellow.withValues(alpha: 0.08),
          highlightColor: PCColors.yellow.withValues(alpha: 0.05),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 13),
          childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),

          // Important:
          // ExpansionTile starts CLOSED.
          initiallyExpanded: false,

          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: PCColors.yellow.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: PCColors.yellowDark,
              size: 18,
            ),
          ),

          title: Text(
            'change_password'.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),

          subtitle: Text(
            'Tap to change your password',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.42),
            ),
          ),

          children: [
            Form(
              key: _formKeyPassword,
              child: Column(
                children: [
                  // OLD PASSWORD
                  TextFormField(
                    controller: _oldPasswordController,
                    obscureText: _obscureOld,
                    style: const TextStyle(fontSize: 13),
                    decoration: _inputDecoration(
                      hint: 'old_password'.tr(),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureOld ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureOld = !_obscureOld;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_enter_old_password'.tr();
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 7),

                  // NEW PASSWORD
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    style: const TextStyle(fontSize: 13),
                    decoration: _inputDecoration(
                      hint: 'new_password'.tr(),
                      prefixIcon: const Icon(
                        Icons.lock_reset_rounded,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNew = !_obscureNew;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_enter_new_password'.tr();
                      }

                      if (value.length < 6) {
                        return 'password_min_length'.tr();
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 7),

                  // CONFIRM PASSWORD
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    style: const TextStyle(fontSize: 13),
                    decoration: _inputDecoration(
                      hint: 'confirm_new_password'.tr(),
                      prefixIcon: const Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirm = !_obscureConfirm;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_confirm_password'.tr();
                      }

                      if (value != _newPasswordController.text) {
                        return 'passwords_do_not_match'.tr();
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 9),

                  SizedBox(
                    height: 43,
                    width: double.infinity,
                    child: _isLoadingPassword
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : ElevatedButton(
                            onPressed: _updatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white
                                  : Colors.black,
                              foregroundColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: Text(
                              'change_password'.tr().toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // DELETE ACCOUNT
  //
  // CLOSED BY DEFAULT

  Widget _buildDeleteAccountSection({required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Material(
        color: Colors.red.withValues(alpha: isDark ? 0.035 : 0.025),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.red.withValues(alpha: 0.05),
            highlightColor: Colors.red.withValues(alpha: 0.03),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 13),

            childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),

            // Closed initially.
            initiallyExpanded: false,

            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 18,
              ),
            ),

            title: Text(
              'danger_zone'.tr(),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),

            subtitle: Text(
              'Tap to manage account deletion',
              style: TextStyle(
                fontSize: 10,
                color: Colors.red.withValues(alpha: 0.55),
              ),
            ),

            children: [
              Text(
                'delete_account_confirm_msg'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),

              const SizedBox(height: 9),

              SizedBox(
                height: 42,
                width: double.infinity,
                child: _isLoadingDelete
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.red,
                          strokeWidth: 2.5,
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _deleteAccount,
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          size: 19,
                        ),
                        label: Text(
                          'delete_account_btn'.tr().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.55),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
