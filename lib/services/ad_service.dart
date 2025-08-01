import 'package:flutter/material.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // テスト用のAdMob ID
  static const String testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // 本番用のAdMob ID（実際のIDに置き換えてください）
  static const String nativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110'; // テスト用
  static const String bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // テスト用
  static const String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712'; // テスト用

  // 投稿リストに広告を挿入する頻度を制御
  static bool shouldShowAd(int index) {
    // 配信後に広告機能を再有効化予定
    return false;

    // final shouldShow = index > 0 && index % 5 == 0;
    // print('広告表示チェック: index=$index, shouldShow=$shouldShow');
    // return shouldShow;
  }

  // 広告の初期化（配信後に再有効化予定）
  static Future<void> initializeAds() async {
    // await MobileAds.instance.initialize();
    print('広告初期化: 配信後に再有効化予定');
  }

  // ネイティブ広告の読み込み（配信後に再有効化予定）
  static Future<dynamic> loadNativeAd() async {
    // try {
    //   final nativeAd = NativeAd(
    //     adUnitId: nativeAdUnitId,
    //     factoryId: 'listTile',
    //     request: const AdRequest(),
    //     listener: NativeAdListener(
    //       onAdLoaded: (ad) => print('ネイティブ広告が読み込まれました'),
    //       onAdFailedToLoad: (ad, error) => print('ネイティブ広告の読み込みに失敗しました: $error'),
    //     ),
    //   );
    //   await nativeAd.load();
    //   return nativeAd;
    // } catch (e) {
    //   print('ネイティブ広告の読み込みエラー: $e');
    //   return null;
    // }
    print('ネイティブ広告読み込み: 配信後に再有効化予定');
    return null;
  }
}
