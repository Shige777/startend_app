# セキュリティ設定手順

## 🔐 Firebase設定ファイルの準備

このプロジェクトでは、セキュリティのためFirebase設定ファイルをGitから除外しています。
開発環境でアプリを実行するには、以下の設定が必要です。

### 1. Firebase設定ファイルの作成

#### `lib/firebase_options.dart`
1. `lib/firebase_options.dart.template` をコピーして `lib/firebase_options.dart` を作成
2. FirebaseコンソールからプロジェクトのAPI情報を取得
3. テンプレート内の `YOUR_*` プレースホルダーを実際の値に置き換え

#### Android用設定
1. Firebaseコンソールから `google-services.json` をダウンロード
2. `android/app/google-services.json` に配置

#### iOS用設定
1. Firebaseコンソールから `GoogleService-Info.plist` をダウンロード
2. `ios/Runner/GoogleService-Info.plist` に配置

### 2. Web用設定

#### 環境変数の設定
Web版をデプロイする際は、以下の環境変数を設定：

```bash
FIREBASE_API_KEY=your_web_api_key
GOOGLE_SIGNIN_CLIENT_ID=your_google_signin_client_id
```

#### 設定ファイルの更新
- `web/index.html` と `web/firebase-messaging-sw.js` の `${FIREBASE_API_KEY}` を実際のAPIキーに置き換え
- `web/index.html` の `${GOOGLE_SIGNIN_CLIENT_ID}` を実際のGoogle Sign-In Client IDに置き換え

### 3. 重要な注意事項

⚠️ **絶対にやってはいけないこと:**
- Firebase設定ファイルをGitにコミット
- APIキーをコードに直接記述
- 機密情報を含むファイルをGitHubに公開

✅ **推奨事項:**
- 環境変数を使用してAPIキーを管理
- デプロイ時にCI/CDパイプラインで設定を注入
- 定期的にAPIキーをローテーション

### 4. 現在の除外設定

`.gitignore` で以下のファイルが除外されています：
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`

これらのファイルは各開発者が個別に設定する必要があります。

### 5. 本番リリース前の確認事項

#### Bundle Identifierの確認
- iOS: `com.example.startendapp` → 本番用に変更を推奨
- Android: `com.startend.app.startend_app` → 統一性を確認

#### デバッグ情報の削除
- 本番ビルドでは `kDebugMode` でデバッグ情報が自動的に除外されます
- 必要に応じて追加のログ出力を削除してください

#### 署名設定
- Android: 本番用keystoreファイルを作成し、適切に設定
- iOS: App Store Connect用の証明書を設定

#### セキュリティルール
- Firestore、Firebase Storageのセキュリティルールを本番環境に適用
- 必要に応じてAPIキーの制限を設定 