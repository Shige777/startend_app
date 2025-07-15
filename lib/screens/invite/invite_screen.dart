import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';

class InviteScreen extends StatefulWidget {
  final String inviteToken;

  const InviteScreen({
    super.key,
    required this.inviteToken,
  });

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  String? _communityName;

  @override
  void initState() {
    super.initState();
    _processInvite();
  }

  Future<void> _processInvite() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final communityProvider = context.read<CommunityProvider>();
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        setState(() {
          _errorMessage = 'ログインしてください';
          _isProcessing = false;
        });
        return;
      }

      final success = await communityProvider.joinCommunityByInviteUrl(
        widget.inviteToken,
        currentUser.id,
      );

      if (success && mounted) {
        // 成功時はホーム画面に遷移
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コミュニティに参加しました！')),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = communityProvider.errorMessage ?? '招待URLの処理に失敗しました';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '招待URLの処理中にエラーが発生しました';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コミュニティ招待'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  '招待URLを処理中...',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('ホームに戻る'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
