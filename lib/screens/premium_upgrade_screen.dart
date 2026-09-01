import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/notification_bell.dart';

import '../services/iap_service.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _premiumHandled = false;

  static const Color _yellow = Color(0xFFFFC72C);
  static const Color _yellowLight = Color(0xFFFFE066);
  static const Color _yellowDark = Color(0xFFE6A700);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _listenForPremiumStatus();
  }

  // PREMIUM STATUS

  void _listenForPremiumStatus() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (_premiumHandled) return;

          final data = snapshot.data();
          final isPremium = data?['isPremium'] == true;

          if (!isPremium) return;

          _premiumHandled = true;

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('purchase_successful'.tr()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          // Give the SnackBar a moment to appear before leaving.
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }, onError: (e) => print('PremiumUpgrade stream error: $e'));
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    final textColor = isLightMode ? const Color(0xFF181818) : Colors.white;

    final secondaryTextColor = isLightMode
        ? const Color(0xFF6F6F6F)
        : Colors.white.withValues(alpha: 0.65);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.of(context).pop(),
        ),

        title: Text(
          'upgrade_to_premium'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        actions: const [
          NotificationBell(),
          SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: ListenableBuilder(
            listenable: IapService.instance,
            builder: (context, _) {
              final iap = IapService.instance;

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),

                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),

                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 26,
                      ),

                      child: Column(
                        children: [
                          // PREMIUM ICON
                          const SizedBox(height: 8),

                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,

                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_yellowLight, _yellow],
                                ),

                                boxShadow: [
                                  BoxShadow(
                                    color: _yellow.withValues(
                                      alpha: isLightMode ? 0.28 : 0.20,
                                    ),
                                    blurRadius: 30,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),

                              child: const Icon(
                                Icons.star_rounded,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // TITLE
                          Text(
                            'potato_couch_premium'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 27,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: -0.7,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'unlock_ad_free'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 22),

                          // BENEFITS
                          _benefitsCard(
                            isLightMode: isLightMode,
                            textColor: textColor,
                          ),

                          const SizedBox(height: 22),

                          // PURCHASE
                          if (iap.isLoading)
                            _loadingWidget()
                          else
                            _purchaseSection(
                              iap: iap,
                              isLightMode: isLightMode,
                            ),

                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // BENEFITS CARD

  Widget _benefitsCard({required bool isLightMode, required Color textColor}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),

      child: Column(
        children: [
          _buildBenefitRow(
            icon: Icons.block_rounded,
            text: 'permanently_remove_ads'.tr(),
            textColor: textColor,
          ),

          _benefitDivider(),

          _buildBenefitRow(
            icon: Icons.favorite_rounded,
            text: 'support_development'.tr(),
            textColor: textColor,
          ),

          _benefitDivider(),

          _buildBenefitRow(
            icon: Icons.offline_bolt_rounded,
            text: 'faster_workouts'.tr(),
            textColor: textColor,
          ),
        ],
      ),
      ),
    );
  }

  // BENEFIT ROW

  Widget _buildBenefitRow({
    required IconData icon,
    required String text,
    required Color textColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,

          decoration: BoxDecoration(
            color: _yellow.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),

          child: Icon(icon, color: _yellowDark, size: 21),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),

        const SizedBox(width: 6),

        const Icon(Icons.check_circle_rounded, color: _yellowDark, size: 19),
      ],
    );
  }

  // BENEFIT DIVIDER

  Widget _benefitDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),

      child: Divider(
        height: 1,
        thickness: 0.7,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
      ),
    );
  }

  // PURCHASE SECTION

  Widget _purchaseSection({
    required IapService iap,
    required bool isLightMode,
  }) {
    final product = iap.removeAdsProduct;

    final canPurchase = iap.isAvailable && product != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PURCHASE BUTTON
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: _yellowDark,
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: canPurchase ? () => iap.buyRemoveAds() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _yellow,
              foregroundColor: Colors.black,
              elevation: 0,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide.none, // Removes the black border
              ),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, size: 21),

                  const SizedBox(width: 8),

                  Flexible(
                    child: Text(
                      product != null
                          ? 'upgrade_for_price'.tr(args: [product.price])
                          : 'loading_price'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 6),

        // AVAILABILITY MESSAGE
        if (!iap.isAvailable && product == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              'Premium purchase is currently unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isLightMode ? Colors.black45 : Colors.white38,
              ),
            ),
          ),

        // RESTORE
        TextButton(
          onPressed: () {
            iap.restorePurchases();
          },

          style: TextButton.styleFrom(
            foregroundColor: isLightMode ? Colors.black54 : Colors.white54,

            minimumSize: const Size.fromHeight(42),

            padding: const EdgeInsets.symmetric(vertical: 8),
          ),

          child: Text(
            'restore_purchases'.tr(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  // LOADING

  Widget _loadingWidget() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 25),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _yellowDark,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Loading premium...',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
