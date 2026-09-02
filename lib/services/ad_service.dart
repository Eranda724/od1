import 'dart:io';
import 'dart:async';
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
  
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  
  bool _isPremiumCache = false;

  BannerAd? get bannerAd => _isBannerAdLoaded && !_isPremiumCache ? _bannerAd : null;
  bool get isPremium => _isPremiumCache;

  bool _isPrivacyOptionsRequired = false;
  
  /// Whether the privacy options form is required (for GDPR compliance in settings)
  bool get isPrivacyOptionsRequired => _isPrivacyOptionsRequired;

  /// Initializes the MobileAds SDK and handles GDPR consent via UMP
  Future<void> initialize() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) async {
            if (formError != null) {
              debugPrint('Consent form error: ${formError.message}');
            }
            await _completeInit(completer);
          });
        } else {
          await _completeInit(completer);
        }
      },
      (FormError formError) async {
        debugPrint('Consent request error: ${formError.message}');
        await _completeInit(completer);
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () async {
        debugPrint('Consent request timeout.');
        await _completeInit(null);
      },
    );
  }

  Future<void> _completeInit(Completer<void>? completer) async {
    if (completer != null && completer.isCompleted) return;
    
    // Cache the privacy options requirement status so the UI can check it synchronously
    final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    _isPrivacyOptionsRequired = status == PrivacyOptionsRequirementStatus.required;

    final canRequestAds = await ConsentInformation.instance.canRequestAds();
    if (canRequestAds) {
      await MobileAds.instance.initialize();
    } else {
      debugPrint('Cannot request ads. Missing consent.');
    }
    
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  /// Show the privacy options form to allow users to revoke/manage consent
  void showPrivacyOptionsForm() {
    ConsentForm.showPrivacyOptionsForm((FormError? formError) {
      if (formError != null) {
        debugPrint('Error showing privacy options form: ${formError.message}');
      }
    });
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

  /// Refreshes the premium status cache
  Future<void> refreshPremiumStatus() async {
    _isPremiumCache = await _isUserPremium();
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

  /// Loads a standard Interstitial Ad for the active session break.
  Future<void> loadInterstitialAd() async {
    _isPremiumCache = await _isUserPremium();
    if (_isPremiumCache) {
      debugPrint('User is premium. Interstitial ad loading aborted.');
      return;
    }
    if (_interstitialAd != null || _isInterstitialAdLoading) return;
    _isInterstitialAdLoading = true;
    
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('InterstitialAd loaded.');
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _interstitialAd = null;
          _isInterstitialAdLoading = false;
        },
      ),
    );
  }

  /// Shows the Interstitial Ad and calls onAdDismissed when closed.
  Future<void> showInterstitialAd({required VoidCallback onAdDismissed}) async {
    _isPremiumCache = await _isUserPremium();
    if (_isPremiumCache) {
      onAdDismissed();
      return;
    }

    // If the ad is currently loading, wait for it for up to 10 seconds.
    if (_isInterstitialAdLoading) {
      debugPrint('Waiting for interstitial ad to finish loading...');
      int waited = 0;
      while (_isInterstitialAdLoading && waited < 100) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited++;
      }
    }

    if (_interstitialAd == null) {
      debugPrint('Warning: attempt to show interstitial before loaded.');
      onAdDismissed();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('Ad showed fullscreen content.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Ad dismissed fullscreen content.');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Load the next one in advance
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Ad failed to show fullscreen content: $error');
        ad.dispose();
        _interstitialAd = null;
        onAdDismissed();
      },
    );

    _interstitialAd!.show();
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

  /// Returns the configured ad unit ID for standard interstitials.
  String get _interstitialAdUnitId {
    if (Platform.isAndroid) {
      return dotenv.env['ADMOB_INTERSTITIAL_ID_ANDROID'] ?? 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return dotenv.env['ADMOB_INTERSTITIAL_ID_IOS'] ?? 'ca-app-pub-3940256099942544/4411468910';
    }
    throw UnsupportedError('Unsupported platform');
  }
}
