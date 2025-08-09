
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // ネイティブ広告のAdMob ID
  static const String nativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110'; // テスト用

  // プリロードされた広告を保持
  static final List<NativeAd> _preloadedAds = [];
  static bool _isInitialized = false;

  // 投稿リストにネイティブ広告を挿入する頻度を制御
  static bool shouldShowAd(int index) {
    final shouldShow = index > 0 && index % 5 == 0; // Re-enabled
    return shouldShow;
  }

  // 広告の初期化
  static Future<void> initializeAds() async {
    if (_isInitialized) return;

    await MobileAds.instance.initialize();
    _isInitialized = true;

    // 初期化後に広告をプリロード
    _preloadAds();
  }

  // 広告をプリロード
  static Future<void> _preloadAds() async {
    try {
      // 複数の広告をプリロード
      for (int i = 0; i < 3; i++) {
        final nativeAd = NativeAd(
          adUnitId: nativeAdUnitId,
          factoryId: 'listTile',
          request: const AdRequest(),
          listener: NativeAdListener(
            onAdLoaded: (ad) {},
            onAdFailedToLoad: (ad, error) {
              ad.dispose();
            },
          ),
        );

        await nativeAd.load();
        _preloadedAds.add(nativeAd);
      }
    } catch (e) {
      // エラーハンドリング
    }
  }

  // プリロードされた広告を取得
  static NativeAd? getPreloadedAd() {
    if (_preloadedAds.isNotEmpty) {
      return _preloadedAds.removeAt(0);
    }
    return null;
  }

  // 新しい広告をプリロード
  static Future<void> _loadNewAd() async {
    try {
      final nativeAd = NativeAd(
        adUnitId: nativeAdUnitId,
        factoryId: 'listTile',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {},
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
          },
        ),
      );

      await nativeAd.load();
      _preloadedAds.add(nativeAd);
    } catch (e) {
      // エラーハンドリング
    }
  }

  // 広告プールを補充
  static Future<void> refillAdPool() async {
    if (_preloadedAds.length < 2) {
      await _loadNewAd();
    }
  }

  // ネイティブ広告の読み込み（従来の方法）
  static Future<NativeAd?> loadNativeAd() async {
    try {
      final nativeAd = NativeAd(
        adUnitId: nativeAdUnitId,
        factoryId: 'listTile',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {},
          onAdFailedToLoad: (ad, error) {},
        ),
      );
      await nativeAd.load();
      return nativeAd;
    } catch (e) {
      return null;
    }
  }
}
