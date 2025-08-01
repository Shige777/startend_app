import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_colors.dart';

class CarouselAdWidget extends StatefulWidget {
  const CarouselAdWidget({super.key});

  @override
  State<CarouselAdWidget> createState() => _CarouselAdWidgetState();
}

class _CarouselAdWidgetState extends State<CarouselAdWidget> {
  List<NativeAd> _nativeAds = [];
  bool _isAdLoaded = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  void _loadAds() {
    // 複数のネイティブ広告を読み込み
    for (int i = 0; i < 3; i++) {
      final nativeAd = NativeAd(
        adUnitId: 'ca-app-pub-3940256099942544/2247696110', // テスト用
        factoryId: 'adFactoryExample',
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
      _nativeAds.add(nativeAd);
      nativeAd.load();
    }
  }

  @override
  void dispose() {
    for (final ad in _nativeAds) {
      ad.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _nativeAds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 広告ラベル
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'おすすめ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // カルーセル
          Expanded(
            child: PageView.builder(
              itemCount: _nativeAds.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AdWidget(ad: _nativeAds[index]),
                  ),
                );
              },
            ),
          ),
          // ページインジケーター
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _nativeAds.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == index
                      ? AppColors.primary
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
