# Firebase Storage セキュリティルール設定ガイド

## 現在の問題
START投稿時に「アップロード権限がありません」エラーが発生しています。

## 解決方法

### 1. Firebase Console でセキュリティルールを確認

1. **Firebase Console にアクセス**
   - https://console.firebase.google.com/
   - `startend-sns-app` プロジェクトを選択

2. **Storage セクションに移動**
   - 左メニューから「Storage」を選択
   - 「Rules」タブをクリック

### 2. 推奨セキュリティルール

以下のルールを適用してください：

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // 認証されたユーザーのみアップロード可能
    match /{allPaths=**} {
      allow read: if true; // 読み取りは誰でも可能
      allow write: if request.auth != null; // 書き込みは認証済みユーザーのみ
    }
    
    // プロフィール画像
    match /profiles/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 投稿画像
    match /posts/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // コミュニティ画像
    match /communities/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### 3. より安全なルール（本番環境推奨）

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // プロフィール画像：本人のみアップロード可能
    match /profiles/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null 
                  && request.auth.uid == userId
                  && request.resource.size < 5 * 1024 * 1024; // 5MB制限
    }
    
    // 投稿画像：認証済みユーザーのみ
    match /posts/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null
                  && request.resource.size < 5 * 1024 * 1024
                  && request.resource.contentType.matches('image/.*');
    }
    
    // コミュニティ画像：認証済みユーザーのみ
    match /communities/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null
                  && request.resource.size < 5 * 1024 * 1024
                  && request.resource.contentType.matches('image/.*');
    }
    
    // その他のファイル：拒否
    match /{allPaths=**} {
      allow read: if false;
      allow write: if false;
    }
  }
}
```

### 4. 設定手順

1. **Firebase Console** → **Storage** → **Rules**
2. 上記のルールをコピー＆ペースト
3. **「公開」ボタンをクリック**
4. 変更が反映されるまで数分待つ

### 5. テスト方法

1. アプリでログイン
2. START投稿を作成
3. 画像をアップロード
4. エラーが解決されていることを確認

## 注意事項

- **開発環境**: より緩いルールでテスト
- **本番環境**: 厳格なルールで運用
- **ファイルサイズ制限**: 5MB以下を推奨
- **ファイル形式**: 画像ファイルのみ許可

## トラブルシューティング

### エラーが続く場合
1. Firebase Console でルールが正しく保存されているか確認
2. アプリでログアウト→ログインを試す
3. アプリを再起動
4. ブラウザのキャッシュをクリア

### 権限エラーの詳細確認
- アプリのコンソールログを確認
- Firebase Console の「使用状況」タブでエラーログを確認 