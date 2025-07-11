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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // アプリロゴ・タイトル
                const Icon(Icons.timeline, size: 80, color: AppColors.primary),
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
                const SizedBox(height: 24),

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
                    });
                  },
                  child: Text(
                    _isSignUp ? 'すでにアカウントをお持ちですか？ログイン' : 'アカウントをお持ちでない方はこちら',
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

                // ソーシャルログイン説明
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text(
                        'ソーシャルログインについて',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'このアプリは現在テスト中です。\n'
                        'startendofficial.appのGoogleアカウントでログインしてください。\n'
                        'その他のGmailアドレスでは「エラーが発生しました」と表示される場合があります。\n\n'
                        '※ 開発者がOAuth同意画面を本番環境に変更するか、\n'
                        'テストユーザーリストにあなたのGmailアドレスを追加する必要があります。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // シミュレーター制限の注意
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'シミュレーターでは制限があります。\n実機での利用をお勧めします。',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[700],
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),

                // エラーメッセージ
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (authProvider.errorMessage != null) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authProvider.errorMessage!,
                                  style:
                                      const TextStyle(color: AppColors.error),
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
              ],
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
}
