import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:startend_app/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:startend_app/screens/auth/login_screen.dart';
import 'package:startend_app/screens/home/home_screen.dart';
import 'dart:async';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _titleAnimationController;
  late AnimationController _buttonAnimationController;
  late AnimationController _circleAnimationController;
  late Animation<double> _titleAnimation;
  late Animation<double> _buttonAnimation;
  late Animation<double> _circleAnimation;

  bool _isNavigating = false; // ナビゲーション中フラグ

  @override
  void initState() {
    super.initState();

    // フラグを確実に初期化
    _isNavigating = false;
    print('WelcomeScreen initState - _isNavigating initialized to false');

    // 認証状態チェックを有効化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthenticationStatus();
    });

    _titleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _circleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _titleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeOut,
    ));

    _buttonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeOut,
    ));

    _circleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _circleAnimationController,
      curve: Curves.easeInOut,
    ));

    _titleAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _buttonAnimationController.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _circleAnimationController.forward();
      }
    });
  }

  void _checkAuthenticationStatus() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    print('WelcomeScreen: Checking authentication status');
    print('Authenticated: ${authProvider.isAuthenticated}');
    print('HasAgreedToTerms: ${authProvider.hasAgreedToTerms}');

    if (authProvider.isAuthenticated && !_isNavigating) {
      print('User already authenticated - scheduling navigation to home');
      _isNavigating = true;
      // WidgetBindingでNavigator操作を遅延実行
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToHome();
        }
      });
    }
  }

  void _navigateToHome() {
    if (_isNavigating) {
      print('WelcomeScreen: Navigation already in progress - skipping');
      return;
    }

    print('WelcomeScreen: Navigating directly to home screen');
    _isNavigating = true;

    try {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
          settings: const RouteSettings(name: '/home'),
        ),
        (route) => false,
      );
      print('WelcomeScreen: Direct navigation to home completed');
    } catch (e) {
      print('WelcomeScreen: Navigation to home failed: $e');
      _isNavigating = false; // エラー時はフラグをリセット
    }
  }

  @override
  void dispose() {
    _titleAnimationController.dispose();
    _buttonAnimationController.dispose();
    _circleAnimationController.dispose();
    super.dispose();
  }

  void _showAgreementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
          title: const Text(
            '利用規約とプライバシーポリシーに同意しますか？',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'StartEndをご利用いただくには、利用規約とプライバシーポリシーに同意していただく必要があります。',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showDisagreeMessage();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text(
                        '同意しない',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        print('Agreement button pressed - closing dialog');
                        Navigator.of(context).pop();
                        print('Dialog closed - calling _proceedToAuth');
                        _proceedToAuth();
                        print('_proceedToAuth call completed');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text(
                        '同意する',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showDisagreeMessage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
          title: const Text(
            '利用規約とプライバシーポリシーに同意しない場合、アプリをご利用いただけません。',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _proceedToAuth() {
    print('_proceedToAuth called - current _isNavigating: $_isNavigating');

    // フラグチェックを一時的に無効化してテスト
    // if (_isNavigating) {
    //   print('_proceedToAuth: navigation already in progress - skipping');
    //   return;
    // }

    print('_proceedToAuth: proceeding without flag check');
    _isNavigating = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // エラーがある場合のみクリア
    if (authProvider.errorMessage != null) {
      print('WelcomeScreen: clearing error message');
      authProvider.clearError();
    }

    // 状態設定（通知なし）
    print('Setting agreed to terms silently');
    try {
      authProvider.setAgreedToTerms(true, skipNotification: true);
      print('setAgreedToTerms completed successfully');
    } catch (e) {
      print('setAgreedToTerms failed: $e');
    }

    // ナビゲーション実行（アニメーション付き）
    print('Starting animated navigation - mounted: $mounted');
    if (mounted) {
      print('Executing animated navigation to login screen...');
      try {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionDuration: const Duration(milliseconds: 1200),
            reverseTransitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              print('Custom animation - value: ${animation.value}');

              // 下から上にスライドアップするアニメーション
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;

              var slideAnimation = animation.drive(
                Tween(begin: begin, end: end).chain(
                  CurveTween(curve: Curves.easeOutCubic),
                ),
              );

              return SlideTransition(
                position: slideAnimation,
                child: child,
              );
            },
          ),
        );
        print(
            'Navigation executed successfully - keeping _isNavigating true until next screen');
      } catch (e) {
        print('Navigation failed: $e');
        _isNavigating = false; // エラー時はフラグをリセット
      }
    }
  }

  Future<void> _showTerms() async {
    const url = 'https://startend-sns-app.web.app/terms-of-service.html';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('利用規約のページを開けませんでした'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPrivacy() async {
    const url = 'https://startend-sns-app.web.app/privacy-policy.html';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プライバシーポリシーのページを開けませんでした'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // タイトル
              AnimatedBuilder(
                animation: _titleAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - _titleAnimation.value)),
                    child: Opacity(
                      opacity: _titleAnimation.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 円形アニメーション
                          AnimatedBuilder(
                            animation: _circleAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(200, 200),
                                painter: CirclePainter(
                                  progress: _circleAnimation.value,
                                ),
                              );
                            },
                          ),
                          // タイトルテキスト
                          const Text(
                            'StartEnd',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // 説明文
              const Text(
                '「変わる」を楽しむSNSで、あなたの成長の軌跡を記録し、仲間と共有しましょう。',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // メインボタン
              AnimatedBuilder(
                animation: _buttonAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - _buttonAnimation.value)),
                    child: Opacity(
                      opacity: _buttonAnimation.value,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _showAgreementDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            side:
                                const BorderSide(color: Colors.black, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            elevation: 0,
                          ),
                          child: const Text(
                            'StartEndを始める',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // 利用規約・プライバシーポリシーリンク
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _showTerms,
                    child: const Text(
                      '利用規約',
                      style: TextStyle(
                        color: Colors.black,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text(
                    '・',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _showPrivacy,
                    child: const Text(
                      'プライバシーポリシー',
                      style: TextStyle(
                        color: Colors.black,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 円形アニメーションのカスタムペインター
class CirclePainter extends CustomPainter {
  final double progress;

  CirclePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 80.0;

    // 円の線のペイント
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // 円の描画（進行度に応じて）
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -90 * (3.14159 / 180), // 開始角度（上から）
      progress * 2 * 3.14159, // 進行度に応じた角度
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
