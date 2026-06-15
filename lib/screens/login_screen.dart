import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'admin_screen.dart';

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

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        final isAdmin = doc.data()?['isAdmin'] == true;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => isAdmin ? const AdminScreen() : const HomeScreen(),
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/login.png', height: 120),
            const SizedBox(height: 16),
            const Text(
              'Potato',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFC72C),
                shadows: [
                  Shadow(offset: Offset(-2.5, -2.5), color: Colors.black),
                  Shadow(offset: Offset(2.5, -2.5), color: Colors.black),
                  Shadow(offset: Offset(2.5, 2.5), color: Colors.black),
                  Shadow(offset: Offset(-2.5, 2.5), color: Colors.black),
                ],
              ),
            ),
            const Text(
              '60 Second Routine',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
                  Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
                  Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
                  Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
                ],
              ),
            ),
            const SizedBox(height: 32),
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
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
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