import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../constants/app_colors.dart';
import 'post_card_widget.dart';
import 'user_list_item.dart';

enum PostListType { following, community, user }

class PostListWidget extends StatefulWidget {
  final PostListType type;
  final List<PostModel>? posts;
  final String? searchQuery;
  final Function(PostModel)? onPostTap;
  final String? userId; // 特定のユーザーの投稿を表示する場合に使用

  const PostListWidget({
    super.key,
    required this.type,
    this.posts,
    this.searchQuery,
    this.onPostTap,
    this.userId,
  });

  @override
  State<PostListWidget> createState() => _PostListWidgetState();
}

class _PostListWidgetState extends State<PostListWidget> {
  @override
  void initState() {
    super.initState();
    // ビルド完了後に非同期処理を実行
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // 既に投稿が渡されている場合は読み込みをスキップ
      if (widget.posts == null) {
        _loadPosts();
      }
    });
  }

  void _loadPosts() async {
    final postProvider = context.read<PostProvider>();

    switch (widget.type) {
      case PostListType.following:
        // フォロー中の投稿を取得
        final userProvider = context.read<UserProvider>();
        final currentUser = userProvider.currentUser;
        if (currentUser != null) {
          await postProvider.getFollowingPosts(currentUser.followingIds);
        }
        break;
      case PostListType.community:
        // コミュニティの投稿を取得
        final userProvider = context.read<UserProvider>();
        final currentUser = userProvider.currentUser;
        if (currentUser != null) {
          await postProvider
              .getMultipleCommunityPosts(currentUser.communityIds);
        }
        break;
      case PostListType.user:
        // ユーザーの投稿を取得
        final targetUserId = widget.userId;
        if (targetUserId != null) {
          await postProvider.getUserPosts(targetUserId);
        } else {
          // userIdが指定されていない場合は現在のユーザーの投稿を取得
          final userProvider = context.read<UserProvider>();
          final currentUser = userProvider.currentUser;
          if (currentUser != null) {
            await postProvider.getUserPosts(currentUser.id);
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PostProvider, UserProvider>(
      builder: (context, postProvider, userProvider, child) {
        List<PostModel> posts;

        if (widget.posts != null) {
          posts = widget.posts!;
        } else {
          switch (widget.type) {
            case PostListType.following:
              posts = postProvider.followingPosts;
              break;
            case PostListType.community:
              posts = postProvider.communityPosts;
              break;
            case PostListType.user:
              posts = postProvider.userPosts;
              break;
          }
        }

        // 検索フィルタリング
        if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
          posts = posts.where((post) {
            final query = widget.searchQuery!.toLowerCase();
            return post.title.toLowerCase().contains(query) ||
                (post.comment?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        // 検索結果のユーザー（フォロー中タブの場合のみ）
        List<UserModel> searchUsers = [];
        if (widget.type == PostListType.following &&
            widget.searchQuery != null &&
            widget.searchQuery!.isNotEmpty) {
          searchUsers = userProvider.searchResults;
        }

        if (postProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (posts.isEmpty && searchUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getEmptyIcon(), size: 64, color: AppColors.textHint),
                const SizedBox(height: 16),
                Text(
                  _getEmptyMessage(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: searchUsers.length + posts.length,
            itemBuilder: (context, index) {
              // ユーザー結果を先に表示
              if (index < searchUsers.length) {
                return UserListItem(
                  user: searchUsers[index],
                  onTap: () {
                    context.go('/profile/${searchUsers[index].id}');
                  },
                );
              }

              // 投稿を表示
              final postIndex = index - searchUsers.length;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: PostCardWidget(
                  post: posts[postIndex],
                  onTap: widget.onPostTap != null
                      ? () => widget.onPostTap!(posts[postIndex])
                      : null,
                  onDelete: _canDeletePost(posts[postIndex])
                      ? () => _showDeleteConfirmation(posts[postIndex])
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    _loadPosts();
  }

  IconData _getEmptyIcon() {
    switch (widget.type) {
      case PostListType.following:
        return Icons.people_outline;
      case PostListType.community:
        return Icons.group_outlined;
      case PostListType.user:
        return Icons.person_outline;
    }
  }

  String _getEmptyMessage() {
    switch (widget.type) {
      case PostListType.following:
        return 'フォロー中の投稿はありません';
      case PostListType.community:
        return 'コミュニティの投稿はありません';
      case PostListType.user:
        return '投稿はありません';
    }
  }

  // 投稿削除権限があるかチェック
  bool _canDeletePost(PostModel post) {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    return currentUser != null && post.userId == currentUser.id;
  }

  // 削除確認ダイアログを表示
  void _showDeleteConfirmation(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿削除'),
        content: const Text('この投稿を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePost(post);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // 投稿削除処理
  Future<void> _deletePost(PostModel post) async {
    final postProvider = context.read<PostProvider>();

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await postProvider.deletePost(post.id);

      if (mounted) {
        Navigator.of(context).pop(); // ローディング終了

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿を削除しました')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿の削除に失敗しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // ローディング終了
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }
}
