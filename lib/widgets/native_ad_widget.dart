import 'package:flutter/material.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_colors.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  // NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // _loadAd();
  }

  // Future<void> _loadAd() async {
  //   try {
  //     _nativeAd = NativeAd(
  //       adUnitId: 'ca-app-pub-3940256099942544/2247696110', // テスト用
  //       factoryId: 'listTile',
  //       request: const AdRequest(),
  //       listener: NativeAdListener(
  //         onAdLoaded: (ad) {
  //           setState(() {
  //             _isAdLoaded = true;
  //           });
  //           print('ネイティブ広告が読み込まれました');
  //         },
  //         onAdFailedToLoad: (ad, error) {
  //           print('ネイティブ広告の読み込みに失敗しました: $error');
  //           ad.dispose();
  //         },
  //       ),
  //     );
  //     await _nativeAd!.load();
  //   } catch (e) {
  //     print('ネイティブ広告の読み込みエラー: $e');
  //   }
  // }

  @override
  void dispose() {
    // _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 配信後に広告機能を再有効化予定
    return const SizedBox.shrink();

    // if (!_isAdLoaded) {
    //   print('ネイティブ広告: まだ読み込まれていません');
    //   return const SizedBox.shrink();
    // }

    // print('ネイティブ広告: 表示中');
    // return Container(
    //   margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    //   height: 70, // より小さな高さに調整
    //   child: Container(
    //     decoration: BoxDecoration(
    //       color: Colors.white,
    //       borderRadius: BorderRadius.circular(4),
    //       border: Border.all(
    //         color: Colors.grey.withOpacity(0.1),
    //         width: 0.5,
    //       ),
    //       boxShadow: [
    //         BoxShadow(
    //           color: Colors.black.withOpacity(0.02),
    //           blurRadius: 1,
    //           offset: const Offset(0, 0.5),
    //         ),
    //       ],
    //     ),
    //     child: ClipRRect(
    //       borderRadius: BorderRadius.circular(4),
    //       child: SizedBox(
    //         width: double.infinity,
    //         height: double.infinity,
    //         child: AdWidget(ad: _nativeAd!),
    //       ),
    //     ),
    //   ),
    // );
  }
}
