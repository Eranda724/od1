import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/iap_service.dart';
import '../app_settings.dart';

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
              const SnackBar(
                content: Text('Purchase Successful! You are now Premium.'),
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
        title: const Text('Upgrade to Premium'),
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
                  const Text(
                    'Potato Couch Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unlock the ultimate ad-free experience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  _buildBenefitRow(Icons.block_rounded, 'Permanently remove all ads'),
                  const SizedBox(height: 16),
                  _buildBenefitRow(Icons.favorite_rounded, 'Support ongoing app development'),
                  const SizedBox(height: 16),
                  _buildBenefitRow(Icons.offline_bolt_rounded, 'Faster, uninterrupted workouts'),
                  
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
                                ? 'Upgrade for ${iap.removeAdsProduct!.price}'
                                : 'Loading price...',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => iap.restorePurchases(),
                          child: const Text(
                            'Restore Purchases',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
