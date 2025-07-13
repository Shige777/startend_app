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

## 🛡️ セキュリティルールの強化

### Firestore セキュリティルール
以下のセキュリティ対策が実装されています：

#### データバリデーション
- **ユーザー情報**: 表示名50文字制限、メールアドレス形式チェック
- **投稿**: タイトル100文字制限、コメント500文字制限
- **コミュニティ**: 名前50文字制限、説明200文字制限、メンバー8人制限

#### アクセス制御
- **プライベートアカウント**: フォロワーのみアクセス可能
- **投稿プライバシー**: 公開/コミュニティのみの設定
- **コミュニティ**: リーダー・メンバーのみ編集可能

#### 不正操作防止
- **自己フォロー防止**: 自分自身をフォローできない
- **投稿改ざん防止**: 作成者のみ編集可能
- **メールアドレス変更防止**: 一度設定したメールアドレスは変更不可

### Firebase Storage セキュリティルール
以下の制限が設定されています：

#### ファイル制限
- **プロフィール画像**: 10MB制限、JPEG/PNG/WebP/GIF形式のみ
- **投稿画像**: 10MB制限、JPEG/PNG/WebP/GIF形式のみ
- **コミュニティ画像**: 5MB制限、JPEG/PNG/WebP/GIF形式のみ

#### アクセス制御
- **プロフィール画像**: 本人のみアップロード可能
- **投稿画像**: 本人のみアップロード可能
- **すべての画像**: 認証済みユーザーのみ読み取り可能

## 🔒 本番環境での追加セキュリティ対策

### 1. Firebase プロジェクト設定

#### App Check の有効化
```bash
# Firebase CLI でApp Check を有効化
firebase app-check:enable --project=your-project-id
```

#### API キーの制限
- **Android**: パッケージ名とSHA-1フィンガープリントで制限
- **iOS**: Bundle IDで制限
- **Web**: HTTPリファラーで制限

### 2. 認証セキュリティ

#### パスワード要件
- 最小6文字（Firebase Auth デフォルト）
- 複雑なパスワードの推奨をUI上で表示

#### OAuth設定
- **Google Sign-In**: 本番用OAuth同意画面を設定
- **Apple Sign-In**: 本番用Service IDを設定

### 3. データ保護

#### 個人情報の暗号化
- プロフィール画像URLは署名付きURLを使用
- 機密データのクライアント側暗号化（必要に応じて）

#### データ保持期間
- 削除されたアカウントのデータは30日後に完全削除
- 投稿データのバックアップは90日間保持

### 4. 監視とログ

#### Firebase Analytics
- 異常なアクセスパターンの検出
- セキュリティインシデントの追跡

#### Cloud Logging
- 認証失敗の監視
- 不正アクセスの検出

## ⚠️ 重要な注意事項

### 絶対にやってはいけないこと
- Firebase設定ファイルをGitにコミット
- APIキーをコードに直接記述
- 機密情報を含むファイルをGitHubに公開
- 本番環境でデバッグモードを有効化
- セキュリティルールを緩和する

### 推奨事項
- 環境変数を使用してAPIキーを管理
- デプロイ時にCI/CDパイプラインで設定を注入
- 定期的にAPIキーをローテーション
- セキュリティルールの定期的な見直し
- 脆弱性スキャンの実施

### 4. 現在の除外設定

`.gitignore` で以下のファイルが除外されています：
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`

これらのファイルは各開発者が個別に設定する必要があります。

## 🚀 本番リリース前の確認事項

### Bundle Identifierの統一
- **iOS**: `com.startend.app` 形式に統一
- **Android**: `com.startend.app.startend_app` 形式に統一
- **Web**: ドメイン名との整合性確認

### デバッグ情報の削除
- 本番ビルドでは `kDebugMode` でデバッグ情報が自動的に除外
- コンソールログの出力を最小限に抑制
- エラーログのみ本番環境で出力

### 署名設定
- **Android**: 本番用keystoreファイルを作成し、適切に設定
- **iOS**: App Store Connect用の証明書を設定
- **署名証明書**: 安全な場所に保管

### セキュリティルールのデプロイ
```bash
# Firestore ルールのデプロイ
firebase deploy --only firestore:rules

# Storage ルールのデプロイ
firebase deploy --only storage
```

### パフォーマンス最適化
- 画像圧縮の有効化
- 不要なデバッグコードの削除
- バンドルサイズの最適化

## 🔍 セキュリティテスト

### 実施すべきテスト
1. **認証テスト**: 不正ログインの防止
2. **認可テスト**: 他人のデータへのアクセス防止
3. **入力検証テスト**: SQLインジェクション等の防止
4. **ファイルアップロードテスト**: 不正ファイルの防止
5. **セッション管理テスト**: セッションハイジャックの防止

### 自動化ツール
- Firebase Security Rules テスト
- OWASP ZAP による脆弱性スキャン
- 依存関係の脆弱性チェック

## 📞 インシデント対応

### セキュリティインシデント発生時
1. **即座に対応**: 影響範囲の特定と緊急対応
2. **ログ収集**: 関連するログの保全
3. **ユーザー通知**: 必要に応じてユーザーへの通知
4. **対策実施**: 脆弱性の修正とセキュリティ強化
5. **事後検証**: 再発防止策の実施

### 連絡先
- **開発者**: [@Shige777](https://github.com/Shige777)
- **GitHub Issues**: セキュリティ関連は非公開で報告

---

*このドキュメントは定期的に更新され、最新のセキュリティ対策を反映しています。* 