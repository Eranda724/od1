import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'onboarding_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../main.dart';
import '../app_settings.dart';
import '../services/social_auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/language_switcher.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  bool _isLoadingSocial = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final input = _emailController.text.trim();
      if (input.isEmpty) {
        throw FirebaseAuthException(code: 'empty-email', message: 'Please enter your email.');
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(input)) {
        throw FirebaseAuthException(code: 'invalid-email', message: 'Invalid email address format.');
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: input,
        password: _passwordController.text.trim(),
      );

      // Ensure the email is saved in Firestore (fixes older accounts missing the email field)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const StartRouter(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'empty-email':
            _errorMessage = 'please_enter_email'.tr();
            break;
          case 'invalid-credential':
          case 'user-not-found':
          case 'wrong-password':
            _errorMessage = 'err_invalid_credential'.tr();
            break;
          case 'user-disabled':
            _errorMessage = 'err_user_disabled'.tr();
            break;
          case 'invalid-email':
            _errorMessage = 'err_invalid_email'.tr();
            break;
          case 'network-request-failed':
            _errorMessage = 'err_network'.tr();
            break;
          default:
            _errorMessage = 'err_login_failed'.tr();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'err_default'.tr();
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StartRouter()),
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StartRouter()),
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // resizeToAvoidBottomInset true so the body shrinks when keyboard appears
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingScreen(),
              ),
            );
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          LanguageSwitcher(),
          SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Branding ──
                      Center(
                        child: Image.asset(
                          'assets/images/login.png',
                          height: screenHeight * 0.22,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                            Text(
                              '60 Second Routine',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.isDark ? Colors.white : Colors.white,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // ── Form ──
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'email_label'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'password_label'.tr(),
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text('forgot_password'.tr()),
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: Text('login_button'.tr()),
                            ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: Text('no_account'.tr()),
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
                          label: Text('continue_google'.tr()),
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
                            label: Text(
                              'continue_apple'.tr(),
                              style: const TextStyle(color: Colors.white),
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
    );
  }
}