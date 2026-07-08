import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../services/account_deletion_service.dart';
import 'login_screen.dart';
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

  bool _isLoadingProfile = false;
  bool _isLoadingPassword = false;
  bool _isLoadingDelete = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _obscureDeletePassword = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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

      // Update email
      if (newEmail != user.email) {
        // updateEmail is sometimes deprecated or requires recent login.
        // We will try to update it directly.
        // ignore: deprecated_member_use
        await user.updateEmail(newEmail);
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'email': newEmail}, SetOptions(merge: true));
      }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'failed_update_password'.tr()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPassword = false);
    }
  }

  Future<bool> _isUsernameTaken(String username) async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    
    // Check displayName
    var snap = await usersRef.where('displayName', isEqualTo: username).limit(1).get();
    if (snap.docs.isNotEmpty) return true;

    // Check legacy username
    snap = await usersRef.where('username', isEqualTo: username).limit(1).get();
    return snap.docs.isNotEmpty;
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
      final passwordController = TextEditingController();
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
                  controller: passwordController,
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
                onPressed: () => Navigator.pop(ctx, passwordController.text),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('delete_forever'.tr()),
              ),
            ],
          ),
        ),
      );

      passwordController.dispose();
      if (password == null || password.isEmpty || !mounted) return;
    }

    // ── Step 3: Delete account ────────────────────────────────────────────────
    setState(() => _isLoadingDelete = true);
    try {
      await AccountDeletionService.deleteAccount(password: password);
      if (!mounted) return;
      // Navigate to login and clear the entire navigation stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'failed_delete_account'.tr()),
            backgroundColor: Colors.red,
          ),
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
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
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
                      decoration: InputDecoration(
                        labelText: 'username_label'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'please_enter_username'.tr() : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'email_label'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'please_enter_email_valid'.tr();
                        if (!value.contains('@')) return 'please_enter_valid_email'.tr();
                        return null;
                      },
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
