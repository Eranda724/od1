import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        throw FirebaseAuthException(
          code: 'empty-email',
          message: 'Please enter your email.',
        );
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(input)) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Invalid email address format.',
        );
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const StartRouter()),
          (route) => false,
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const StartRouter()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted)
        setState(() => _errorMessage = e.message ?? 'Google sign-in failed.');
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
      if (mounted)
        setState(() => _errorMessage = e.message ?? 'Apple sign-in failed.');
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
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            // If nothing to pop, we're at the root — just stay here.
            // No coded WelcomeScreen fallback; Superwall owns that flow.
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [LanguageSwitcher(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // Only scrollable when keyboard is open (bottomInset > 0)
              physics: bottomInset > 0
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Branding
                        Center(
                          child: Image.asset(
                            'assets/images/login.png',
                            height: screenHeight * 0.19,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'welcome_back_title'.tr(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'login_subtitle_new'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Social Sign-In
                        if (_isLoadingSocial)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          if (Platform.isIOS) ...[
                            ElevatedButton.icon(
                              onPressed: _signInWithApple,
                              icon: Image.asset(
                                'assets/images/apple.png',
                                height: 22,
                                width: 22,
                                color: Colors.white,
                              ),
                              label: Text(
                                'continue_apple'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                backgroundColor: const Color(0xFF111111),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          OutlinedButton.icon(
                            onPressed: _signInWithGoogle,
                            icon: Image.asset(
                              'assets/images/google.png',
                              height: 22,
                              width: 22,
                            ),
                            label: Text(
                              'continue_google'.tr(),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              foregroundColor: Colors.black87,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'or_divider'.tr(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Form
                        Text(
                          'email_label'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            hintText: 'email_hint'.tr(),
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFFFC72C),
                                width: 2,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'password_label'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFFFC72C),
                                width: 2,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
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
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'forgot_password'.tr(),
                              style: TextStyle(
                                color: Color(0xFFFFB300),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 24,
                          child: _errorMessage != null
                              ? Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 8),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xFFD69E00),
                                      offset: Offset(0, 5),
                                      blurRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: Colors.black12,
                                      offset: Offset(0, 8),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFC72C),
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Text(
                                    'log_in_action'.tr().toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'dont_have_account_prefix'.tr(),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegisterScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'sign_up_action'.tr(),
                                style: TextStyle(
                                  color: Color(0xFFFFB300),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
