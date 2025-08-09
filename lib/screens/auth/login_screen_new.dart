import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:startend_app/providers/auth_provider.dart';

import 'package:startend_app/constants/app_colors.dart';
import 'package:startend_app/screens/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _showHomeScreen = false; // ホーム画面表示フラグ
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isPasswordVisible = false;

  // アニメーション用のコントローラー
  late AnimationController _iconAnimationController;
  late Animation<double> _iconScaleAnimation;
  late Animation<Offset> _iconPositionAnimation;
  late Animation<double> _iconOpacityAnimation;
  late Animation<double> _uiFadeAnimation; // UI要素のフェードアニメーション
  bool _isAnimating = false;

  // アプリ画像の位置を計算するためのキー
  final GlobalKey _iconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    print('LoginScreen: initState called');

    // アニメーションコントローラーの初期化
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // 3秒から2秒に短縮
      vsync: this,
    );

    // UI要素のフェードアニメーション（最初にフェードアウト）
    _uiFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: const Interval(0.0, 0.2,
            curve: Curves.easeOut), // 最初の20%でフェードアウト（30%から短縮）
      ),
    );

    // 位置アニメーションは後で動的に設定
    _iconPositionAnimation = Tween<Offset>(
      begin: const Offset(0, -0.25), // デフォルト値
      end: Offset.zero, // 画面中央
    ).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: const Interval(0.2, 0.6,
            curve: Curves.easeOut), // 20%から60%で降下（30%-80%から短縮）
      ),
    );

    // スケールアニメーション（収縮→拡大）- 降下完了後に開始
    _iconScaleAnimation = _iconAnimationController.drive(
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.7), // 収縮フェーズ
          weight: 20, // 全体の20% (30%から短縮)
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.7, end: 200.0), // 爆発的拡大フェーズ
          weight: 80, // 全体の80% (70%から増加)
        ),
      ]).chain(CurveTween(
          curve: const Interval(0.6, 1.0))), // 降下完了後に開始（80%-100%から短縮）
    );

    // 透明度アニメーション
    _iconOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(_iconAnimationController);

    // エラーメッセージをクリア
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.errorMessage != null) {
        print('LoginScreen: clearing error message silently');
        authProvider.clearErrorSilently();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success = false;
    if (_isSignUp) {
      success = await authProvider.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await authProvider.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    // ログイン成功時は即座にアニメーション開始
    if (success) {
      print('Email/Password login successful - starting immediate animation');
      _startIconZoomAnimation();
    } else {
      print('Email/Password login failed: success=$success');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ログイン処理中はnotifyListenersを抑制
    authProvider.suppressNotifications(true);

    final success = await authProvider.signInWithGoogle();

    // ログイン成功時は即座にアニメーション開始（遅延なし）
    if (success) {
      print('Google login successful - starting immediate animation');
      _startIconZoomAnimation();
    } else {
      print('Google login failed: success=$success');
      // 失敗時はnotificationを再有効化
      authProvider.suppressNotifications(false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ログイン処理中はnotifyListenersを抑制
    authProvider.suppressNotifications(true);

    final success = await authProvider.signInWithApple();

    // ログイン成功時は即座にアニメーション開始（遅延なし）
    if (success) {
      print('Apple login successful - starting immediate animation');
      _startIconZoomAnimation();
    } else {
      print('Apple login failed: success=$success');
      // 失敗時はnotificationを再有効化
      authProvider.suppressNotifications(false);
    }
  }

  // アニメーション開始時に正確な位置を計算
  void _calculateIconPosition() {
    if (_iconKey.currentContext != null) {
      final RenderBox renderBox =
          _iconKey.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final screenHeight = MediaQuery.of(context).size.height;

      // アプリ画像の中心位置を計算
      final iconCenterY = position.dy + renderBox.size.height / 2;
      final normalizedY = (iconCenterY - screenHeight / 2) / (screenHeight / 2);

      // 位置アニメーションを動的に更新
      _iconPositionAnimation = Tween<Offset>(
        begin: Offset(0, normalizedY),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _iconAnimationController,
          curve: const Interval(0.2, 0.6, curve: Curves.easeOut), // 20%から60%で降下
        ),
      );
    }
  }

  void _startIconZoomAnimation() {
    setState(() {
      _isAnimating = true;
    });

    // 正確な位置を計算
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateIconPosition();

      // アニメーション開始
      _iconAnimationController.forward().then((_) {
        // アニメーション完了後の処理
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.suppressNotifications(false);

        setState(() {
          _showHomeScreen = true;
        });
      });
    });
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアドレスを入力してください')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.resetPassword(email);
  }

  @override
  Widget build(BuildContext context) {
    // ホーム画面フラグがtrueの場合、HomeScreenを表示
    if (_showHomeScreen) {
      return const HomeScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return AnimatedBuilder(
                    animation: _iconAnimationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _uiFadeAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 画面の高さに応じて上部余白を追加
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.1),
                              // アプリアイコン
                              Container(
                                key: _iconKey, // キーを追加
                                alignment: Alignment.center,
                                margin: const EdgeInsets.only(bottom: 32),
                                child: Image.asset(
                                  'assets/icons/startend_icon.png',
                                  width: 80,
                                  height: 80,
                                ),
                              ),

                              // エラーメッセージ表示
                              if (authProvider.errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    authProvider.errorMessage!,
                                    style:
                                        TextStyle(color: Colors.red.shade700),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                              // メールアドレス入力
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.black),
                                decoration: const InputDecoration(
                                  labelText: 'メールアドレス',
                                  border: OutlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.email, color: Colors.black),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'メールアドレスを入力してください';
                                  }
                                  if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return '正しいメールアドレスを入力してください';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // パスワード入力
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                style: const TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  labelText: 'パスワード',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock,
                                      color: Colors.black),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'パスワードを入力してください';
                                  }
                                  if (value.length < 6) {
                                    return 'パスワードは6文字以上で入力してください';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // メインアクションボタン
                              ElevatedButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(_isSignUp ? 'アカウント作成' : 'ログイン'),
                              ),
                              const SizedBox(height: 16),

                              // ソーシャルログインボタン
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : _handleGoogleSignIn,
                                      icon: const Icon(Icons.g_mobiledata,
                                          color: Colors.black),
                                      label: const Text('Google',
                                          style:
                                              TextStyle(color: Colors.black)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        side: const BorderSide(
                                            color: Colors.black),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : _handleAppleSignIn,
                                      icon: const Icon(Icons.apple,
                                          color: Colors.black),
                                      label: const Text('Apple',
                                          style:
                                              TextStyle(color: Colors.black)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        side: const BorderSide(
                                            color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // パスワードリセットリンク
                              TextButton(
                                onPressed: _handlePasswordReset,
                                child: const Text(
                                  'パスワードを忘れた場合',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),

                              // モード切り替え
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isSignUp
                                        ? '既にアカウントをお持ちですか？'
                                        : 'アカウントをお持ちでないですか？',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isSignUp = !_isSignUp;
                                      });
                                    },
                                    child: Text(
                                      _isSignUp ? 'ログイン' : 'アカウント作成',
                                      style:
                                          const TextStyle(color: Colors.blue),
                                    ),
                                  ),
                                ],
                              ),
                              // 画面の高さに応じて下部余白を追加
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.1),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          // アニメーション中のアイコンオーバーレイ
          if (_isAnimating)
            AnimatedBuilder(
              animation: _iconAnimationController,
              builder: (context, child) {
                return Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: SlideTransition(
                      position: _iconPositionAnimation,
                      child: FadeTransition(
                        opacity: _iconOpacityAnimation,
                        child: Transform.scale(
                          scale: _iconScaleAnimation.value,
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/icons/startend_icon.png',
                                width: 80,
                                height: 80,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
