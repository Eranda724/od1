import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../services/account_deletion_service.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKeyProfile = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  bool _isLoadingProfile = false;
  bool _isLoadingPassword = false;
  bool _isLoadingDelete = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _obscureDeletePassword = true;

  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
  }

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
      _isUsernameAvailable = null; // reset while typing
      _isCheckingUsername = true;
    });

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
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
      if (mounted) {
        setState(() {
          _isUsernameAvailable = !isTaken;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = null;
        });
      }
    }
  }

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

  Future<void> _updateProfile() async {
    if (!_formKeyProfile.currentState!.validate()) return;

    setState(() => _isLoadingProfile = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newName = _displayNameController.text.trim();
      final newEmail = _emailController.text.trim();

      // Update display name
      if (newName != user.displayName) {
        if (newName.isEmpty) {
          throw FirebaseAuthException(code: 'invalid-username', message: 'username_required'.tr());
        }

        final isTaken = await _isUsernameTaken(newName);
        if (isTaken) {
          throw FirebaseAuthException(code: 'username-taken', message: 'username_taken'.tr());
        }

        await user.updateDisplayName(newName);
        // Ensure Firestore is updated so leaderboard knows
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'displayName': newName}, SetOptions(merge: true));
      }

      // Update email is disabled because it requires complex re-authentication 
      // and email verification which is beyond the scope of this app.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_updated'.tr()), backgroundColor: Colors.green),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'failed_update_profile'.tr()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKeyPassword.currentState!.validate()) return;

    setState(() => _isLoadingPassword = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return;

      final oldPassword = _oldPasswordController.text;
      final newPassword = _newPasswordController.text;

      // 1. Re-authenticate with old password
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Update to new password
      await user.updatePassword(newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('password_updated'.tr()), backgroundColor: Colors.green),
        );
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg;
        switch (e.code) {
          case 'invalid-credential':
          case 'wrong-password':
            msg = 'err_wrong_password'.tr();
            break;
          case 'weak-password':
            msg = 'err_weak_password'.tr();
            break;
          case 'requires-recent-login':
            msg = 'err_requires_recent_login'.tr();
            break;
          case 'network-request-failed':
            msg = 'err_network'.tr();
            break;
          default:
            msg = 'failed_update_password'.tr();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPassword = false);
    }
  }

  Future<bool> _isUsernameTaken(String username) async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // Check displayName
    var snap = await usersRef.where('displayName', isEqualTo: username).limit(1).get();
    if (snap.docs.isNotEmpty) {
      if (snap.docs.first.id != currentUserId) return true;
    }

    // Check legacy username
    snap = await usersRef.where('username', isEqualTo: username).limit(1).get();
    if (snap.docs.isNotEmpty) {
      if (snap.docs.first.id != currentUserId) return true;
    }
    return false;
  }

  Future<void> _deleteAccount() async {
    // ── Step 1: Warning dialog ────────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
        title: Text(
          'delete_account_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'delete_account_confirm_msg'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('yes_delete_my_account'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // ── Step 2: Password confirmation (email/password users only) ─────────────────
    String? password;
    if (AccountDeletionService.isEmailPasswordUser) {
      _deletePasswordController.clear();
      password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('confirm_your_password'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'enter_password_confirm_delete'.tr(),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _deletePasswordController,
                  obscureText: _obscureDeletePassword,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'password_label'.tr(),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureDeletePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setDialogState(
                          () => _obscureDeletePassword = !_obscureDeletePassword),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _deletePasswordController.text),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('delete_forever'.tr()),
              ),
            ],
          ),
        ),
      );

      if (password == null || password.isEmpty || !mounted) return;
    }

    // ── Step 3: Delete account ────────────────────────────────────────────────
    setState(() => _isLoadingDelete = true);
    try {
      await AccountDeletionService.deleteAccount(password: password);
      if (!mounted) return;
      // Navigate to onboarding and clear the entire navigation stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg;
        switch (e.code) {
          case 'invalid-credential':
          case 'wrong-password':
            msg = 'err_wrong_password'.tr();
            break;
          case 'requires-recent-login':
            msg = 'err_requires_recent_login'.tr();
            break;
          case 'network-request-failed':
            msg = 'err_network'.tr();
            break;
          default:
            msg = 'failed_delete_account'.tr();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_msg'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDelete = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('profile_menu'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: FirebaseAuth.instance.currentUser?.uid == null 
                  ? const SizedBox()
                  : StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final isPremium = snapshot.data?.data()?['isPremium'] == true;
                    
                    return Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: PCColors.yellow,
                              child: Icon(Icons.person, size: 48, color: Colors.black),
                            ),
                            if (isPremium)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: PCColors.yellow,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                        if (isPremium) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC72C).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFFC72C)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFC72C), size: 16),
                                const SizedBox(width: 4),
                                Text('premium_member'.tr(), style: const TextStyle(color: Color(0xFFFFC72C), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // ── Profile Information ──
              Text('profile_information'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Form(
                key: _formKeyProfile,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _displayNameController,
                      onChanged: _onUsernameChanged,
                      decoration: InputDecoration(
                        labelText: 'username_label'.tr(),
                        border: const OutlineInputBorder(),
                        suffixIcon: _isCheckingUsername
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : (_isUsernameAvailable == true)
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : (_isUsernameAvailable == false)
                                    ? const Icon(Icons.cancel, color: Colors.red)
                                    : null,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'please_enter_username'.tr() : null,
                    ),
                    if (_isUsernameAvailable == false)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          'err_username_taken'.tr(),
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'email_label'.tr(),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white10 
                            : Colors.grey.shade200,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _isLoadingProfile
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _updateProfile,
                            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                            child: Text('update_profile'.tr()),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // ── Change Password ──
              Text('change_password'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Form(
                key: _formKeyPassword,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: _obscureOld,
                      decoration: InputDecoration(
                        labelText: 'old_password'.tr(),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureOld = !_obscureOld),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'please_enter_old_password'.tr() : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'new_password'.tr(),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'please_enter_new_password'.tr();
                        if (value.length < 6) return 'password_min_length'.tr();
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'confirm_new_password'.tr(),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'please_confirm_password'.tr();
                        if (value != _newPasswordController.text) return 'passwords_do_not_match'.tr();
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _isLoadingPassword
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _updatePassword,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white12
                                  : Colors.black87,
                              foregroundColor: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.white,
                              side: BorderSide.none,
                            ),
                            child: Text('change_password'.tr()),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // ── Danger Zone ──
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'danger_zone'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _isLoadingDelete
                  ? const Center(child: CircularProgressIndicator(color: Colors.red))
                  : OutlinedButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: Text('delete_account_btn'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
