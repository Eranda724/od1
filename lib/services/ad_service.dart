import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  BannerAd? get bannerAd => _isBannerAdLoaded ? _bannerAd : null;

  /// Initializes the MobileAds SDK
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  /// Loads a standard banner ad to be displayed on the dashboard.
  void loadBannerAd({VoidCallback? onLoaded}) {
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
