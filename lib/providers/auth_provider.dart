import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user_model.dart';

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
      // Android: google-services.jsonから自動取得
      // iOS: GoogleService-Info.plistから自動取得
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    }

    if (kDebugMode) {
      print('Google Sign-In initialized for ${kIsWeb ? 'Web' : 'Mobile'}');
      print('Client ID: ${_googleSignIn.clientId ?? 'Auto-configured'}');
    }
  }

  // ローディング状態を設定
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // エラーメッセージを設定
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Firebaseユーザーの作成またはアップデート
  Future<void> _createOrUpdateUser(User user) async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      // ユーザーが既に存在するかチェック
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        // 新規ユーザーの場合、Firestoreにユーザー情報を作成
        final userData = UserModel(
          id: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          profileImageUrl: user.photoURL,
          bio: '',
          followerIds: [],
          followingIds: [],
          communityIds: [],
          postCount: 0,
          isPrivate: false,
          requiresApproval: false,
          showCommunityPostsToOthers: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userDoc.set(userData.toFirestore());
        if (kDebugMode) {
          print('新規ユーザー作成: ${user.uid}');
        }
      } else {
        // 既存ユーザーの場合、最終ログイン時刻を更新
        await userDoc.update({
          'updatedAt': FieldValue.serverTimestamp(),
          'isEmailVerified': user.emailVerified,
        });
        if (kDebugMode) {
          print('既存ユーザー更新: ${user.uid}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ユーザー作成/更新エラー: $e');
      }
    }
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
      if (_user != null) {
        await _createOrUpdateUser(_user!);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      // アカウントが既に存在する場合、Google認証でのアカウントがあるかチェック
      if (e.code == 'email-already-in-use') {
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.contains('google.com')) {
          _setError(
              'このメールアドレスは既にGoogleアカウントで使用されています。Googleでサインインするか、アカウントをリンクしてください。');
        } else {
          _setError('このメールアドレスは既に使用されています。');
        }
      } else {
        _setError(_getErrorMessage(e.code));
      }
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
      if (_user != null) {
        await _createOrUpdateUser(_user!);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      // アカウントが存在しない場合、Google認証でのアカウントがあるかチェック
      if (e.code == 'user-not-found') {
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.contains('google.com')) {
          _setError('このメールアドレスはGoogleアカウントでサインインしてください。または、アカウントをリンクしてください。');
        } else {
          _setError('このメールアドレスのアカウントが見つかりません。');
        }
      } else {
        _setError(_getErrorMessage(e.code));
      }
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
    GoogleSignInAccount? googleUser;
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
      googleUser = await _googleSignIn.signIn();

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

      if (result.user != null) {
        await _createOrUpdateUser(result.user!);
      }

      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        // 同じメールアドレスで別の認証方法のアカウントが存在する場合
        final email = googleUser?.email;
        if (email != null) {
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.contains('password')) {
            _setError(
                'このメールアドレスは既にメール認証でアカウントが作成されています。メール認証でサインインするか、アカウントをリンクしてください。');
          } else {
            _setError('このメールアドレスは既に別の認証方法で使用されています。');
          }
        } else {
          _setError('アカウントが既に存在しますが、異なる認証方法で作成されています。');
        }
      } else {
        _setError(_getErrorMessage(e.code));
      }
      return false;
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

  // アカウントリンク機能 - Googleアカウントをメール認証アカウントにリンク
  Future<bool> linkGoogleAccount(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      // まず、メール認証でサインイン
      final UserCredential emailResult = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Google Sign-Inを実行
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setError('Google Sign-Inがキャンセルされました');
        return false;
      }

      // Google認証情報を取得
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 現在のユーザーにGoogleアカウントをリンク
      await emailResult.user!.linkWithCredential(credential);

      if (kDebugMode) {
        print('Google アカウントがリンクされました');
      }

      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        _setError('このGoogleアカウントは既にリンクされています');
      } else if (e.code == 'credential-already-in-use') {
        _setError('このGoogleアカウントは既に別のユーザーによって使用されています');
      } else {
        _setError(_getErrorMessage(e.code));
      }
      return false;
    } catch (e) {
      _setError('アカウントリンクに失敗しました: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // アカウントリンク機能 - メール認証をGoogleアカウントにリンク
  Future<bool> linkEmailAccount(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      // 現在のユーザーが存在するかチェック
      if (_user == null) {
        _setError('サインインしてください');
        return false;
      }

      // メール認証の認証情報を作成
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // 現在のユーザーにメール認証をリンク
      await _user!.linkWithCredential(credential);

      if (kDebugMode) {
        print('メール認証がリンクされました');
      }

      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        _setError('このメール認証は既にリンクされています');
      } else if (e.code == 'credential-already-in-use') {
        _setError('このメールアドレスは既に別のユーザーによって使用されています');
      } else if (e.code == 'email-already-in-use') {
        _setError('このメールアドレスは既に使用されています');
      } else {
        _setError(_getErrorMessage(e.code));
      }
      return false;
    } catch (e) {
      _setError('アカウントリンクに失敗しました: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 特定のメールアドレスで利用可能な認証方法を取得
  Future<List<String>> getSignInMethodsForEmail(String email) async {
    try {
      return await _auth.fetchSignInMethodsForEmail(email);
    } catch (e) {
      if (kDebugMode) {
        print('認証方法の取得エラー: $e');
      }
      return [];
    }
  }

  // 現在のユーザーの認証プロバイダーを取得
  List<String> getCurrentUserProviders() {
    if (_user == null) return [];
    return _user!.providerData.map((info) => info.providerId).toList();
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
        print('Platform: ${defaultTargetPlatform.toString()}');
      }

      // Apple Sign Inが利用可能かチェック
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        final errorMessage =
            'Apple IDサインインはこのデバイス/プラットフォームで利用できません。\niOS 13.0以降またはmacOS 10.15以降が必要です。';
        _setError(errorMessage);
        if (kDebugMode) {
          print('Apple Sign In: Not available on this platform');
        }
        return false;
      }

      if (kDebugMode) {
        print('Apple Sign In: Platform check passed');
      }

      // Apple ID認証情報を取得（リトライ機能付き）
      AuthorizationCredentialAppleID? appleCredential;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );
          break; // 成功したらループを抜ける
        } catch (e) {
          retryCount++;
          if (kDebugMode) {
            print('Apple Sign In: Retry $retryCount/$maxRetries - Error: $e');
          }

          if (retryCount >= maxRetries) {
            rethrow; // 最大リトライ回数に達したら例外を再スロー
          }

          // 短い待機時間を入れる
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }

      if (appleCredential == null) {
        _setError('Apple IDサインインに失敗しました。もう一度お試しください。');
        return false;
      }

      if (kDebugMode) {
        print('Apple Sign In: Got Apple credentials');
        print('User ID: ${appleCredential.userIdentifier}');
        print('Email: ${appleCredential.email ?? 'Not provided'}');
        print(
            'Full Name: ${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}');
        print(
            'Identity Token: ${appleCredential.identityToken != null ? 'Present' : 'Missing'}');
        print(
            'Authorization Code: ${appleCredential.authorizationCode != null ? 'Present' : 'Missing'}');
      }

      // Firebase認証情報を作成
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      if (kDebugMode) {
        print('Apple Sign In: Created Firebase credential');
      }

      // Firebaseでサインイン
      final UserCredential result = await _auth.signInWithCredential(
        oauthCredential,
      );

      _user = result.user;

      if (kDebugMode) {
        print('Apple Sign In: Successfully signed in to Firebase');
        print('User ID: ${_user?.uid}');
        print('User Email: ${_user?.email}');
      }

      // 初回サインインの場合、ユーザー情報を更新
      if (result.additionalUserInfo?.isNewUser == true) {
        String displayName = '';
        if (appleCredential.givenName != null ||
            appleCredential.familyName != null) {
          displayName =
              '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                  .trim();
        }

        if (displayName.isNotEmpty) {
          await _user?.updateDisplayName(displayName);
        }

        if (kDebugMode) {
          print('Apple Sign In: Updated user display name: $displayName');
        }
      }

      return true;
    } catch (e) {
      String errorMessage;

      // 具体的なエラーコードに基づいてメッセージを設定
      if (e.toString().contains('1000') ||
          e.toString().contains('ASAuthorizationErrorCanceled')) {
        errorMessage = 'Apple IDサインインがキャンセルされました。';
      } else if (e.toString().contains('1001') ||
          e.toString().contains('ASAuthorizationErrorFailed')) {
        errorMessage = 'Apple IDサインインに失敗しました。ネットワーク接続を確認してください。';
      } else if (e.toString().contains('1002') ||
          e.toString().contains('ASAuthorizationErrorInvalidResponse')) {
        errorMessage = 'Apple IDサインインで無効な応答を受信しました。もう一度お試しください。';
      } else if (e.toString().contains('1003') ||
          e.toString().contains('ASAuthorizationErrorNotHandled')) {
        errorMessage = 'Apple IDサインインがサポートされていません。';
      } else if (e.toString().contains('1004') ||
          e.toString().contains('ASAuthorizationErrorNotInteractive')) {
        errorMessage = 'Apple IDサインインが利用できません。設定を確認してください。';
      } else if (e.toString().contains('network')) {
        errorMessage = 'ネットワークエラーが発生しました。インターネット接続を確認してください。';
      } else if (e.toString().contains('FirebaseAuthException')) {
        errorMessage = 'Firebase認証エラーが発生しました。しばらく待ってから再試行してください。';
      } else {
        errorMessage =
            'Apple IDサインインに失敗しました。\n実機でお試しください。\n\nエラー詳細: ${e.toString()}';
      }

      _setError(errorMessage);
      if (kDebugMode) {
        print('Apple Sign In Error: $e');
        print('Error Type: ${e.runtimeType}');
        print('Error Details: ${e.toString()}');
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
