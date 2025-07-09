#!/bin/bash

# StartEnd App APK Build Script
# このスクリプトはAndroid APKファイルを生成します

echo "🚀 StartEnd App APK ビルド開始"

# Flutter環境の確認
echo "📱 Flutter環境の確認..."
flutter --version

# 依存関係の取得
echo "📦 依存関係の取得..."
flutter pub get

# APKビルド
echo "🔨 APKビルド中..."
flutter build apk --release

# 結果の確認
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo "✅ APKビルド成功！"
    echo "📍 APKファイル: build/app/outputs/flutter-apk/app-release.apk"
    
    # ファイルサイズを表示
    echo "📊 APKファイルサイズ:"
    ls -lh build/app/outputs/flutter-apk/app-release.apk
    
    # releasesフォルダにコピー
    mkdir -p releases
    cp build/app/outputs/flutter-apk/app-release.apk releases/startend-app-$(date +%Y%m%d).apk
    echo "📁 リリースフォルダにコピー完了: releases/startend-app-$(date +%Y%m%d).apk"
else
    echo "❌ APKビルド失敗"
    exit 1
fi

echo "🎉 ビルド完了！" 