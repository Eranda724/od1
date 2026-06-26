import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import '../app_settings.dart';

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
    return Scaffold(
      backgroundColor: PCColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/images/register.png', height: 220)),
                  const SizedBox(height: 16),
                  // Potato title
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
                  // Subtitle
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
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
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
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
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
                ],
              ),
            ),
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