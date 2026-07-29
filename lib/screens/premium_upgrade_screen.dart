import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/iap_service.dart';
import 'package:easy_localization/easy_localization.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _listenForPremiumStatus();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _listenForPremiumStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        final isPremium = snapshot.data()?['isPremium'] == true;
        if (isPremium) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('purchase_successful'.tr()),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(); // Auto-navigate back
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final textColor = isLightMode ? Colors.black87 : Colors.white;
    final secondaryTextColor = isLightMode ? Colors.black54 : Colors.white.withValues(alpha: 0.7);

    return Scaffold(
      appBar: AppBar(
        title: Text('upgrade_to_premium'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLightMode
                ? [
                    const Color(0xFFFFF2C2), // Warm soft gold top
                    Colors.white,
                    const Color(0xFFFAFAFA),
                  ]
                : [
                    const Color(0xFF332A00), // Dark gold hint at the top
                    const Color(0xFF111111), // Deep black-grey
                    const Color(0xFF0A0A0A), // Near black at bottom
                  ],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: IapService.instance,
            builder: (context, _) {
              final iap = IapService.instance;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 1),
                    // Animated Premium Star
                    Center(
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFE066), Color(0xFFFDB931)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: isLightMode ? 0.5 : 0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'potato_couch_premium'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'unlock_ad_free'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Benefits Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isLightMode 
                            ? Colors.black.withValues(alpha: 0.02)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isLightMode 
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildBenefitRow(Icons.block_rounded, 'permanently_remove_ads'.tr(), textColor),
                          const SizedBox(height: 24),
                          _buildBenefitRow(Icons.favorite_rounded, 'support_development'.tr(), textColor),
                          const SizedBox(height: 24),
                          _buildBenefitRow(Icons.offline_bolt_rounded, 'faster_workouts'.tr(), textColor),
                        ],
                      ),
                    ),
                    
                    const Spacer(flex: 2),

                    if (iap.isLoading)
                      const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFE066), Color(0xFFFDB931)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: (iap.isAvailable && iap.removeAdsProduct != null)
                                  ? () => iap.buyRemoveAds()
                                  : null,
                              child: Text(
                                iap.removeAdsProduct != null 
                                    ? 'upgrade_for_price'.tr(args: [iap.removeAdsProduct!.price])
                                    : 'loading_price'.tr(),
                                style: const TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => iap.restorePurchases(),
                            style: TextButton.styleFrom(
                              foregroundColor: isLightMode ? Colors.black54 : Colors.white.withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'restore_purchases'.tr(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFFE6A700), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
