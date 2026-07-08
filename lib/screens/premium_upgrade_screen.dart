import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/iap_service.dart';
import '../app_settings.dart';
import 'package:easy_localization/easy_localization.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _listenForPremiumStatus();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('upgrade_to_premium'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: IapService.instance,
          builder: (context, _) {
            final iap = IapService.instance;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Icon(
                    Icons.star_rounded,
                    size: 100,
                    color: Color(0xFFFFC72C),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'potato_couch_premium'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'unlock_ad_free'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  _buildBenefitRow(Icons.block_rounded, 'permanently_remove_ads'.tr()),
                  const SizedBox(height: 16),
                  _buildBenefitRow(Icons.favorite_rounded, 'support_development'.tr()),
                  const SizedBox(height: 16),
                  _buildBenefitRow(Icons.offline_bolt_rounded, 'faster_workouts'.tr()),
                  
                  const Spacer(),

                  if (iap.isLoading)
                    const Center(child: CircularProgressIndicator(color: PCColors.yellow))
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PCColors.yellow,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: (iap.isAvailable && iap.removeAdsProduct != null)
                              ? () => iap.buyRemoveAds()
                              : null,
                          child: Text(
                            iap.removeAdsProduct != null 
                                ? 'upgrade_for_price'.tr(args: [iap.removeAdsProduct!.price])
                                : 'loading_price'.tr(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => iap.restorePurchases(),
                          child: Text(
                            'restore_purchases'.tr(),
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFC72C), size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
