#!/bin/bash

# iOS App Store リリース用ビルドスクリプト
# 使用方法: ./scripts/build_ios.sh

set -e

echo "🚀 StartEnd App - iOS App Store ビルド開始"
echo "========================================"

# 作業ディレクトリをプロジェクトルートに移動
cd "$(dirname "$0")/.."

# 1. 依存関係のクリーンアップとインストール
echo "📦 依存関係をクリーンアップ中..."
flutter clean

echo "📦 依存関係をインストール中..."
flutter pub get

# 2. iOS依存関係の更新
echo "🍎 iOSの依存関係を更新中..."
cd ios
pod cache clean --all
pod deintegrate
pod install --repo-update
cd ..

# 3. ビルド設定の確認
echo "🔧 ビルド設定を確認中..."
echo "Bundle ID: com.startend.app"
echo "Version: $(grep 'version:' pubspec.yaml | awk '{print $2}')"

# 4. アプリアイコンの確認
if [ ! -f "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json" ]; then
    echo "⚠️  警告: アプリアイコンが設定されていません"
    echo "   ios/Runner/Assets.xcassets/AppIcon.appiconsetにアイコンを追加してください"
fi

# 5. リリースビルドの実行
echo "🔨 リリースビルドを実行中..."
flutter build ios --release --no-codesign

echo "✅ ビルド完了！"
echo ""
echo "📱 次のステップ:"
echo "1. Xcodeで ios/Runner.xcworkspace を開く"
echo "2. Signing & Capabilities で Developer Team を設定"
echo "3. Product > Archive でアーカイブを作成"
echo "4. Organizer から App Store Connect にアップロード"
echo ""
echo "🧪 TestFlight ベータテスト:"
echo "1. App Store Connect でアプリを確認"
echo "2. TestFlight でベータ版として配信"
echo "3. 内部テスターまたは外部テスターに招待メール送信" 