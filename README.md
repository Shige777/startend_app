# startend SNSアプリ

START/END投稿を軸とした進捗共有SNSアプリです。

## 機能概要

### 主要機能
- **START/END投稿**: 目標開始と完了を投稿で共有
- **軌跡表示**: 個人の投稿履歴を時系列で表示
- **コミュニティ**: 興味のあるテーマでグループを作成・参加
- **フォロー機能**: 他のユーザーをフォローして投稿を追跡
- **検索機能**: 投稿やコミュニティを検索

### 投稿の分類
- **集中** (24時間以内): 短期集中の目標
- **進行中** (24時間以上): 長期的な目標
- **完了**: END投稿済みの目標

### プライバシー設定
- 全体公開
- 相互フォローのみ
- コミュニティのみ
- 相互フォロー + コミュニティのみ

## 技術スタック

- **フレームワーク**: Flutter
- **言語**: Dart
- **バックエンド**: Firebase
  - Authentication (メール、Google、Apple ID)
  - Firestore (データベース)
  - Storage (画像保存)
  - Messaging (プッシュ通知)
- **状態管理**: Provider
- **ルーティング**: go_router

## セットアップ

### 前提条件
- Flutter SDK (最新版)
- Firebase プロジェクト
- Android Studio / Xcode (モバイル開発の場合)

### インストール

1. リポジトリをクローン
```bash
git clone https://github.com/yourusername/startend_app.git
cd startend_app
```

2. 依存関係をインストール
```bash
flutter pub get
```

3. Firebase設定
- Firebase Console でプロジェクトを作成
- `google-services.json` (Android) と `GoogleService-Info.plist` (iOS) を配置
- Firebase CLI で設定を完了

4. アプリを実行
```bash
flutter run
```

## プロジェクト構成

```
lib/
├── constants/          # 定数定義
├── models/            # データモデル
├── providers/         # 状態管理
├── screens/           # 画面
│   ├── auth/         # 認証関連
│   ├── home/         # ホーム画面
│   ├── profile/      # プロフィール関連
│   ├── post/         # 投稿関連
│   └── community/    # コミュニティ関連
├── services/          # 外部サービス連携
├── utils/            # ユーティリティ
├── widgets/          # 再利用可能なウィジェット
└── main.dart         # エントリーポイント
```

## 主要画面

### ホーム画面
- フォロー中の投稿一覧
- コミュニティ投稿一覧
- 検索機能

### 軌跡画面
- 個人の投稿履歴
- 進行中/完了の分類表示
- プライバシー設定

### 投稿作成画面
- START投稿の作成
- 画像添付
- 完了予定時刻設定

### プロフィール設定画面
- プロフィール情報編集
- プライバシー設定
- 軌跡公開範囲設定

### コミュニティ画面
- 参加コミュニティ一覧
- コミュニティ検索
- 参加申請/脱退機能

## 開発状況

### 実装済み
- [x] 基本的なアプリ構造
- [x] Firebase認証 (メール、Google、Apple)
- [x] 投稿作成・表示機能
- [x] プロフィール設定
- [x] コミュニティ参加機能
- [x] 検索機能
- [x] 軌跡表示改善

### 今後の実装予定
- [ ] END投稿機能
- [ ] プッシュ通知
- [ ] 画像アップロード
- [ ] フォロー機能の完全実装
- [ ] コミュニティ管理機能

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。
