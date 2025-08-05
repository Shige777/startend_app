import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_colors.dart';
import '../services/ad_service.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    try {
      // まずプリロードされた広告を試す
      _nativeAd = AdService.getPreloadedAd();

      if (_nativeAd != null) {
        setState(() {
          _isAdLoaded = true;
        });

        // 広告プールを補充
        AdService.refillAdPool();
        return;
      }

      // プリロードされた広告がない場合は新しく読み込む
      _nativeAd = NativeAd(
        adUnitId: 'ca-app-pub-3940256099942544/2247696110', // テスト用
        factoryId: 'listTile',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            setState(() {
              _isAdLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
          },
        ),
      );
      await _nativeAd!.load();
    } catch (e) {
      // エラーハンドリング
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 1,
              offset: const Offset(0, 0.5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: AdWidget(ad: _nativeAd!),
          ),
        ),
      ),
    );
  }
}
