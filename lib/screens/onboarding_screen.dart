import 'package:flutter/material.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'welcome_screen.dart';
import '../app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/language_switcher.dart';

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
      'image': 'assets/images/onbo2.png',
      'titleKey': 'onboarding_title_2',
      'subtitleKey': 'onboarding_subtitle_2',
    },
    {
      'image': 'assets/images/onbo3.png',
      'titleKey': 'onboarding_title_3',
      'subtitleKey': 'onboarding_subtitle_3',
    },
    {
      'image': 'assets/images/onbo1.png',
      'titleKey': 'onboarding_title_4',
      'subtitleKey': 'onboarding_subtitle_4',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      int nextPage = _currentPage < _pages.length - 1 ? _currentPage + 1 : 0;
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

    // Register the onboarding event with Superwall.
    final handler = PaywallPresentationHandler();
    handler.onSkip((PaywallSkippedReason skipReason) async {
      _fallbackNavigation();
    });
    handler.onError((String error) async {
      debugPrint('Superwall presentation error: $error');
      _fallbackNavigation();
    });

    Superwall.shared.registerPlacement('onboarding_start', handler: handler);
  }

  Future<void> _fallbackNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildBottomControl() {
    if (_currentPage == _pages.length - 1) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFD69E00), // Darker yellow for 3D effect
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
          onPressed: _getStarted,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC72C),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Text(
            'onboarding_lets_go'.tr().toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () {
              _timer?.cancel();
              _controller.nextPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'onboarding_next'.tr(),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Page images
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + 80),
                    Text(
                      page['titleKey']!.tr(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      page['subtitleKey']!.tr(),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: SizedBox(
                        height: 400,
                        width: 400,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Mascot
                            Image.asset(
                              page['image']!,
                              height: 380,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Top Bar (Language Switcher on Left, Skip on Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const LanguageSwitcher(),
                GestureDetector(
                  onTap: _getStarted,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'onboarding_skip'.tr(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dot indicators
          Positioned(
            bottom: 140 + MediaQuery.of(context).padding.bottom,
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
                        : context.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // Dynamic Bottom Control
          Positioned(
            bottom: 40 + MediaQuery.of(context).padding.bottom,
            left: 24,
            right: 24,
            child: _buildBottomControl(),
          ),
        ],
      ),
    );
  }
}
