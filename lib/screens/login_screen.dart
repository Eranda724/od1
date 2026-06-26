import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'onboarding_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../main.dart';
import '../app_settings.dart';

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
  bool _obscurePassword = true;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final input = _emailController.text.trim();
      if (input.isEmpty) {
        throw FirebaseAuthException(code: 'invalid-email', message: 'Please enter an email or username.');
      }

      String emailToUse = input;

      // If the input doesn't look like an email, try resolving it as a username
      if (!input.contains('@')) {
        final usersRef = FirebaseFirestore.instance.collection('users');
        
        // Check new displayName field
        var snap = await usersRef.where('displayName', isEqualTo: input).limit(1).get();
        if (snap.docs.isNotEmpty) {
          emailToUse = snap.docs.first.data()['email'] ?? '';
        } else {
          // Check old username field for legacy users
          snap = await usersRef.where('username', isEqualTo: input).limit(1).get();
          if (snap.docs.isNotEmpty) {
            emailToUse = snap.docs.first.data()['email'] ?? '';
          } else {
            throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'No account found with this username.',
            );
          }
        }

        if (emailToUse.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Account found, but email is missing. Please contact support.',
          );
        }
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: _passwordController.text.trim(),
      );

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
        _errorMessage = e.message ?? 'Login failed';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PCColors.background,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Image.asset('assets/images/login.png', height: 260)),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  Text(
                    'Potato',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      foreground: Paint()
                        ..style = ui.PaintingStyle.stroke
                        ..strokeWidth = 5
                        ..strokeJoin = ui.StrokeJoin.round
                        ..color = Colors.black,
                    ),
                  ),
                  const Text(
                    'Potato',
                    style: TextStyle(
                      fontSize: 48,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.9,
                      foreground: Paint()
                        ..style = ui.PaintingStyle.stroke
                        ..strokeWidth = 3
                        ..strokeJoin = ui.StrokeJoin.round
                        ..color = Colors.black,
                    ),
                  ),
                  const Text(
                    '60 Second Routine',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email or Username',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
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
                child: const Text('Forgot Password?'),
              ),
            ),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Login'),
                  ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}