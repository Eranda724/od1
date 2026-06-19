import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/images/po2.png',
      'title': 'Build Daily Habits 🔥',
      'subtitle': 'Just 60 seconds a day keeps your streak alive.',
    },
    {
      'image': 'assets/images/po1.png',
      'title': 'Track Your Progress 💪',
      'subtitle': 'Every rep counts. Watch your lifetime totals grow.',
    },
    {
      'image': 'assets/images/po3.png',
      'title': 'Even a Couch Potato Can Do This 🥔',
      'subtitle': 'Small steps every day. No gym needed.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      int nextPage = _currentPage < _pages.length - 1
          ? _currentPage + 1
          : 0;
      if (_controller.hasClients) {
        _controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _getStarted() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // ── Page images ──
          PageView.builder(
            controller: _controller,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      page['image']!,
                      height: 280, // Smaller image
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 48),
                    Text(
                      page['title']!,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 213, 94, 3),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      page['subtitle']!,
                      style: const TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 120), // Padding for bottom controls
                  ],
                ),
              );
            },
          ),

          // ── Dot indicators ──
          Positioned(
            bottom: 115,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFFFFC72C)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // ── Get Started button ──
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: _getStarted,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
              child: const Text('Get Started'),
            ),
          ),

        ],
      ),
    );
  }
}
