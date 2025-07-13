# 🏪 StartEnd App ストアベータ配信ガイド

## 📋 概要

StartEnd App のGoogle Play Store および App Store でのベータ配信準備ガイドです。
本格的なベータテストを実施するため、各ストアでの配信準備を進めます。

## 🤖 Google Play Store - ベータ配信準備

### 1. Google Play Console 設定

#### アプリの基本情報
- **アプリ名**: StartEnd App
- **パッケージ名**: `com.startend.app.startend_app`
- **カテゴリ**: ソーシャル
- **対象年齢**: 13歳以上

#### ストアの掲載情報
```
短い説明（80文字以内）:
START/END投稿でモチベーションを共有。目標達成をサポートするSNSアプリ

詳細な説明:
StartEnd Appは、目標の開始（START）と完了（END）を投稿することで、
モチベーションを維持し、目標達成をサポートするソーシャルアプリです。

主な機能:
• START/END投稿で進捗を記録
• フォロー機能でモチベーションを共有
• コミュニティ機能で同じ目標を持つ仲間と交流
• 軌跡表示で過去の成果を振り返り

あなたの目標達成を、コミュニティと一緒にサポートします。
```

#### 必要な画像・動画
- **アプリアイコン**: 512x512px (PNG)
- **フィーチャーグラフィック**: 1024x500px
- **スクリーンショット**: 
  - 電話: 最低2枚、最大8枚
  - 7インチタブレット: 最低1枚、最大8枚
  - 10インチタブレット: 最低1枚、最大8枚

### 2. アプリバンドル準備

#### 署名設定
```bash
# キーストアファイルの作成
keytool -genkey -v -keystore startend-app-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias startend-app-key

# android/key.properties ファイルの作成
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=startend-app-key
storeFile=../startend-app-release-key.jks
```

#### build.gradle.kts 設定
```kotlin
// android/app/build.gradle.kts に追加
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### AAB（Android App Bundle）ビルド
```bash
# リリースビルド
flutter build appbundle --release

# 生成されるファイル
# build/app/outputs/bundle/release/app-release.aab
```

### 3. 内部テスト設定

#### テストトラック作成
1. **内部テスト**: 開発チーム向け（最大100名）
2. **クローズドテスト**: 限定ベータテスター向け（最大1000名）
3. **オープンテスト**: 公開ベータテスト向け（制限なし）

#### テスター管理
```
内部テスト用メールアドレス:
- 開発者: developer@startend.app
- テスター: beta-tester@startend.app

クローズドテスト用Googleグループ:
- グループ名: startend-beta-testers@googlegroups.com
- 参加者: ベータテスター限定
```

### 4. アプリ審査対応

#### プライバシーポリシー
- **URL**: https://shige777.github.io/startend_app/privacy-policy.html
- **内容**: データ収集、使用目的、第三者提供について

#### データ安全性
- **収集するデータ**: 
  - 個人情報: メールアドレス、表示名
  - アプリ情報: 投稿内容、画像
  - デバイス情報: 端末識別子
- **暗号化**: 転送中・保存中ともに暗号化
- **削除**: ユーザーによる削除可能

#### 対象年齢とコンテンツ評価
- **対象年齢**: 13歳以上
- **コンテンツ評価**: 全年齢対象
- **広告**: なし

## 🍎 App Store - ベータ配信準備

### 1. App Store Connect 設定

#### アプリの基本情報
- **アプリ名**: StartEnd App
- **Bundle ID**: `com.startend.app.startendApp`
- **SKU**: startend-app-ios
- **カテゴリ**: ソーシャルネットワーキング

#### ストアの掲載情報
```
サブタイトル（30文字以内）:
目標達成をサポートするSNS

説明（4000文字以内）:
StartEnd Appは、目標の開始（START）と完了（END）を投稿することで、
モチベーションを維持し、目標達成をサポートするソーシャルアプリです。

【主な機能】
▸ START/END投稿
目標の開始と完了を記録し、進捗を可視化

▸ ソーシャル機能
フォロー機能でモチベーションを共有
いいね機能で相互に応援

▸ コミュニティ機能
同じ目標を持つ仲間と交流
コミュニティ内でのチャット機能

▸ 軌跡表示
過去の投稿を時系列で表示
期間別フィルターで成果を振り返り

【こんな方におすすめ】
• 目標達成を習慣化したい
• モチベーションを維持したい
• 同じ目標を持つ仲間と交流したい
• 進捗を可視化したい

あなたの目標達成を、コミュニティと一緒にサポートします。
```

#### 必要な画像・動画
- **アプリアイコン**: 1024x1024px (PNG)
- **スクリーンショット**:
  - iPhone: 最低1枚、最大10枚
  - iPad: 最低1枚、最大10枚
- **アプリプレビュー**: 最大3本（オプション）

### 2. Xcode プロジェクト設定

#### Bundle Identifier 統一
```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleIdentifier</key>
<string>com.startend.app.startendApp</string>
```

#### 署名設定
1. **Apple Developer Account**: 年間99ドル
2. **Certificates**: Distribution Certificate
3. **Provisioning Profiles**: App Store Distribution

#### iOS ビルド
```bash
# iOS リリースビルド
flutter build ios --release

# Xcode でアーカイブ
# Product > Archive > Distribute App
```

### 3. TestFlight 設定

#### 内部テスト
- **対象**: 開発チーム（最大100名）
- **審査**: 不要
- **配信**: 即座に配信可能

#### 外部テスト
- **対象**: 外部ベータテスター（最大10,000名）
- **審査**: Apple審査が必要
- **配信**: 審査通過後に配信

#### テスター招待
```
招待方法:
1. メールアドレスで個別招待
2. 公開リンクでの招待
3. グループ単位での招待

テスター情報:
- 名前
- メールアドレス
- テストグループ
```

### 4. App Review 対応

#### App Store Review Guidelines
- **4.0 Design**: ユーザーインターフェース
- **5.0 Legal**: プライバシーポリシー
- **2.0 Performance**: アプリの安定性

#### 必要な準備
- **デモアカウント**: 審査用テストアカウント
- **プライバシーポリシー**: 必須
- **利用規約**: 推奨

## 🔧 共通準備事項

### 1. アプリバージョン管理

#### pubspec.yaml
```yaml
version: 1.0.0+1  # ベータ版
# 1.0.0: セマンティックバージョン
# +1: ビルド番号
```

#### バージョン戦略
```
ベータ版: 1.0.0+1, 1.0.0+2, ...
RC版: 1.0.0+10, 1.0.0+11, ...
正式版: 1.0.0+20
```

### 2. Firebase 設定

#### プロジェクト設定
- **プロジェクト名**: startend-sns-app
- **プラットフォーム**: iOS, Android, Web
- **認証**: Google, Apple, Email

#### セキュリティ設定
- **Firestore Rules**: 本番環境用
- **Storage Rules**: 本番環境用
- **App Check**: 有効化

### 3. 法的準備

#### プライバシーポリシー
```
必須項目:
• 収集する情報の種類
• 情報の使用目的
• 第三者への提供
• データの保存期間
• ユーザーの権利
• 連絡先情報
```

#### 利用規約
```
必須項目:
• サービスの利用条件
• 禁止事項
• 免責事項
• 知的財産権
• サービスの変更・終了
```

### 4. サポート体制

#### サポートチャンネル
- **メール**: support@startend.app
- **GitHub Issues**: 技術的な問題
- **FAQ**: よくある質問

#### 対応言語
- **日本語**: メイン対応
- **英語**: 将来的に対応予定

## 📅 ベータ配信スケジュール

### Phase 1: 内部テスト（1週間）
- **対象**: 開発チーム
- **目的**: 基本機能の動作確認
- **配信**: Google Play (内部テスト), TestFlight (内部テスト)

### Phase 2: クローズドベータ（2週間）
- **対象**: 限定ベータテスター（50名）
- **目的**: 実用性テスト
- **配信**: Google Play (クローズドテスト), TestFlight (外部テスト)

### Phase 3: オープンベータ（2週間）
- **対象**: 一般ユーザー（500名）
- **目的**: 大規模テスト
- **配信**: Google Play (オープンテスト), TestFlight (外部テスト)

### Phase 4: 正式リリース
- **対象**: 全ユーザー
- **配信**: Google Play Store, App Store

## 🎯 ベータテスト目標

### 技術的目標
- **クラッシュ率**: 0.1%未満
- **ANR率**: 0.1%未満
- **起動時間**: 3秒以内
- **メモリ使用量**: 200MB以下

### ユーザー体験目標
- **ユーザー満足度**: 4.0以上
- **継続率**: 1週間で50%以上
- **投稿率**: 1日1回以上

### フィードバック収集
- **アプリ内フィードバック**: 評価・コメント機能
- **ストアレビュー**: 評価・レビュー分析
- **直接フィードバック**: メール・GitHub Issues

## 📊 分析・監視

### アプリ分析
- **Firebase Analytics**: ユーザー行動分析
- **Crashlytics**: クラッシュ監視
- **Performance Monitoring**: パフォーマンス監視

### ストア分析
- **Google Play Console**: ダウンロード数、評価
- **App Store Connect**: ダウンロード数、評価
- **TestFlight**: ベータテスト参加状況

## 🚀 正式リリース準備

### 成功指標
- **ベータテスト完了**: 全フェーズ完了
- **重大バグ**: 0件
- **ユーザー満足度**: 4.0以上
- **ストア審査**: 通過

### リリース戦略
1. **ソフトローンチ**: 日本先行リリース
2. **グローバル展開**: 段階的な地域拡大
3. **マーケティング**: SNS・メディア展開

---

**ベータ配信準備を進めて、より多くのユーザーに StartEnd App を届けましょう！** 