import 'package:flutter/material.dart';

class AppColors {
  // プライマリーカラー（黒系）
  static const Color primary = Color(0xFF000000); // 黒
  static const Color primaryDark = Color(0xFF212121); // ダークグレー
  static const Color primaryLight = Color(0xFF424242); // グレー

  // アクセントカラー
  static const Color accent = Color(0xFF424242); // グレー
  static const Color accentDark = Color(0xFF212121); // ダークグレー
  static const Color accentLight = Color(0xFFE0E0E0); // ライトグレー

  // セカンダリーカラー
  static const Color secondary = Color(0xFF424242); // グレー

  // リアクション用（黒系）
  static const Color flame = Color(0xFF000000); // 黒
  static const Color flameGlow = Color(0xFF212121); // ダークグレー

  // 背景色
  static const Color background = Color(0xFFFFFFFF); // 白に変更
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFFFFFF); // 白に変更

  // テキストカラー
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ステータスカラー
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFF000000); // 黒に変更
  static const Color info = Color(0xFF000000); // 黒に変更

  // 投稿タイプ別カラー
  static const Color concentration = Color(0xFFFFFFFF); // 白に変更
  static const Color inProgress = Color(0xFF000000); // 黒に変更
  static const Color completed = Color(0xFF4CAF50);

  // その他
  static const Color divider = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1A000000);
  static const Color transparent = Color(0x00000000);
}
