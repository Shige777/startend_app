# Flutter用のProGuardルール

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# AdMob
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Gson (Firebase用)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# 画像処理ライブラリ
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# OkHttp (ネットワーク)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# その他のよく使用されるライブラリ
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**

# デバッグ情報を保持
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# アプリ固有のモデルクラス
-keep class ** implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# エラーレポート用の行番号を保持
-keepattributes LineNumberTable,SourceFile
-renamesourcefileattribute SourceFile