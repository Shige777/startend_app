import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // テスト用
  static const String _interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712'; // テスト用
  static const String _nativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110'; // テスト用

  // バナー広告を作成
  static BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('バナー広告が読み込まれました');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('バナー広告の読み込みに失敗しました: $error');
          ad.dispose();
        },
      ),
    );
  }

  // ネイティブ広告を作成
  static NativeAd createNativeAd() {
    return NativeAd(
      adUnitId: _nativeAdUnitId,
      factoryId: 'adFactoryExample', // ファクトリーIDを修正
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('ネイティブ広告が読み込まれました');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('ネイティブ広告の読み込みに失敗しました: $error');
          ad.dispose();
        },
      ),
    );
  }

  // インタースティシャル広告を作成
  static InterstitialAd? _interstitialAd;

  static Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          debugPrint('インタースティシャル広告が読み込まれました');
        },
        onAdFailedToLoad: (error) {
          debugPrint('インタースティシャル広告の読み込みに失敗しました: $error');
        },
      ),
    );
  }

  static Future<void> showInterstitialAd() async {
    if (_interstitialAd != null) {
      await _interstitialAd!.show();
      _interstitialAd = null;
      // 次の広告を読み込み
      loadInterstitialAd();
    }
  }

  // 投稿リストに広告を挿入する頻度を制御
  static bool shouldShowAd(int index) {
    // 3件ごとにネイティブ広告を表示（より頻繁に表示）
    // 5件ごとにネイティブ広告を表示（現在の設定）
    // 6件ごとにネイティブ広告を表示（より控えめに表示）
    final shouldShow = index > 0 && index % 5 == 0;
    debugPrint('広告表示チェック: index=$index, shouldShow=$shouldShow');
    return shouldShow;
  }
}
