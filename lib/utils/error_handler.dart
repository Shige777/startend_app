import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ErrorHandler {
  /// エラーをユーザーフレンドリーなメッセージに変換
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getAuthErrorMessage(error);
    } else if (error is FirebaseException) {
      return _getFirebaseErrorMessage(error);
    } else if (error is Exception) {
      // 詳細なエラー情報は開発時のみ表示
      final errorMessage = error.toString().replaceFirst('Exception: ', '');
      if (kDebugMode) {
        return errorMessage;
      } else {
        return 'エラーが発生しました。しばらくしてからもう一度お試しください。';
      }
    } else {
      return 'エラーが発生しました。しばらくしてからもう一度お試しください。';
    }
  }

  /// Firebase Auth エラーメッセージ
  static String _getAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'このメールアドレスは登録されていません。';
      case 'wrong-password':
        return 'パスワードが間違っています。';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています。';
      case 'weak-password':
        return 'パスワードが弱すぎます。6文字以上で設定してください。';
      case 'invalid-email':
        return '無効なメールアドレスです。';
      case 'operation-not-allowed':
        return 'この認証方法は無効です。';
      case 'account-exists-with-different-credential':
        return 'このメールアドレスは別の認証方法で登録されています。';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました。接続を確認してください。';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらくしてからもう一度お試しください。';
      default:
        return 'ログインエラーが発生しました: ${error.message}';
    }
  }

  /// Firebase エラーメッセージ
  static String _getFirebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'アクセス権限がありません。';
      case 'not-found':
        return 'データが見つかりません。';
      case 'already-exists':
        return 'データは既に存在します。';
      case 'resource-exhausted':
        return 'リソースが不足しています。しばらくしてからもう一度お試しください。';
      case 'failed-precondition':
        return '操作の前提条件が満たされていません。';
      case 'aborted':
        return '操作が中断されました。もう一度お試しください。';
      case 'out-of-range':
        return '無効な範囲の値が指定されました。';
      case 'unimplemented':
        return 'この機能はまだ実装されていません。';
      case 'internal':
        return 'サーバー内部エラーが発生しました。';
      case 'unavailable':
        return 'サービスが一時的に利用できません。';
      case 'deadline-exceeded':
        return 'タイムアウトしました。もう一度お試しください。';
      default:
        return 'エラーが発生しました: ${error.message}';
    }
  }

  /// エラーダイアログを表示
  static void showErrorDialog(BuildContext context, dynamic error,
      {String? title}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'エラー'),
        content: Text(getErrorMessage(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// エラースナックバーを表示
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getErrorMessage(error)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '閉じる',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// ネットワークエラーかどうかを判定
  static bool isNetworkError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'network-request-failed' ||
          error.code == 'unavailable';
    }
    return false;
  }

  /// リトライ可能なエラーかどうかを判定
  static bool isRetryableError(dynamic error) {
    if (error is FirebaseException) {
      return [
        'aborted',
        'deadline-exceeded',
        'internal',
        'resource-exhausted',
        'unavailable',
        'network-request-failed',
      ].contains(error.code);
    }
    return false;
  }
}
