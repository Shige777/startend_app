import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isAnimating = false;
  bool _showHomeScreen = false;

  // アニメーション関連
  late AnimationController _iconAnimationController;
  late Animation<double> _iconScaleAnimation;
  late Animation<Offset> _iconPositionAnimation;
  late Animation<double> _iconOpacityAnimation;

  @override
  void initState() {
    super.initState();

    // アニメーションコントローラーの初期化
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 4000), // 6秒から4秒に短縮
      vsync: this,
    );

    // 位置アニメーション（ログイン画面アイコン位置から中央へ）- UIスライドアウト完了後に降下
    _iconPositionAnimation = Tween<Offset>(
      begin: const Offset(0, -0.25), // ログイン画面のアイコン位置をより正確に設定
      end: Offset.zero, // 画面中央
    ).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: const Interval(0.1, 0.4,
            curve: Curves.easeOut), // UIスライドアウト完了後に滑らかに降下（20%-50%から短縮）
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
          curve: const Interval(0.4, 1.0))), // 降下完了後に開始（50%-100%から短縮）
    );

    // 透明度アニメーション（常に表示）
    _iconOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(_iconAnimationController);

    // アニメーションコントローラーを初期状態に設定
    _iconAnimationController.stop();
    _iconAnimationController.reset();

    // AuthProviderの通知を抑制（ログイン処理中の不要な画面遷移を防ぐ）
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.suppressNotifications(true);

    // エラーメッセージを静かにクリア
    authProvider.clearErrorSilently();
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success;

    if (_isSignUp) {
      success = await authProvider.signUpWithEmail(
        _emailController.text,
        _passwordController.text,
      );
    } else {
      success = await authProvider.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
    }

    if (success) {
      _startIconZoomAnimation();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.signInWithGoogle();

    if (success) {
      _startIconZoomAnimation();
    }
  }

  Future<void> _handleAppleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.signInWithApple();

    if (success) {
      _startIconZoomAnimation();
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('パスワードリセット用のメールアドレスを入力してください'),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.resetPassword(_emailController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('パスワードリセット用のメールを送信しました'),
        ),
      );
    }
  }

  void _startIconZoomAnimation() {
    try {
      if (mounted) {
        setState(() {
          _isAnimating = true;
        });

        // setStateの反映を待ってからアニメーション開始
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // アニメーションコントローラーを確実にリセット
            _iconAnimationController.stop();
            _iconAnimationController.reset();

            // 少し待ってからアニメーション開始
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _iconAnimationController.forward().then((_) {
                  if (mounted) {
                    _executeDirectNavigation();
                  }
                }).catchError((error) {
                  if (mounted) {
                    _executeDirectNavigation();
                  }
                });

                // 安全策: 6秒後にフォールバック実行
                Timer(const Duration(seconds: 6), () {
                  if (mounted && _isAnimating) {
                    _executeDirectNavigation();
                  }
                });
              } else {
                _executeDirectNavigation();
              }
            });
          } else {
            _executeDirectNavigation();
          }
        });
      } else {
        _executeDirectNavigation();
      }
    } catch (e) {
      _executeDirectNavigation();
    }
  }

  void _executeDirectNavigation() {
    print('Executing direct home screen display (bypassing all navigation)');

    if (!mounted) {
      print('Widget not mounted - aborting');
      return;
    }

    print('About to show home screen directly - mounted: $mounted');

    try {
      print('Setting _showHomeScreen to true for direct widget replacement');

      setState(() {
        _showHomeScreen = true;
      });

      print('Home screen flag set - widget will rebuild as HomeScreen');

      // 通知を再有効化
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.suppressNotifications(false);
      print('AuthProvider notifications re-enabled');

      // PostProviderの更新処理
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final postProvider =
              Provider.of<PostProvider>(context, listen: false);
          await postProvider.updateExpiredPosts();
          print('Expired posts updated successfully');
        } catch (e) {
          print('Error updating expired posts: $e');
        }
      });
    } catch (e) {
      print('Direct navigation failed: $e');

      // エラー時はnotificationを再有効化
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.suppressNotifications(false);
      } catch (notifError) {
        print('Failed to re-enable notifications after error: $notifError');
      }
    }
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
                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 画面の高さに応じて上部余白を追加
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.1),

                            // アプリアイコン（アニメーション中は非表示）
                            if (!_isAnimating)
                              Container(
                                alignment: Alignment.center,
                                margin: const EdgeInsets.only(bottom: 32),
                                child: Image.asset(
                                  'assets/icons/startend_icon.png',
                                  width: 80,
                                  height: 80,
                                ),
                              ),

                            // エラーメッセージの表示
                            if (authProvider.errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  authProvider.errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // メールアドレス入力
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'メールアドレス',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'メールアドレスを入力してください';
                                }
                                if (!value.contains('@')) {
                                  return '有効なメールアドレスを入力してください';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // パスワード入力
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'パスワード',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'パスワードを入力してください';
                                }
                                if (_isSignUp && value.length < 6) {
                                  return 'パスワードは6文字以上で入力してください';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // ログイン/サインアップボタン
                            ElevatedButton(
                              onPressed:
                                  authProvider.isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: authProvider.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : Text(_isSignUp ? 'アカウント作成' : 'ログイン'),
                            ),
                            const SizedBox(height: 16),

                            // Google サインイン
                            OutlinedButton.icon(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : _handleGoogleSignIn,
                              icon: const Icon(Icons.account_circle,
                                  color: Colors.black),
                              label: const Text(
                                'Googleでサインイン',
                                style: TextStyle(color: Colors.black),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Apple サインイン
                            OutlinedButton.icon(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : _handleAppleSignIn,
                              icon:
                                  const Icon(Icons.apple, color: Colors.black),
                              label: const Text(
                                'Appleでサインイン',
                                style: TextStyle(color: Colors.black),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // パスワードリセット
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
                                    style: const TextStyle(color: Colors.blue),
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
