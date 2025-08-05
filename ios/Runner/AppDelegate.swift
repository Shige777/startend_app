import UIKit
import Flutter
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // ネイティブ広告ファクトリーを登録
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "listTile",
      nativeAdFactory: NativeAdFactory()
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    // ネイティブ広告ファクトリーを削除
    FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(self, factoryId: "listTile")
  }
}

// ネイティブ広告ファクトリー
class NativeAdFactory : FLTNativeAdFactory {
  func createNativeAd(_ nativeAd: NativeAd,
                      customOptions: [AnyHashable : Any]? = nil) -> NativeAdView? {
    // NIBファイルの読み込みを回避し、プログラムでビューを作成
    let nativeAdView = NativeAdView()
    nativeAdView.backgroundColor = UIColor.white
    
    // ヘッドラインラベル
    let headlineLabel = UILabel()
    headlineLabel.text = nativeAd.headline
    headlineLabel.font = UIFont.boldSystemFont(ofSize: 14)
    headlineLabel.textColor = UIColor.black
    headlineLabel.numberOfLines = 1
    headlineLabel.lineBreakMode = .byTruncatingTail
    headlineLabel.translatesAutoresizingMaskIntoConstraints = false
    nativeAdView.addSubview(headlineLabel)
    
    // ボディラベル
    let bodyLabel = UILabel()
    bodyLabel.text = nativeAd.body
    bodyLabel.font = UIFont.systemFont(ofSize: 12)
    bodyLabel.textColor = UIColor.darkGray
    bodyLabel.numberOfLines = 2
    bodyLabel.lineBreakMode = .byTruncatingTail
    bodyLabel.translatesAutoresizingMaskIntoConstraints = false
    nativeAdView.addSubview(bodyLabel)
    
    // コールトゥアクションボタン
    let callToActionButton = UIButton(type: .system)
    callToActionButton.setTitle(nativeAd.callToAction, for: .normal)
    callToActionButton.backgroundColor = UIColor.systemBlue
    callToActionButton.setTitleColor(UIColor.white, for: .normal)
    callToActionButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
    callToActionButton.layer.cornerRadius = 4
    callToActionButton.translatesAutoresizingMaskIntoConstraints = false
    nativeAdView.addSubview(callToActionButton)
    
    // アイコン画像ビュー
    let iconImageView = UIImageView()
    iconImageView.image = nativeAd.icon?.image
    iconImageView.contentMode = .scaleAspectFit
    iconImageView.clipsToBounds = true
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    nativeAdView.addSubview(iconImageView)
    
    // 制約を設定（境界内に収める）
    NSLayoutConstraint.activate([
      // アイコン
      iconImageView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 4),
      iconImageView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 4),
      iconImageView.widthAnchor.constraint(equalToConstant: 48),
      iconImageView.heightAnchor.constraint(equalToConstant: 48),
      iconImageView.bottomAnchor.constraint(lessThanOrEqualTo: nativeAdView.bottomAnchor, constant: -4),
      
      // ヘッドライン
      headlineLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 4),
      headlineLabel.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 4),
      headlineLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -4),
      
      // ボディ
      bodyLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 4),
      bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 2),
      bodyLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -4),
      
      // ボタン
      callToActionButton.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 4),
      callToActionButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 4),
      callToActionButton.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -4),
      callToActionButton.heightAnchor.constraint(equalToConstant: 24),
      callToActionButton.bottomAnchor.constraint(lessThanOrEqualTo: nativeAdView.bottomAnchor, constant: -4)
    ])
    
    // 広告の要素を設定
    nativeAdView.headlineView = headlineLabel
    nativeAdView.bodyView = bodyLabel
    nativeAdView.callToActionView = callToActionButton
    nativeAdView.iconView = iconImageView
    nativeAdView.nativeAd = nativeAd
    
    return nativeAdView
  }
}
