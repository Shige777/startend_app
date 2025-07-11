import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../firebase_options.dart'; // Added for DefaultFirebaseOptions

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  String? get currentUserId => _user?.uid;

  // コンストラクタ
  AuthProvider() {
    // Google Sign-Inの設定を初期化
    _initializeGoogleSignIn();

    _auth.authStateChanges().listen((User? user) {
      if (kDebugMode) {
        print('Auth state changed: ${user?.uid}');
      }
      _user = user;
      notifyListeners();
    });

    // 現在のユーザーを取得
    _user = _auth.currentUser;

    if (kDebugMode) {
      print('Current user on init: ${_user?.uid ?? 'null'}');
    }
  }

  // Google Sign-Inの初期化
  void _initializeGoogleSignIn() {
    if (kIsWeb) {
      // Web環境用の設定 - Firebase ConsoleのWeb Client IDを使用
      _googleSignIn = GoogleSignIn(
        clientId:
            '201575475230-b626ctmas0d2rocgpkr1hdnbtmpmnh0r.apps.googleusercontent.com',
      );
    } else {
      // モバイル環境用の設定
      // iOS用に明示的にClient IDを設定
      _googleSignIn = GoogleSignIn(
        clientId:
            '201575475230-lsfr1s52m5csfnb7n6f03355tvp00b1l.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
    }

    if (kDebugMode) {
      print('Google Sign-In initialized for ${kIsWeb ? 'Web' : 'Mobile'}');
      print('Client ID: ${_googleSignIn.clientId}');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // メールアドレスでサインアップ
  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = result.user;
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError('予期しないエラーが発生しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // メールアドレスでサインイン
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = result.user;
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError('予期しないエラーが発生しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Googleサインイン
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _setError(null);

      if (kDebugMode) {
        print('=== Google Sign-In Debug Info ===');
        print('Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
        print('Current User: ${_googleSignIn.currentUser?.email ?? 'None'}');
        print('Starting Google Sign-In...');
      }

      // 既存のサインイン状態をクリア
      try {
        await _googleSignIn.signOut();
        if (kDebugMode) {
          print('Cleared existing sign-in state');
        }
      } catch (e) {
        if (kDebugMode) {
          print('No existing sign-in to clear: $e');
        }
      }

      // Google Sign-Inを実行
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        if (kDebugMode) {
          print('Google Sign-In: User cancelled or failed');
          print('Checking Google Sign-In configuration...');

          // 設定の詳細チェック
          final isSignedIn = await _googleSignIn.isSignedIn();
          print('Is signed in: $isSignedIn');
          print('Client ID configured: ${_googleSignIn.clientId ?? 'Default'}');
        }

        _setError('Google Sign-Inがキャンセルされました');
        return false;
      }

      if (kDebugMode) {
        print('Google Sign-In: Success!');
        print('  User ID: ${googleUser.id}');
        print('  Email: ${googleUser.email}');
        print('  Display Name: ${googleUser.displayName}');
      }

      // Google認証情報を取得
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (kDebugMode) {
        print('Google Auth: Getting credentials...');
        print(
            '  Access Token: ${googleAuth.accessToken != null ? 'Available' : 'Null'}');
        print(
            '  ID Token: ${googleAuth.idToken != null ? 'Available' : 'Null'}');
      }

      // Firebase認証情報を作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      if (kDebugMode) {
        print('Firebase: Signing in with credential...');
      }

      // Firebaseでサインイン
      final UserCredential result =
          await _auth.signInWithCredential(credential);

      if (kDebugMode) {
        print('Firebase Sign-In: Success!');
        print('  User ID: ${result.user?.uid}');
        print('  Email: ${result.user?.email}');
        print('  Display Name: ${result.user?.displayName}');
      }

      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Google Sign-In Error: $e');
        print('Error Type: ${e.runtimeType}');
        print('Stack Trace: $stackTrace');

        // 特定のエラーを詳しく調査
        if (e.toString().contains('PlatformException')) {
          print('');
          print('🔍 PlatformException Details:');
          print('This usually indicates a configuration issue.');
          print('Common causes:');
          print('1. Bundle ID mismatch');
          print('2. GoogleService-Info.plist not properly configured');
          print('3. OAuth Client ID not properly set up');
          print('4. App not properly signed');
          print('');
        }

        if (e.toString().contains('sign_in_canceled')) {
          print('');
          print('ℹ️  User cancelled the sign-in process');
          print('');
        }

        if (e.toString().contains('network_error')) {
          print('');
          print('🌐 Network error occurred');
          print('Check internet connection');
          print('');
        }
      }

      // ユーザーフレンドリーなエラーメッセージ
      if (e.toString().contains('sign_in_canceled')) {
        _setError('Google Sign-Inがキャンセルされました');
      } else if (e.toString().contains('network_error')) {
        _setError('ネットワークエラーが発生しました。インターネット接続を確認してください。');
      } else if (e.toString().contains('PlatformException')) {
        _setError('Google Sign-Inの設定に問題があります。アプリの設定を確認してください。');
      } else {
        _setError('Google Sign-Inに失敗しました: ${e.toString()}');
      }

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Google Sign-Inの状態をチェック
  Future<void> checkGoogleSignInStatus() async {
    if (kDebugMode) {
      print('=== Google Sign-In Status Check ===');
      print('Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
      print(
          'Google Sign-In Instance: ${_googleSignIn != null ? 'Created' : 'Not Created'}');

      try {
        final isSignedIn = await _googleSignIn.isSignedIn();
        print('Is Signed In: $isSignedIn');

        final currentUser = _googleSignIn.currentUser;
        if (currentUser != null) {
          print('Current Google User: ${currentUser.email}');
        } else {
          print('Current Google User: None');
        }
      } catch (e) {
        print('Error checking status: $e');
      }

      print('=== End Status Check ===');
    }
  }

  // Apple ID サインイン
  Future<bool> signInWithApple() async {
    try {
      _setLoading(true);
      _setError(null);

      if (kDebugMode) {
        print('Apple Sign In: Starting sign in process...');
      }

      // Apple Sign Inが利用可能かチェック
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        final errorMessage =
            'Apple IDサインインはこのデバイス/プラットフォームで利用できません。\n実機でお試しください。';
        _setError(errorMessage);
        if (kDebugMode) {
          print('Apple Sign In: Not available on this platform');
        }
        return false;
      }

      if (kDebugMode) {
        print('Apple Sign In: Platform check passed');
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (kDebugMode) {
        print('Apple Sign In: Got Apple credentials');
        print(
            'Identity Token: ${appleCredential.identityToken != null ? 'Present' : 'Missing'}');
        print(
            'Authorization Code: ${appleCredential.authorizationCode != null ? 'Present' : 'Missing'}');
      }

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      if (kDebugMode) {
        print('Apple Sign In: Created Firebase credential');
      }

      final UserCredential result = await _auth.signInWithCredential(
        oauthCredential,
      );

      _user = result.user;

      if (kDebugMode) {
        print('Apple Sign In: Successfully signed in to Firebase');
        print('User ID: ${_user?.uid}');
        print('User Email: ${_user?.email}');
      }

      return true;
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('1000')) {
        errorMessage =
            'Apple IDサインインがキャンセルされました。\nSimulatorでは動作しない場合があります。実機でお試しください。';
      } else {
        errorMessage = 'Apple IDサインインに失敗しました: ${e.toString()}';
      }
      _setError(errorMessage);
      if (kDebugMode) {
        print('Apple Sign In Error: $e');
        print('Error Type: ${e.runtimeType}');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // パスワードリセット
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _setError(null);

      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError('予期しないエラーが発生しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // サインアウト
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _setError(null);
      await _auth.signOut();
      await _googleSignIn.signOut();
      _user = null;
    } catch (e) {
      _setError('サインアウトに失敗しました');
    } finally {
      _setLoading(false);
    }
  }

  // エラーメッセージの日本語化
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'weak-password':
        return 'パスワードが弱すぎます';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'invalid-email':
        return 'メールアドレスが無効です';
      case 'user-not-found':
        return 'ユーザーが見つかりません';
      case 'wrong-password':
        return 'パスワードが間違っています';
      case 'user-disabled':
        return 'このアカウントは無効化されています';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらく待ってから再試行してください';
      case 'operation-not-allowed':
        return 'この操作は許可されていません';
      default:
        return '認証エラーが発生しました';
    }
  }
}
