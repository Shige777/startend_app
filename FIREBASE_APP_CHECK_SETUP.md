# Firebase App Check セットアップガイド

## 概要
Firebase App Checkは、アプリが正当なクライアントからのリクエストのみを受け入れることを保証するセキュリティ機能です。

## セットアップ手順

### 1. Firebase Consoleでの設定
1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. プロジェクトを選択
3. "App Check" セクションに移動
4. "Get started" をクリック

### 2. Android設定
1. "Apps" セクションでAndroidアプリを選択
2. "Play Integrity API" を有効化
3. デバッグトークンを設定（開発用）

### 3. iOS設定
1. "Apps" セクションでiOSアプリを選択
2. "DeviceCheck" を有効化
3. デバッグトークンを設定（開発用）

### 4. Firestoreルールの更新
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // App Check enforcement
    function isAppCheckValid() {
      return request.auth.app != null;
    }
    
    // 既存のルールにApp Checkを追加
    match /users/{userId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId 
        && isAppCheckValid();
    }
    
    match /posts/{postId} {
      allow read: if isAppCheckValid();
      allow write: if request.auth != null && isAppCheckValid();
    }
  }
}
```

### 5. Firebase Storage ルールの更新
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.app != null;
    }
  }
}
```

## 本番環境での有効化

### 警告の解決
現在のログで表示される警告：
```
Error getting App Check token; using placeholder token instead. 
Error: Firebase App Check API has not been used in project 201575475230 before or it is disabled.
```

### 解決手順
1. Firebase Console → App Check
2. "Enable API" をクリック
3. 各サービス（Firestore, Storage等）でApp Checkを有効化
4. プロダクションでの強制を有効化

## デバッグ設定
開発・テスト環境では以下のデバッグトークンを設定：
- Android: SHA-256証明書フィンガープリント
- iOS: App Store Connect の Bundle ID

## 注意事項
- App Checkを有効化すると、すべてのリクエストでトークン検証が必要
- 段階的に有効化することを推奨（まずはログのみ、その後強制）
- デバッグトークンは本番環境では無効化すること

## 参考リンク
- [Firebase App Check Documentation](https://firebase.google.com/docs/app-check)
- [App Check for Flutter](https://firebase.flutter.dev/docs/app-check/overview/)
