# TestFlight ベータリリース手順ガイド

## 📋 事前準備

### 1. Apple Developer Program 登録確認
- Apple Developer Program に年額 $99 で登録済みであることを確認
- App Store Connect へのアクセス権限確認

### 2. 必要なツール・アカウント
- Xcode (最新版)
- Apple ID (Developer Program登録済み)
- macOS (Xcode実行環境)

### 3. アプリID・証明書の準備
- Bundle ID: `com.startend.app`
- App Store Connect でアプリを事前登録

## 🚀 TestFlight リリース手順

### Step 1: アプリの App Store Connect 登録

1. **App Store Connect にログイン**
   - [https://appstoreconnect.apple.com](https://appstoreconnect.apple.com)

2. **新しいアプリを作成**
   ```
   アプリ名: StartEnd
   Bundle ID: com.startend.app
   SKU: startend-app-001 (任意の一意な値)
   プラットフォーム: iOS
   ```

3. **基本情報を設定**
   - アプリ名: StartEnd
   - サブタイトル: 進捗共有SNS
   - カテゴリ: ソーシャルネットワーキング
   - 年齢制限: 4+

### Step 2: ローカルでのビルド

1. **ビルドスクリプトを実行**
   ```bash
   ./scripts/build_ios.sh
   ```

2. **Xcode でプロジェクトを開く**
   ```bash
   open ios/Runner.xcworkspace
   ```

3. **Signing & Capabilities 設定**
   - Team: あなたのDeveloper Team を選択
   - Bundle Identifier: `com.startend.app` に設定
   - Automatically manage signing: ✅ 有効

### Step 3: アーカイブ作成

1. **デバイス設定**
   - Xcode上部で 「Any iOS Device (arm64)」を選択

2. **アーカイブ実行**
   - Menu: `Product` → `Archive`
   - ビルドが完了するまで待機（5-10分程度）

3. **Organizer で確認**
   - アーカイブが正常に作成されたことを確認
   - 「Distribute App」をクリック

### Step 4: App Store Connect にアップロード

1. **配信方法選択**
   - 「App Store Connect」を選択
   - 「Next」をクリック

2. **配信オプション**
   - 「Upload」を選択（デフォルト）
   - 「Next」をクリック

3. **配信オプション詳細**
   - すべてチェックボックスを有効のまま
   - 「Next」をクリック

4. **自動署名**
   - 「Automatically manage signing」を選択
   - 「Next」をクリック

5. **最終確認・アップロード**
   - 設定内容を確認
   - 「Upload」をクリック
   - アップロード完了まで待機（10-30分）

### Step 5: TestFlight 設定

1. **App Store Connect でアプリを確認**
   - アップロードされたビルドが表示されるまで待機
   - 処理には最大1時間程度かかる場合があります

2. **テスト情報を設定**
   ```
   ベータ版アプリの説明:
   StartEndの新機能をテストしていただけるベータ版です。
   
   フィードバック用メール: your.email@example.com
   
   テスト対象:
   - START/END投稿機能
   - コミュニティ・チャット機能  
   - Google Sign-In認証
   - 招待URL機能
   ```

3. **内部テスト設定**
   - 「Internal Testing」タブを選択
   - 新しいグループを作成: "Internal Team"
   - 開発チームメンバーを追加

4. **外部テスト設定（任意）**
   - 「External Testing」タブを選択
   - 新しいグループを作成: "Beta Users"
   - 外部テスターのメールアドレスを追加

## 📱 テスター向け案内

### テスターへの招待メール例

```
件名: StartEnd アプリ ベータテストのご案内

StartEndアプリのベータテストにご参加いただき、ありがとうございます。

【テスト内容】
- START/END投稿の作成・表示
- コミュニティ参加・チャット
- 招待URL機能

【テスト手順】
1. 以下のリンクから TestFlight アプリをダウンロード
   https://apps.apple.com/jp/app/testflight/id899247664

2. TestFlight で StartEnd アプリをインストール

3. アプリを実際に使用してフィードバックをお聞かせください

【フィードバック方法】
- TestFlight アプリ内のフィードバック機能
- メール: your.email@example.com

テスト期間: 2週間
ご質問があればお気軽にお声がけください。
```

## 🐛 トラブルシューティング

### よくある問題と解決方法

1. **Xcode でアーカイブできない**
   ```
   解決方法:
   - Build Settings で Code Signing 設定を確認
   - Developer Team が正しく設定されているか確認
   - Bundle ID が重複していないか確認
   ```

2. **App Store Connect にアップロードできない**
   ```
   解決方法:
   - インターネット接続を確認
   - Apple ID の権限を確認
   - Application Specific Password が必要な場合があります
   ```

3. **TestFlight でビルドが表示されない**
   ```
   解決方法:
   - アップロード後、処理完了まで最大1時間待機
   - App Store Connect でビルドのステータスを確認
   - メールで通知が来るまで待機
   ```

4. **テスターがアプリをインストールできない**
   ```
   解決方法:
   - テスターが TestFlight アプリをインストール済みか確認
   - 招待メールのリンクが有効か確認
   - デバイスが対応バージョン（iOS 12.0以上）か確認
   ```

## 📊 次のステップ

### ベータテスト完了後
1. **フィードバック収集・分析**
2. **重要な修正の実装**
3. **新しいビルドのアップロード**
4. **最終的な App Store 申請準備**

### App Store 正式リリース
1. **スクリーンショット撮影**
2. **アプリストア詳細情報の記入**
3. **レビュー用情報の準備**
4. **App Store 申請** 