import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // GoogleSignIn 7.1.1の新しいAPI: .instanceでシングルトンインスタンスを取得
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _suppressNotifications = false; // notifyListeners制御フラグ
  bool _isAuthenticating = false;
  bool _hasAgreedToTerms = false;

  // ▼▼▼ ゲッタープロパティを追加 ▼▼▼
  bool get isAuthenticated => _user != null; // 認証状態を返す

  @override
  void notifyListeners() {
    if (!_suppressNotifications) {
      super.notifyListeners();
    } else {
      print('AuthProvider: notifyListeners suppressed');
    }
  }

  void suppressNotifications(bool suppress) {
    _suppressNotifications = suppress;
    print('AuthProvider: notifications ${suppress ? 'suppressed' : 'enabled'}');
  }

  String? get currentUserId => _user?.uid; // ログイン中のユーザーIDを返す
  User? get user => _user; // ログイン中のUserオブジェクトを返す
  User? get currentUser => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _user != null;
  bool get isAuthenticating => _isAuthenticating;
  bool get hasAgreedToTerms => _hasAgreedToTerms;
  // ▲▲▲ ここまで ▲▲▲

  AuthProvider() {
    // 初期状態を確実に復元
    _initializeAuthState();

    // 認証状態の変更を監視
    _auth.authStateChanges().listen((User? user) {
      print('AuthProvider: authStateChanges - user: ${user?.uid ?? 'null'}');
      _user = user;
      notifyListeners();
    });

    // GoogleSignInの初期化を開始
    _initializeGoogleSignIn();
  }

  // 初期認証状態の復元
  Future<void> _initializeAuthState() async {
    try {
      // 現在のユーザーを取得
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('AuthProvider: Found existing user: ${currentUser.uid}');
        _user = currentUser;
        notifyListeners();
      } else {
        print('AuthProvider: No existing user found');
      }
    } catch (e) {
      print('AuthProvider: Error initializing auth state: $e');
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearErrorSilently() {
    _errorMessage = null;
    // 通知なしでエラーをクリア
  }

  void setAgreedToTerms(bool agreed,
      {bool delayNotification = false, bool skipNotification = false}) {
    print(
        'AuthProvider: setAgreedToTerms called with: $agreed, delayNotification: $delayNotification, skipNotification: $skipNotification');
    _hasAgreedToTerms = agreed;
    print('AuthProvider: _hasAgreedToTerms is now: $_hasAgreedToTerms');

    if (skipNotification) {
      print('AuthProvider: skipping notifyListeners');
      return;
    }

    if (delayNotification) {
      print('AuthProvider: delaying notifyListeners');
      // 次のフレームまで通知を遅延
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
        print('AuthProvider: delayed notifyListeners called');
      });
    } else {
      notifyListeners();
      print('AuthProvider: immediate notifyListeners called');
    }
  }

  // GoogleSignIn 7.1.1の新しい初期化処理
  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
      _isGoogleSignInInitialized = true;
    } catch (e) {
      // エラーハンドリング
    }
  }

  // GoogleSignInの各機能を使う前に、必ず初期化が終わっているか確認する
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _initializeGoogleSignIn();
      if (!_isGoogleSignInInitialized) {
        throw Exception("Google Sign-In could not be initialized.");
      }
    }
  }

  // メールサインアップ
  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = result.user;

      if (_user != null) {
        await _createOrUpdateUser(_user!);
        _setLoading(false);
        // 認証成功時のみ状態更新を通知
        notifyListeners();
        return true;
      } else {
        _setError('アカウント作成に失敗しました');
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError(_getErrorMessage(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // メールサインイン
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
        _setLoading(false);
        // 認証成功時のみ状態更新を通知
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(_getErrorMessage(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Googleサインイン（7.1.1 API対応）
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _setError(null);
      _isAuthenticating = true;
      // 認証処理開始を通知（リダイレクト防止のため）
      notifyListeners();
      print(
          'AuthProvider: Google sign-in started - authenticating=true, loading=true');

      // 認証処理中の状態を確実に設定（複数回通知）
      notifyListeners();
      print('AuthProvider: Authentication state immediately re-notified');

      // 認証処理中であることを確実に通知
      notifyListeners();
      print('AuthProvider: Authentication state triple-notified for safety');

      // 1. まず初期化が完了していることを確認する
      await _ensureGoogleSignInInitialized();

      // 2. authenticate()を呼び出して認証フローを開始する
      // Google Play Services エラーに対する例外処理を追加
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.authenticate();
      } catch (e) {
        if (kDebugMode) {
          print('Google Play Services error (possibly emulator): $e');
        }
        if (e.toString().contains('Unknown calling package name')) {
          _setError('エミュレータでのGoogle認証はサポートされていません。実機でお試しください。');
        } else {
          _setError('Google認証でエラーが発生しました: $e');
        }
        return false;
      }

      // 3. 認証情報を取得
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken, // accessTokenは使わない
      );

      // 4. Firebaseにサインイン
      final UserCredential result =
          await _auth.signInWithCredential(credential);
      _user = result.user;

      if (_user != null) {
        await _createOrUpdateUser(_user!);
        _setLoading(false);
        _isAuthenticating = false;
        // 認証成功時のみ状態更新を通知
        notifyListeners();
        print(
            'AuthProvider: Google sign-in completed successfully - authenticating=false, loading=false');
        return true;
      } else {
        _setError('Googleサインインに失敗しました');
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
      _isAuthenticating = false;
      print(
          'AuthProvider: Google sign-in finished - authenticating=false, loading=false');
    }
  }

  Future<bool> linkGoogleAccount() async {
    try {
      _setLoading(true);
      _setError(null);

      await _ensureGoogleSignInInitialized();

      final GoogleSignInAccount? googleUser =
          await _googleSignIn.authenticate();
      if (googleUser == null) {
        _setError('Googleサインインがキャンセルされました');
        return false;
      }

      final auth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );

      final userCredential =
          await _auth.currentUser!.linkWithCredential(credential);
      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
        return true;
      }
      return false;
    } catch (e) {
      _setError(_getErrorMessage(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithApple() async {
    try {
      _setLoading(true);
      _setError(null);
      _isAuthenticating = true;
      // 認証処理開始を通知（リダイレクト防止のため）
      notifyListeners();
      print(
          'AuthProvider: Apple sign-in started - authenticating=true, loading=true');

      // 認証処理中の状態を確実に設定（複数回通知）
      notifyListeners();
      print('AuthProvider: Apple authentication state immediately re-notified');

      // 認証処理中であることを確実に通知
      notifyListeners();
      print(
          'AuthProvider: Apple authentication state triple-notified for safety');

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
        _setLoading(false);
        _isAuthenticating = false;
        // 認証成功時のみ状態更新を通知
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(_getErrorMessage(e.toString()));
      return false;
    } finally {
      _setLoading(false);
      _isAuthenticating = false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _setError(null);

      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      _setError(_getErrorMessage(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // サインアウト
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _user = null;
      _setError(null);
    } catch (e) {
      // エラーハンドリング
    }
  }

  // アカウント削除
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _setError(null);

      final user = _auth.currentUser;
      if (user == null) {
        _setError('ユーザーが見つかりません');
        return false;
      }

      // Firebase認証からアカウントを削除
      await user.delete();

      // Google Sign-Inからもサインアウト
      await _googleSignIn.signOut();

      _user = null;
      _setError(null);

      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError(_getErrorMessage(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ユーザー情報の作成・更新
  Future<void> _createOrUpdateUser(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);

      // 既存のユーザー情報を取得
      final existingDoc = await userDoc.get();

      if (existingDoc.exists) {
        // 既存ユーザーの場合、名前とプロフィール画像は更新しない
        final userData = {
          'email': user.email,
          'lastSignInAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await userDoc.update(userData);
      } else {
        // 新規ユーザーの場合、すべての情報を設定
        final userData = {
          'email': user.email,
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'lastSignInAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await userDoc.set(userData);
      }
    } catch (e) {
      // エラーハンドリング
    }
  }

  // エラーメッセージの取得
  String _getErrorMessage(dynamic error) {
    if (error is String) {
      switch (error) {
        case 'user-not-found':
          return 'ユーザーが見つかりません';
        case 'wrong-password':
          return 'パスワードが間違っています';
        case 'email-already-in-use':
          return 'このメールアドレスは既に使用されています';
        case 'weak-password':
          return 'パスワードが弱すぎます';
        case 'invalid-email':
          return '無効なメールアドレスです';
        case 'user-disabled':
          return 'このアカウントは無効化されています';
        case 'too-many-requests':
          return '試行回数が多すぎます。しばらく待ってから再試行してください';
        case 'operation-not-allowed':
          return 'この操作は許可されていません';
        case 'account-exists-with-different-credential':
          return 'このメールアドレスは別の認証方法で登録されています';
        default:
          return '認証に失敗しました: $error';
      }
    }
    return '認証に失敗しました';
  }

  // ランダムなnonceを生成
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  // SHA256ハッシュを生成
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
