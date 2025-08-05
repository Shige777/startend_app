import 'dart:io';

class InputValidator {
  // 危険な文字列パターン
  static final List<RegExp> _dangerousPatterns = [
    RegExp(r'<script', caseSensitive: false),
    RegExp(r'javascript:', caseSensitive: false),
    RegExp(r'vbscript:', caseSensitive: false),
    RegExp(r'onload=', caseSensitive: false),
    RegExp(r'onerror=', caseSensitive: false),
    RegExp(r'onclick=', caseSensitive: false),
  ];

  // 不適切な言葉（基本的なもの）
  static final List<String> _inappropriateWords = [
    // 基本的な不適切な言葉をここに追加
    // 実際の実装では、より包括的なリストまたは外部APIを使用することを推奨
  ];

  /// テキストの基本検証
  static ValidationResult validateText(String text, {
    int maxLength = 1000,
    bool allowEmpty = false,
    bool checkInappropriate = true,
  }) {
    // 空文字チェック
    if (text.trim().isEmpty && !allowEmpty) {
      return ValidationResult(false, 'テキストを入力してください。');
    }

    // 長さチェック
    if (text.length > maxLength) {
      return ValidationResult(false, '${maxLength}文字以内で入力してください。');
    }

    // 危険なパターンチェック
    for (final pattern in _dangerousPatterns) {
      if (pattern.hasMatch(text)) {
        return ValidationResult(false, '不正な文字列が含まれています。');
      }
    }

    // 不適切な言葉チェック
    if (checkInappropriate) {
      final lowerText = text.toLowerCase();
      for (final word in _inappropriateWords) {
        if (lowerText.contains(word.toLowerCase())) {
          return ValidationResult(false, '不適切な内容が含まれています。');
        }
      }
    }

    return ValidationResult(true, null);
  }

  /// メールアドレス検証
  static ValidationResult validateEmail(String email) {
    if (email.trim().isEmpty) {
      return ValidationResult(false, 'メールアドレスを入力してください。');
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return ValidationResult(false, '有効なメールアドレスを入力してください。');
    }

    return ValidationResult(true, null);
  }

  /// パスワード検証
  static ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult(false, 'パスワードを入力してください。');
    }

    if (password.length < 6) {
      return ValidationResult(false, 'パスワードは6文字以上で入力してください。');
    }

    if (password.length > 128) {
      return ValidationResult(false, 'パスワードは128文字以内で入力してください。');
    }

    // 基本的なパスワード強度チェック
    bool hasLetter = password.contains(RegExp(r'[a-zA-Z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    
    if (!hasLetter || !hasDigit) {
      return ValidationResult(false, 'パスワードは英数字を含む必要があります。');
    }

    return ValidationResult(true, null);
  }

  /// 表示名検証
  static ValidationResult validateDisplayName(String name) {
    if (name.trim().isEmpty) {
      return ValidationResult(false, '表示名を入力してください。');
    }

    if (name.length > 50) {
      return ValidationResult(false, '表示名は50文字以内で入力してください。');
    }

    // 危険なパターンチェック
    for (final pattern in _dangerousPatterns) {
      if (pattern.hasMatch(name)) {
        return ValidationResult(false, '不正な文字列が含まれています。');
      }
    }

    return ValidationResult(true, null);
  }

  /// 投稿タイトル検証
  static ValidationResult validatePostTitle(String title) {
    return validateText(
      title,
      maxLength: 100,
      allowEmpty: true,
      checkInappropriate: true,
    );
  }

  /// 投稿コメント検証
  static ValidationResult validatePostComment(String comment) {
    return validateText(
      comment,
      maxLength: 500,
      allowEmpty: true,
      checkInappropriate: true,
    );
  }

  /// ファイルサイズ検証
  static ValidationResult validateFileSize(File file, {int maxSizeInMB = 5}) {
    final fileSize = file.lengthSync();
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024;

    if (fileSize > maxSizeInBytes) {
      return ValidationResult(false, 'ファイルサイズは${maxSizeInMB}MB以下にしてください。');
    }

    return ValidationResult(true, null);
  }

  /// 画像ファイル拡張子検証
  static ValidationResult validateImageExtension(String filePath) {
    final allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final extension = filePath.toLowerCase().split('.').last;

    if (!allowedExtensions.any((ext) => ext.endsWith(extension))) {
      return ValidationResult(false, '対応していないファイル形式です。JPG、PNG、GIF、WebPファイルを選択してください。');
    }

    return ValidationResult(true, null);
  }

  /// URLの検証
  static ValidationResult validateUrl(String url) {
    if (url.trim().isEmpty) {
      return ValidationResult(true, null); // URLは任意の場合が多い
    }

    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return ValidationResult(false, '有効なURLを入力してください。');
      }
    } catch (e) {
      return ValidationResult(false, '有効なURLを入力してください。');
    }

    return ValidationResult(true, null);
  }
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult(this.isValid, this.errorMessage);
}