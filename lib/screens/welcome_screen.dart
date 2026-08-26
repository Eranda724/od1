import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'onboarding_screen.dart';
import '../app_settings.dart';
import '../widgets/language_switcher.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _completeOnboarding(
    BuildContext context,
    Widget nextScreen,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/onbo1-back.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).padding.top + 80,
                          ),
                          Text(
                            'onboarding_title_1'.tr(),
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
                            'onboarding_subtitle_1'.tr(),
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
                            child: Image.asset(
                              'assets/images/onbo4.png',
                              height: 380,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
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
                          onPressed: () => _completeOnboarding(
                            context,
                            const RegisterScreen(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC72C),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            'get_started'.tr().toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () =>
                            _completeOnboarding(context, const LoginScreen()),
                        child: RichText(
                          text: TextSpan(
                            text: 'already_have_account_prefix'.tr(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'already_have_account_login'
                                    .tr()
                                    .replaceFirst(
                                        'already_have_account_prefix'.tr(), ''),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Back button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
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
          ),
          // Language switcher overlay (Top Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: const LanguageSwitcher(),
          ),
        ],
      ),
    );
  }
}
