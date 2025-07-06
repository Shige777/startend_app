import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

  AuthProvider() {
    // GoogleSignInを明示的に設定
    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        clientId:
            '201575475230-b626ctmas0d2rocgpkr1hdnbtmpmnh0r.apps.googleusercontent.com',
      );
    } else {
      // iOS/Android環境では明示的にクライアントIDを設定
      _googleSignIn = GoogleSignIn(
        clientId:
            '201575475230-lsfr1s52m5csfnb7n6f03355tvp00b1l.apps.googleusercontent.com',
      );
    }

    // デバッグ情報を出力
    if (kDebugMode) {
      print('AuthProvider initialized');
      print('Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
      print('GoogleSignIn clientId: ${_googleSignIn.clientId}');
    }

    // Firebase Auth の永続化設定（Web環境のみ）
    if (kIsWeb) {
      try {
        _auth.setPersistence(Persistence.LOCAL);
      } catch (e) {
        if (kDebugMode) {
          print('setPersistence failed: $e');
        }
      }
    }

    _auth.authStateChanges().listen((User? user) {
      if (kDebugMode) {
        print('Auth state changed: ${user?.uid ?? 'null'}');
      }
      _user = user;
      notifyListeners();
    });

    // 現在のユーザーを取得（自動ログイン）
    _user = _auth.currentUser;
    if (kDebugMode) {
      print('Current user on init: ${_user?.uid ?? 'null'}');
    }

    // テスト用: Web環境での開発時はダミーユーザーを設定
    if (kDebugMode && _user == null) {
      _setDummyUser();
    }
  }

  // テスト用のダミーユーザーを設定（Web環境での開発用）
  void _setDummyUser() {
    // ダミーユーザー情報を設定
    Future.delayed(const Duration(milliseconds: 500), () {
      // デバッグモードでのテスト用認証を有効化
      if (kDebugMode) {
        print('Debug Mode: Setting up test user authentication');
      }
      notifyListeners();
    });
  }

  // テスト用: ダミーユーザーIDを取得
  String? get testUserId => kDebugMode ? 'test_user_001' : null;

  // 実際のユーザーIDまたはテスト用ユーザーIDを取得
  String? get effectiveUserId => _user?.uid ?? testUserId;

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
        print('Google Sign In: Starting sign in process...');
      }

      // 既存のサインインをクリア
      await _googleSignIn.signOut();

      // GoogleSignInの設定を確認
      if (kDebugMode) {
        print('Google Sign In: Configuration check...');
        print('Client ID: ${_googleSignIn.clientId}');
        print('Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
        print('GoogleSignIn isSignedIn: ${await _googleSignIn.isSignedIn()}');
      }

      // iOS環境での追加チェック
      if (!kIsWeb) {
        if (kDebugMode) {
          print('Google Sign In: Checking iOS configuration...');
        }

        // iOS環境でのサインイン試行
        try {
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

          if (googleUser == null) {
            if (kDebugMode) {
              print(
                  'Google Sign In: User cancelled sign in or signIn returned null');
            }
            return false;
          }

          return await _processGoogleSignIn(googleUser);
        } catch (e) {
          if (kDebugMode) {
            print('Google Sign In iOS Error: $e');
            print('Error details: ${e.toString()}');
          }

          // iOS Simulatorの場合は特別なエラーメッセージ
          if (e.toString().contains('network_error') ||
              e.toString().contains('sign_in_canceled') ||
              e.toString().contains('sign_in_failed')) {
            _setError('iOS Simulatorでは制限があります。実機でお試しください。');
            return false;
          }

          throw e;
        }
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        if (kDebugMode) {
          print('Google Sign In: User cancelled sign in');
        }
        return false; // ユーザーがキャンセルした場合
      }

      return await _processGoogleSignIn(googleUser);
    } catch (e) {
      final errorMessage = 'Googleサインインに失敗しました: ${e.toString()}';
      _setError(errorMessage);
      if (kDebugMode) {
        print('Google Sign In Error: $e');
        print('Error Type: ${e.runtimeType}');
        if (e is FirebaseAuthException) {
          print('Firebase Auth Error Code: ${e.code}');
          print('Firebase Auth Error Message: ${e.message}');
        }
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Google Sign-Inの共通処理
  Future<bool> _processGoogleSignIn(GoogleSignInAccount googleUser) async {
    if (kDebugMode) {
      print('Google Sign In: User signed in: ${googleUser.email}');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    if (kDebugMode) {
      print('Google Sign In: Got authentication tokens');
      print(
          'Access Token: ${googleAuth.accessToken != null ? 'Present' : 'Missing'}');
      print('ID Token: ${googleAuth.idToken != null ? 'Present' : 'Missing'}');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    if (kDebugMode) {
      print('Google Sign In: Created Firebase credential');
    }

    final UserCredential result = await _auth.signInWithCredential(
      credential,
    );

    _user = result.user;

    if (kDebugMode) {
      print('Google Sign In: Successfully signed in to Firebase');
      print('User ID: ${_user?.uid}');
      print('User Email: ${_user?.email}');
    }

    return true;
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
