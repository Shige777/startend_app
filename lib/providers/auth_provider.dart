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
  GoogleSignIn? _googleSignIn;

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

    // 初期化が完了するまで少し待機
    Future.delayed(const Duration(milliseconds: 100), () {
      if (kDebugMode) {
        print('AuthProvider initialization complete');
      }
    });

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
    // すでに初期化済みの場合は何もしない
    if (_googleSignIn != null) {
      if (kDebugMode) {
        print('Google Sign-In already initialized, skipping...');
      }
      return;
    }
    try {
      if (kDebugMode) {
        print(
            'Initializing Google Sign-In for ${kIsWeb ? 'Web' : 'Mobile'}...');
      }

      if (kIsWeb) {
        // Web環境用の設定 - Firebase ConsoleのWeb Client IDを使用
        _googleSignIn = GoogleSignIn(
          clientId:
              '201575475230-b626ctmas0d2rocgpkr1hdnbtmpmnh0r.apps.googleusercontent.com',
        );
      } else {
        // モバイル環境用の設定 - 自動設定を使用
        _googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          forceCodeForRefreshToken: true,
        );
      }
      if (kDebugMode) {
        print(
            'Google Sign-In initialized for  [32m${kIsWeb ? 'Web' : 'Mobile'} [0m');
        print(
            'Client ID:  [32m${_googleSignIn?.clientId ?? 'Auto-configured'} [0m');
        print('Google Sign-In instance created successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In initialization error: $e');
        print('Error type: ${e.runtimeType}');
      }
      // フォールバック：基本的な設定で再試行
      try {
        if (kDebugMode) {
          print('Attempting fallback Google Sign-In initialization...');
        }
        _googleSignIn = GoogleSignIn(
          forceCodeForRefreshToken: true,
        );
        if (kDebugMode) {
          print('Google Sign-In fallback initialization successful');
        }
      } catch (fallbackError) {
        if (kDebugMode) {
          print(
              'Google Sign-In fallback initialization failed: $fallbackError');
        }
        _googleSignIn = null;
      }
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
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        if (kDebugMode) {
          print(
              'ユーザー作成/更新処理開始 (試行 ${retryCount + 1}/$maxRetries): ${user.uid}');
        }

        // ユーザーが既に存在するかチェック（タイムアウト付き）
        final docSnapshot = await userDoc.get().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
                'Firestore get timeout', const Duration(seconds: 10));
          },
        );

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

          // 新規ユーザー作成（タイムアウトとリトライ付き）
          await userDoc.set(userData.toFirestore()).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                  'Firestore set timeout', const Duration(seconds: 15));
            },
          );

          if (kDebugMode) {
            print('新規ユーザー作成成功: ${user.uid}');
          }

          // 作成後の確認（新規ユーザーでは重要）
          await Future.delayed(const Duration(milliseconds: 500));
          try {
            final verification = await userDoc.get().timeout(
                  const Duration(seconds: 5),
                );

            if (!verification.exists) {
              if (kDebugMode) {
                print('⚠️ ユーザー作成後の確認でドキュメントが見つからない - リトライ');
              }
              throw Exception('User document not found after creation');
            }
          } catch (e) {
            if (kDebugMode) {
              print('ユーザー作成の確認でエラー（継続します）: $e');
            }
            // 確認でエラーが出ても続行（作成自体は成功している可能性）
          }
        } else {
          // 既存ユーザーの場合、最終ログイン時刻を更新
          await userDoc.update({
            'updatedAt': FieldValue.serverTimestamp(),
            'isEmailVerified': user.emailVerified,
          }).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                  'Firestore update timeout', const Duration(seconds: 10));
            },
          );

          if (kDebugMode) {
            print('既存ユーザー更新成功: ${user.uid}');
          }
        }

        // 成功した場合はリターン
        return;
      } on TimeoutException catch (e) {
        retryCount++;
        if (kDebugMode) {
          print('Firestore操作タイムアウト (試行 $retryCount/$maxRetries): $e');
        }

        if (retryCount >= maxRetries) {
          if (kDebugMode) {
            print('Firestore操作の最大リトライ回数に到達 - 処理を続行');
          }
          return; // エラーを投げずに続行（認証自体は成功している）
        }

        // 段階的に待機時間を増やす
        await Future.delayed(Duration(milliseconds: 1000 * retryCount));
      } catch (e) {
        retryCount++;
        if (kDebugMode) {
          print('ユーザー作成/更新エラー (試行 $retryCount/$maxRetries): $e');
        }

        if (retryCount >= maxRetries) {
          if (kDebugMode) {
            print('ユーザー作成/更新の最大リトライ回数に到達 - 処理を続行');
            print('エラー詳細: ${e.toString()}');
          }
          return; // エラーを投げずに続行（認証自体は成功している）
        }

        // ネットワーク関連のエラーの場合は長めに待機
        if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          await Future.delayed(Duration(milliseconds: 2000 * retryCount));
        } else {
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        }
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

        // 新規ユーザーの場合、初期化完了を待機
        if (kDebugMode) {
          print('新規メールユーザーの初期化完了を待機中...');
        }
        await Future.delayed(const Duration(milliseconds: 800));
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

      if (kDebugMode) {
        print('Email Sign-In: Starting...');
        print('Email: $email');
      }

      // Android環境でのreCAPTCHA問題を回避するための設定
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('Email Sign-In: Success!');
        print('User ID: ${result.user?.uid}');
      }

      _user = result.user;
      if (_user != null) {
        await _createOrUpdateUser(_user!);

        // サインイン後の同期時間を確保
        await Future.delayed(const Duration(milliseconds: 300));
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
            'FirebaseAuthException in Email Sign-In: ${e.code} - ${e.message}');
      }

      // アカウントが存在しない場合、Google認証でのアカウントがあるかチェック
      if (e.code == 'user-not-found') {
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.contains('google.com')) {
          _setError('このメールアドレスはGoogleアカウントでサインインしてください。または、アカウントをリンクしてください。');
        } else {
          _setError('このメールアドレスのアカウントが見つかりません。');
        }
      } else if (e.code == 'invalid-credential') {
        // 認証情報が無効な場合、Googleアカウントとの重複をチェック
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.contains('google.com')) {
          _setError(
              'このメールアドレスはGoogleアカウントで使用されています。Googleでサインインするか、アカウントをリンクしてください。');
        } else {
          _setError('メールアドレスまたはパスワードが間違っています。');
        }
      } else if (e.code == 'account-exists-with-different-credential') {
        _setError('このメールアドレスは別の認証方法で使用されています。Googleでサインインするか、アカウントをリンクしてください。');
      } else {
        _setError(_getErrorMessage(e.code));
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in Email Sign-In: $e');
        print('Error type: ${e.runtimeType}');
      }
      _setError('予期しないエラーが発生しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Googleサインイン（簡素化版）
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _setError(null);

      if (kDebugMode) {
        print('Google Sign-In: Starting...');
        print(
            'Google Sign-In instance: ${_googleSignIn != null ? 'Initialized' : 'Not initialized'}');
      }

      // Google Sign-Inインスタンスが初期化されているかチェック
      if (_googleSignIn == null) {
        if (kDebugMode) {
          print('Google Sign-In not initialized, reinitializing...');
        }
        _initializeGoogleSignIn();

        // 再初期化後もnullの場合はエラー
        if (_googleSignIn == null) {
          if (kDebugMode) {
            print('Google Sign-In initialization failed completely');
          }
          _setError('Google Sign-Inの初期化に失敗しました');
          return false;
        }
      }

      if (kDebugMode) {
        print('Google Sign-In: Attempting to sign in...');
        print('Client ID: ${_googleSignIn?.clientId}');
      }

      // Web環境ではsignInSilentlyを試行
      GoogleSignInAccount? googleUser;
      if (kIsWeb) {
        try {
          googleUser = await _googleSignIn?.signInSilently();
          if (googleUser == null) {
            // signInSilentlyが失敗した場合は通常のsignInを試行
            googleUser = await _googleSignIn?.signIn();
          }
        } catch (e) {
          if (kDebugMode) {
            print(
                'Web Google Sign-In silent failed, trying regular sign in: $e');
          }
          googleUser = await _googleSignIn?.signIn();
        }
      } else {
        // モバイル環境では通常のsignIn
        googleUser = await _googleSignIn?.signIn();
      }

      if (googleUser == null) {
        if (kDebugMode) {
          print('Google Sign-In: User cancelled or failed to get account');
        }
        _setError('Google Sign-Inがキャンセルされました');
        return false;
      }

      if (kDebugMode) {
        print('Google Sign-In: Success!');
        print('  Email: ${googleUser.email}');
        print('  Display Name: ${googleUser.displayName}');
        print('  ID: ${googleUser.id}');
      }

      // Google認証情報を取得
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (kDebugMode) {
        print(
            'Google Auth: Access Token: ${googleAuth.accessToken != null ? 'Available' : 'Null'}');
        print(
            'Google Auth: ID Token: ${googleAuth.idToken != null ? 'Available' : 'Null'}');
      }

      // Firebase認証情報を作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      if (kDebugMode) {
        print('Firebase: Creating credential...');
      }

      // Firebaseでサインイン
      final UserCredential result =
          await _auth.signInWithCredential(credential);

      if (kDebugMode) {
        print('Firebase Sign-In: Success!');
        print('  User ID: ${result.user?.uid}');
        print('  Is New User: ${result.additionalUserInfo?.isNewUser}');
      }

      if (result.user != null) {
        await _createOrUpdateUser(result.user!);
      }

      return true;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('FirebaseAuthException: ${e.code} - ${e.message}');
      }
      if (e.code == 'account-exists-with-different-credential') {
        _setError(
            'このメールアドレスは既に別の認証方法で使用されています。メールアドレスでサインインするか、アカウントをリンクしてください。');
      } else if (e.code == 'email-already-in-use') {
        _setError('このメールアドレスは既に使用されています。別のメールアドレスを使用するか、既存のアカウントでサインインしてください。');
      } else if (e.code == 'invalid-credential') {
        _setError('認証情報が無効です。Googleアカウントの設定を確認してください。');
      } else {
        _setError(_getErrorMessage(e.code));
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In Error: $e');
        print('Error Type: ${e.runtimeType}');
        print('Error Details: ${e.toString()}');
        print('Error Stack Trace: ${StackTrace.current}');
      }

      String errorMessage;

      if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('canceled') ||
          e.toString().contains('cancelled')) {
        errorMessage = 'Google Sign-Inがキャンセルされました';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'ネットワークエラーが発生しました。インターネット接続を確認してください';
      } else if (e.toString().contains('popup_closed')) {
        errorMessage = 'Google Sign-Inウィンドウが閉じられました';
      } else if (e.toString().contains('popup_blocked')) {
        errorMessage = 'ポップアップがブロックされました。ブラウザの設定を確認してください';
      } else {
        errorMessage = 'Google Sign-Inに失敗しました。しばらく待ってから再試行してください';
      }

      _setError(errorMessage);
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

      if (kDebugMode) {
        print('Account Link: Starting...');
        print('Email: $email');
      }

      // まず、メール認証でサインイン
      final UserCredential emailResult = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('Account Link: Email sign-in successful');
        print('User ID: ${emailResult.user?.uid}');
      }

      // Google Sign-Inを実行
      final GoogleSignInAccount? googleUser = await _googleSignIn?.signIn();
      if (googleUser == null) {
        _setError('Google Sign-Inがキャンセルされました');
        return false;
      }

      if (kDebugMode) {
        print('Account Link: Google sign-in successful');
        print('Google Email: ${googleUser.email}');
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
        print('Account Link: Successfully linked Google account');
      }

      return true;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
            'FirebaseAuthException in Account Link: ${e.code} - ${e.message}');
      }
      if (e.code == 'provider-already-linked') {
        _setError('このGoogleアカウントは既にリンクされています');
      } else if (e.code == 'credential-already-in-use') {
        _setError('このGoogleアカウントは既に別のユーザーによって使用されています');
      } else if (e.code == 'email-already-in-use') {
        _setError('このメールアドレスは既に使用されています。別のメールアドレスを使用してください。');
      } else if (e.code == 'invalid-credential') {
        _setError('認証情報が無効です。メールアドレスとパスワードを確認してください。');
      } else {
        _setError(_getErrorMessage(e.code));
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in Account Link: $e');
        print('Error type: ${e.runtimeType}');
      }
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
          'Google Sign-In Instance: ${_googleSignIn != null ? 'Created' : 'Null'}');

      if (_googleSignIn != null) {
        try {
          final isSignedIn = await _googleSignIn!.isSignedIn();
          final currentUser = await _googleSignIn!.currentUser;
          print('Is Signed In: $isSignedIn');
          print('Current Google User: ${currentUser?.email ?? 'None'}');
        } catch (e) {
          print('Error checking Google Sign-In status: $e');
        }
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
          // 認証前に少し待機（システムの準備時間を確保）
          if (retryCount > 0) {
            await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          }

          appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

          if (kDebugMode) {
            print(
                'Apple Sign In: Successfully got credentials on attempt ${retryCount + 1}');
          }
          break; // 成功したらループを抜ける
        } catch (e) {
          retryCount++;
          if (kDebugMode) {
            print('Apple Sign In: Retry $retryCount/$maxRetries - Error: $e');
          }

          if (retryCount >= maxRetries) {
            if (kDebugMode) {
              print('Apple Sign In: Max retries reached, throwing error');
            }
            rethrow; // 最大リトライ回数に達したら例外を再スロー
          }

          // エラーの種類に応じて待機時間を調整
          if (e.toString().contains('1000') ||
              e.toString().contains('canceled')) {
            // ユーザーキャンセルの場合は即座に終了
            if (kDebugMode) {
              print('Apple Sign In: User canceled, stopping retries');
            }
            _setError('Apple IDサインインがキャンセルされました。');
            return false;
          }
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

      // ユーザー情報をFirestoreに保存/更新
      if (_user != null) {
        await _createOrUpdateUser(_user!);
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
          e.toString().contains('ASAuthorizationErrorCanceled') ||
          e.toString().contains('canceled')) {
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

      if (kDebugMode) {
        print('Password Reset: Starting...');
        print('Email: $email');
      }

      // まず、このメールアドレスでアカウントが存在するかチェック
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (kDebugMode) {
        print('Password Reset: Available methods for $email: $methods');
      }

      if (methods.isEmpty) {
        if (kDebugMode) {
          print('Password Reset: No account found for $email');
        }
        _setError('このメールアドレスのアカウントが見つかりません。');
        return false;
      }

      // Googleアカウントのみの場合は特別なメッセージ
      if (methods.length == 1 && methods.contains('google.com')) {
        if (kDebugMode) {
          print('Password Reset: Google-only account for $email');
        }
        _setError('このメールアドレスはGoogleアカウントでサインインされています。Googleでサインインしてください。');
        return false;
      }

      if (kDebugMode) {
        print('Password Reset: Sending reset email to $email');
      }

      // パスワードリセットメールを送信
      await _auth.sendPasswordResetEmail(email: email);

      if (kDebugMode) {
        print('Password Reset: Email sent successfully to $email');
      }

      return true;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
            'FirebaseAuthException in Password Reset: ${e.code} - ${e.message}');
      }

      if (e.code == 'user-not-found') {
        _setError('このメールアドレスのアカウントが見つかりません。');
      } else if (e.code == 'invalid-email') {
        _setError('有効なメールアドレスを入力してください。');
      } else if (e.code == 'too-many-requests') {
        _setError('リクエストが多すぎます。しばらく待ってから再試行してください。');
      } else if (e.code == 'network-request-failed') {
        _setError('ネットワークエラーが発生しました。インターネット接続を確認してください。');
      } else {
        _setError('パスワードリセットに失敗しました: ${e.message}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in Password Reset: $e');
        print('Error type: ${e.runtimeType}');
      }
      _setError('パスワードリセットに失敗しました。しばらく待ってから再試行してください。');
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
      await _googleSignIn?.signOut();
      _user = null;
    } catch (e) {
      _setError('サインアウトに失敗しました');
    } finally {
      _setLoading(false);
    }
  }

  // エラーメッセージの日本語化
  String _getErrorMessage(String errorCode) {
    if (kDebugMode) {
      print('Firebase Auth Error Code: $errorCode');
    }

    switch (errorCode) {
      case 'weak-password':
        return 'パスワードが弱すぎます（6文字以上で入力してください）';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'user-not-found':
        return 'このメールアドレスのアカウントが見つかりません';
      case 'wrong-password':
        return 'パスワードが間違っています';
      case 'user-disabled':
        return 'このアカウントは無効化されています';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらく待ってから再試行してください';
      case 'operation-not-allowed':
        return 'この操作は許可されていません';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました。インターネット接続を確認してください';
      case 'invalid-credential':
        return '認証情報が無効です';
      case 'account-exists-with-different-credential':
        return 'このメールアドレスは別の認証方法で使用されています';
      default:
        return '認証エラーが発生しました（エラーコード: $errorCode）';
    }
  }
}
