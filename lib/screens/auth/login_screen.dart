import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:startend_app/providers/auth_provider.dart';
import 'package:startend_app/constants/app_colors.dart';

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
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success;

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

    if (success && mounted) {
      context.go('/home');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();

    if (success && mounted) {
      context.go('/home');
    }
  }

  Future<void> _handleAppleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithApple();

    if (success && mounted) {
      context.go('/home');
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メールアドレスを入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success =
        await authProvider.resetPassword(_emailController.text.trim());

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('パスワードリセットメールを送信しました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // アプリアイコン
                    Container(
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
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          authProvider.errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
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
                        prefixIcon: Icon(Icons.email, color: Colors.black),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'メールアドレスを入力してください';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
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
                        prefixIcon: const Icon(Icons.lock, color: Colors.black),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
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
                      onPressed: authProvider.isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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
                                style: TextStyle(color: Colors.black)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: const BorderSide(color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: authProvider.isLoading
                                ? null
                                : _handleAppleSignIn,
                            icon: const Icon(Icons.apple, color: Colors.black),
                            label: const Text('Apple',
                                style: TextStyle(color: Colors.black)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: const BorderSide(color: Colors.black),
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
                          _isSignUp ? '既にアカウントをお持ちですか？' : 'アカウントをお持ちでないですか？',
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
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
