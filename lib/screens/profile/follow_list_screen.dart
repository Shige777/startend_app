import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/follow_service.dart';
import '../../constants/app_colors.dart';
import '../../widgets/wave_loading_widget.dart';
import '../../widgets/user_list_item.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String title;
  final FollowListType type;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.title,
    required this.type,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

enum FollowListType { followers, following }

class _FollowListScreenState extends State<FollowListScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // FollowServiceを使用してフォロー関係を取得
      Stream<List<UserModel>> userStream;
      if (widget.type == FollowListType.followers) {
        userStream = FollowService.getFollowers(widget.userId);
      } else {
        userStream = FollowService.getFollowing(widget.userId);
      }

      // Streamの最初の値を取得
      final users = await userStream.first;

      setState(() {
        _users = users;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ユーザー一覧の読み込みに失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WaveLoadingWidget(
                    size: 80,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '読み込み中...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.type == FollowListType.followers
                            ? Icons.people_outline
                            : Icons.person_add_outlined,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.type == FollowListType.followers
                            ? 'フォロワーがいません'
                            : 'フォロー中のユーザーがいません',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return UserListItem(
                      user: user,
                      onTap: () {
                        // TODO: ユーザー詳細画面に遷移
                        context.go('/profile/${user.id}');
                      },
                    );
                  },
                ),
    );
  }
}
