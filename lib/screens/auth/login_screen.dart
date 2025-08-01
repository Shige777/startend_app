import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _showLinkOptions = false;
  List<String> _availableMethods = [];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailableSignInMethods() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final methods = await authProvider
        .getSignInMethodsForEmail(_emailController.text.trim());

    setState(() {
      _availableMethods = methods;
      _showLinkOptions = methods.isNotEmpty && !methods.contains('password');
    });
  }

  Future<void> _linkGoogleAccount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.linkGoogleAccount(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Googleアカウントがリンクされました'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.largePadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  // アプリロゴ・タイトル
                  const Icon(Icons.timeline,
                      size: 80, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'START/END投稿を軸とした進捗共有SNS',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),

                  // メールアドレス入力
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'メールアドレスを入力してください';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return '有効なメールアドレスを入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // パスワード入力
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
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

                  // パスワードを忘れた場合のリンク
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showPasswordResetDialog(context),
                        child: const Text(
                          'パスワードを忘れた場合',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // エラーメッセージ
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      if (authProvider.errorMessage != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.black.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.black, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authProvider.errorMessage!,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // アカウントリンクオプション
                  if (_showLinkOptions)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'アカウントリンクオプション',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'このメールアドレスは他の認証方法で使用されています。',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_availableMethods.contains('google.com'))
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: Consumer<AuthProvider>(
                                    builder: (context, authProvider, child) {
                                      return ElevatedButton.icon(
                                        onPressed: authProvider.isLoading
                                            ? null
                                            : _linkGoogleAccount,
                                        icon: const Icon(Icons.link),
                                        label: const Text('Googleアカウントとリンク'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'または、Googleでログインしてください',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                  // ログイン/サインアップボタン
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return ElevatedButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => _handleSubmit(context, authProvider),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.textOnPrimary,
                                  ),
                                ),
                              )
                            : Text(_isSignUp ? 'アカウント作成' : 'ログイン'),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ログイン/サインアップ切り替え
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _showLinkOptions = false;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'すでにアカウントをお持ちですか？ログイン' : 'アカウントをお持ちでない方はこちら',
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 区切り線
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('または'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Googleサインイン
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return OutlinedButton.icon(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => _handleGoogleSignIn(context, authProvider),
                        icon: const Icon(Icons.g_mobiledata, size: 24),
                        label: const Text('Googleでログイン・アカウント作成'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.black,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Apple ID サインイン
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return OutlinedButton.icon(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => _handleAppleSignIn(context, authProvider),
                        icon: const Icon(Icons.apple, size: 24),
                        label: const Text('Apple IDでログイン・アカウント作成'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.black,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    bool success;
    if (_isSignUp) {
      success = await authProvider.signUpWithEmail(email, password);
    } else {
      success = await authProvider.signInWithEmail(email, password);
    }

    if (success && mounted) {
      // 通知サービスを初期化
      await NotificationService().initialize();
      context.go('/home');
    } else {
      // エラーが発生した場合、利用可能な認証方法をチェック
      await _checkAvailableSignInMethods();
    }
  }

  Future<void> _handleGoogleSignIn(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    // まず状態をチェック
    await authProvider.checkGoogleSignInStatus();

    final success = await authProvider.signInWithGoogle();
    if (success && mounted) {
      // 通知サービスを初期化
      await NotificationService().initialize();
      context.go('/home');
    } else {
      // エラーが発生した場合、利用可能な認証方法をチェック
      await _checkAvailableSignInMethods();
    }
  }

  Future<void> _handleAppleSignIn(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final success = await authProvider.signInWithApple();
    if (success && mounted) {
      // 通知サービスを初期化
      await NotificationService().initialize();
      context.go('/home');
    }
  }

  // パスワードリセットダイアログを表示
  Future<void> _showPasswordResetDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    List<String> availableMethods = [];

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('パスワードリセット'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '登録済みのメールアドレスを入力してください。\nパスワードリセット用のリンクを送信します。',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'メールアドレスを入力してください';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value)) {
                          return '有効なメールアドレスを入力してください';
                        }
                        return null;
                      },
                      onChanged: (value) async {
                        if (value.isNotEmpty && value.contains('@')) {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final methods = await authProvider
                              .getSignInMethodsForEmail(value.trim());
                          setState(() {
                            availableMethods = methods;
                          });
                        }
                      },
                    ),
                    if (availableMethods.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'このメールアドレスの認証方法:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...availableMethods.map((method) {
                              String methodText = '';
                              if (method == 'google.com') {
                                methodText = 'Googleアカウント';
                              } else if (method == 'password') {
                                methodText = 'メールアドレス・パスワード';
                              }
                              return Text(
                                '• $methodText',
                                style: const TextStyle(fontSize: 12),
                              );
                            }),
                            if (availableMethods.contains('google.com') &&
                                !availableMethods.contains('password'))
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  '⚠️ Googleアカウントの場合は、Googleでログインしてください。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setState(() {
                            isLoading = true;
                          });

                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );

                          final success = await authProvider.resetPassword(
                            emailController.text.trim(),
                          );

                          setState(() {
                            isLoading = false;
                          });

                          if (success) {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'パスワードリセット用のメールを送信しました。\nメールをご確認ください。',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('送信'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
