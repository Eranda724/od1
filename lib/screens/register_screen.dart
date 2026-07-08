import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import '../app_settings.dart';
import '../services/social_auth_service.dart';
import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  bool _isLoadingSocial = false;
  bool _obscurePassword = true;

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final typedName = _usernameController.text.trim();
      if (typedName.isEmpty) {
        throw FirebaseAuthException(code: 'invalid-username', message: 'Username is required.');
      }

      // Check uniqueness before creating the auth account
      final isTaken = await _isUsernameTaken(typedName);
      if (isTaken) {
        throw FirebaseAuthException(code: 'username-taken', message: 'This username is already taken. Please choose another.');
      }

      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final displayName = typedName;

      // Save to Firebase Auth profile
      await credential.user?.updateDisplayName(displayName);

      // Also save to Firestore user doc immediately so leaderboard can read it
      if (credential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'displayName': displayName,
              'email': credential.user!.email,
            }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Registration failed';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Database error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoadingSocial = true;
      _errorMessage = null;
    });
    try {
      final credential = await SocialAuthService.signInWithGoogle();
      if (credential == null) return; // user cancelled
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const StartRouter()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message ?? 'Google sign-in failed.');
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSocial = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoadingSocial = true;
      _errorMessage = null;
    });
    try {
      final credential = await SocialAuthService.signInWithApple();
      if (credential == null) return; // user cancelled
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const StartRouter()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message ?? 'Apple sign-in failed.');
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Apple sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSocial = false);
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // resizeToAvoidBottomInset true so the body shrinks when keyboard appears
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // Only scrollable when keyboard is open (bottomInset > 0)
                  physics: bottomInset > 0
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Branding ──
                            Center(
                              child: Image.asset(
                                'assets/images/register.png',
                                height: screenHeight * 0.19,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Potato title
                            Center(
                              child: Stack(
                                children: [
                                  Text(
                                    'Potato',
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                      foreground: Paint()
                                        ..style = ui.PaintingStyle.stroke
                                        ..strokeWidth = 5
                                        ..strokeJoin = ui.StrokeJoin.round
                                        ..color = context.textPrimary,
                                    ),
                                  ),
                                  const Text(
                                    'Potato',
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFFC72C),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Subtitle
                            Center(
                              child: Stack(
                                children: [
                                  Text(
                                    '60 Second Routine',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.9,
                                      foreground: Paint()
                                        ..style = ui.PaintingStyle.stroke
                                        ..strokeWidth = 3
                                        ..strokeJoin = ui.StrokeJoin.round
                                        ..color = context.textPrimary,
                                    ),
                                  ),
                                  const Text(
                                    '60 Second Routine',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            // ── Form ──
                            TextField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.text,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscurePassword,
                            ),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            const SizedBox(height: 12),
                            _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : ElevatedButton(
                                    onPressed: _register,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                    ),
                                    child: const Text('Create Account'),
                                  ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Already have an account? Login'),
                            ),

                            // ── Social Sign-In ──
                            if (_isLoadingSocial)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Google Sign-In
                              OutlinedButton.icon(
                                onPressed: _signInWithGoogle,
                                icon: Image.asset(
                                  'assets/images/google.png',
                                  height: 22,
                                  width: 22,
                                ),
                                label: const Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  foregroundColor: Colors.black87,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              // Apple Sign-In — iOS only
                              if (Platform.isIOS) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _signInWithApple,
                                  icon: Image.asset(
                                    'assets/images/apple.png',
                                    height: 22,
                                    width: 22,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Continue with Apple',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    backgroundColor: Colors.black,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Back button overlay
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}