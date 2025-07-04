import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });

    // テスト用: 開発時はダミー認証状態を設定
    if (kDebugMode) {
      _setDummyAuthState();
    }
  }

  // テスト用のダミー認証状態を設定
  void _setDummyAuthState() {
    // 実際のFirebase Userではなく、テスト用の状態を設定
    // 本番環境では使用しない
    Future.delayed(const Duration(milliseconds: 100), () {
      // ダミーユーザーが認証されている状態をシミュレート
      notifyListeners();
    });
  }

  // テスト用: 手動でログイン状態を設定
  void setTestAuthState(bool isLoggedIn) {
    if (kDebugMode) {
      // テスト用のみ
      notifyListeners();
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

      // Web環境での制限を回避するため、まずはサインアウトしてからサインイン
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return false; // ユーザーがキャンセルした場合
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      _user = result.user;
      return true;
    } catch (e) {
      _setError('Googleサインインに失敗しました: ${e.toString()}');
      if (kDebugMode) {
        print('Google Sign In Error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Apple ID サインイン
  Future<bool> signInWithApple() async {
    try {
      _setLoading(true);
      _setError(null);

      // Apple Sign Inが利用可能かチェック
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        _setError('Apple IDサインインはこのプラットフォームで利用できません');
        return false;
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential result = await _auth.signInWithCredential(
        oauthCredential,
      );

      _user = result.user;
      return true;
    } catch (e) {
      _setError('Apple IDサインインに失敗しました: ${e.toString()}');
      if (kDebugMode) {
        print('Apple Sign In Error: $e');
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
