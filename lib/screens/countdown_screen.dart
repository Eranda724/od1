import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'exercise_screen.dart';
import '../app_settings.dart';

class CountdownScreen extends StatefulWidget {
  final int readyTimeSeconds;
  
  const CountdownScreen({
    super.key,
    required this.readyTimeSeconds,
  });

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> with TickerProviderStateMixin {
  late int _countdown;
  Timer? _timer;
  late AnimationController _pulseController;
  late AnimationController _progressController;
  
  final List<String> _motivations = [
    "Your streak is waiting, beat the others!",
    "Get ready to crush your goals!",
    "Breathe in. Focus. Let's go!",
    "Push yourself, because no one else will.",
    "The hardest part is starting. You got this!",
  ];
  late String _currentMotivation;

  @override
  void initState() {
    super.initState();
    _countdown = widget.readyTimeSeconds;
    _currentMotivation = _motivations[Random().nextInt(_motivations.length)];

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pulseController.reverse();
        }
      });

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.readyTimeSeconds),
    )..forward();

    _startTimer();
    _pulseController.forward();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
          // Randomly change motivation every 3 seconds to keep it dynamic
          if (_countdown % 3 == 0) {
            _currentMotivation = _motivations[Random().nextInt(_motivations.length)];
          }
        });
        _pulseController.forward(from: 0);
      } else {
        timer.cancel();
        _progressController.stop();
        _navigateToNext();
      }
    });
  }

  void _navigateToNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExerciseScreen(user: FirebaseAuth.instance.currentUser),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PCColors.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Part 1: Be Ready
            const Text(
              "Be Ready",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: PCColors.brown,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 50),

            // Part 2: Circle Area
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.15);
                  return Transform.scale(
                    scale: scale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background progress circle
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              return CircularProgressIndicator(
                                value: 1.0 - _progressController.value,
                                strokeWidth: 12,
                                backgroundColor: PCColors.yellow.withValues(alpha: 0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(PCColors.green),
                              );
                            },
                          ),
                        ),
                        // Inner circle decoration
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [PCColors.yellow, PCColors.yellowDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: PCColors.yellowDark.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        // Number
                        Text(
                          '$_countdown',
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 70),

            // Part 3: Motivational sentence
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _currentMotivation,
                  key: ValueKey<String>(_currentMotivation),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: PCColors.brown.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            
            // Allow user to skip
            const SizedBox(height: 50),
            TextButton(
              onPressed: () {
                _timer?.cancel();
                _navigateToNext();
              },
              child: const Text(
                "Skip & Start",
                style: TextStyle(
                  fontSize: 16,
                  color: PCColors.brown,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
