import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  
  BannerAd? _sessionAd;
  bool _isSessionAdLoaded = false;
  
  bool _isPremiumCache = false;

  BannerAd? get bannerAd => _isBannerAdLoaded && !_isPremiumCache ? _bannerAd : null;
  BannerAd? get sessionAd => _isSessionAdLoaded && !_isPremiumCache ? _sessionAd : null;
  bool get isPremium => _isPremiumCache;

  /// Initializes the MobileAds SDK
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  /// Checks if the current user is premium (ad-free)
  Future<bool> _isUserPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['isPremium'] == true;
      }
    } catch (e) {
      debugPrint('Error checking premium status: $e');
    }
    return false;
  }

  /// Loads a standard banner ad to be displayed on the dashboard.
  Future<void> loadBannerAd({VoidCallback? onLoaded}) async {
    _isPremiumCache = await _isUserPremium();
    if (_isPremiumCache) {
      debugPrint('User is premium. Ad loading aborted.');
      if (onLoaded != null) onLoaded();
      return;
    }
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('BannerAd loaded.');
          _isBannerAdLoaded = true;
          if (onLoaded != null) onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          _isBannerAdLoaded = false;
        },
      ),
    )..load();
  }

  /// Disposes the banner ad to free up resources when not needed.
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;
  }

  /// Loads a medium rectangle ad (or adaptive) for the active session screen.
  Future<void> loadSessionAd({AdSize size = AdSize.mediumRectangle, VoidCallback? onLoaded}) async {
    _isPremiumCache = await _isUserPremium();
    if (_isPremiumCache) {
      debugPrint('User is premium. Session ad loading aborted.');
      if (onLoaded != null) onLoaded();
      return;
    }
    _sessionAd = BannerAd(
      adUnitId: _bannerAdUnitId, // Reuse banner ID or create a specific one if client provides it
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('SessionAd loaded.');
          _isSessionAdLoaded = true;
          if (onLoaded != null) onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('SessionAd failed to load: $error');
          ad.dispose();
          _sessionAd = null;
          _isSessionAdLoaded = false;
        },
      ),
    )..load();
  }

  /// Disposes the session ad.
  void disposeSessionAd() {
    _sessionAd?.dispose();
    _sessionAd = null;
    _isSessionAdLoaded = false;
  }

  /// Returns the configured ad unit ID for banners.
  String get _bannerAdUnitId {
    if (Platform.isAndroid) {
      return dotenv.env['ADMOB_BANNER_ID_ANDROID'] ?? 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return dotenv.env['ADMOB_BANNER_ID_IOS'] ?? 'ca-app-pub-3940256099942544/2934735716';
    }
    throw UnsupportedError('Unsupported platform');
  }
}
