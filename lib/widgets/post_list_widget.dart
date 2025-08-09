import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../constants/app_colors.dart';
import 'post_card_widget.dart';
import 'user_list_item.dart';
import 'native_ad_widget.dart';
import '../services/ad_service.dart';

import 'leaf_loading_widget.dart';

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
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // 初期化は didChangeDependencies で行う
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ビルド完了後に非同期処理を実行
    if (widget.posts == null && !_hasInitialized) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasInitialized) {
          _initializePosts();
        }
      });
    }
  }

  void _initializePosts() async {
    if (_hasInitialized) return;

    // UserProvider の初期化を待つ
    final userProvider = context.read<UserProvider>();

    // ユーザー情報がまだ読み込まれていない場合
    if (userProvider.currentUser == null) {
      if (userProvider.isLoading) {
        // 読み込み中の場合は少し待ってから再試行
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted && !_hasInitialized) {
          _initializePosts();
        }
        return;
      } else {
        // 読み込み中でない場合は、手動でリフレッシュを実行
        try {
          await userProvider.refreshCurrentUser();
          if (userProvider.currentUser == null) {
            print('PostListWidget: Failed to get current user after refresh');
            return;
          }
        } catch (e) {
          print('PostListWidget: Error refreshing current user: $e');
          return;
        }
      }
    }

    _loadPosts();
  }

  void _loadPosts() async {
    if (_hasInitialized) return; // 既に初期化済みの場合はスキップ
    _hasInitialized = true;

    // contextが利用可能かチェック
    if (!mounted) return;

    print('PostListWidget: Starting _loadPosts');
    final postProvider = context.read<PostProvider>();

    switch (widget.type) {
      case PostListType.following:
        // フォロー中の投稿を取得（自分の投稿も含める）
        try {
          final userProvider = context.read<UserProvider>();
          final currentUser = userProvider.currentUser;
          if (currentUser != null) {
            // フォロー中のユーザーIDに自分のIDも追加
            final followingIdsWithSelf = [
              ...currentUser.followingIds,
              currentUser.id
            ];
            await postProvider.getFollowingPosts(followingIdsWithSelf,
                currentUserId: currentUser.id);
          } else {
            print(
                'PostListWidget: currentUser is null, skipping following posts load');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error loading following posts: $e');
          }
        }
        break;
      case PostListType.community:
        // コミュニティの投稿を取得
        try {
          final userProvider = context.read<UserProvider>();
          final currentUser = userProvider.currentUser;
          if (currentUser != null) {
            await postProvider
                .getMultipleCommunityPosts(currentUser.communityIds);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error loading community posts: $e');
          }
        }
        break;
      case PostListType.user:
        // ユーザーの投稿を取得
        try {
          final userProvider = context.read<UserProvider>();
          final currentUser = userProvider.currentUser;
          final targetUserId = widget.userId;
          if (targetUserId != null) {
            await postProvider.getUserPosts(targetUserId,
                currentUserId: currentUser?.id);
          } else {
            // userIdが指定されていない場合は現在のユーザーの投稿を取得
            if (currentUser != null) {
              await postProvider.getUserPosts(currentUser.id,
                  currentUserId: currentUser.id);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error loading user posts: $e');
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PostProvider, UserProvider>(
      builder: (context, postProvider, userProvider, child) {
        // ユーザー情報がまだ読み込まれていない場合
        if (userProvider.currentUser == null && userProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LeafLoadingWidget(
                  size: 50,
                  color: AppColors.primary,
                ),
                SizedBox(height: 16),
                Text(
                  'ユーザー情報を読み込み中...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        // ユーザー情報の読み込みに失敗した場合
        if (userProvider.currentUser == null &&
            !userProvider.isLoading &&
            userProvider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'ユーザー情報の読み込みに失敗しました',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    userProvider.refreshCurrentUser();
                  },
                  child: const Text('再試行'),
                ),
              ],
            ),
          );
        }

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
          // 検索結果を使用
          posts = postProvider.searchResults;
        }

        // 検索結果のユーザー（フォロー中タブの場合のみ）
        List<UserModel> searchUsers = [];
        if (widget.type == PostListType.following &&
            widget.searchQuery != null &&
            widget.searchQuery!.isNotEmpty) {
          searchUsers = userProvider.searchResults;
        }

        if (postProvider.isLoading && posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LeafLoadingWidget(
                  size: 50,
                  color: AppColors.primary,
                ),
                SizedBox(height: 12),
                Text(
                  '読み込み中...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
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
          color: Colors.black,
          backgroundColor: Colors.transparent,
          strokeWidth: 1.0,
          displacement: 0,
          child: ListView.builder(
            padding: EdgeInsets.zero, // パディングを削除
            itemCount: searchUsers.length + posts.length,
            itemBuilder: (context, index) {
              // 検索結果のユーザーを表示
              if (index < searchUsers.length) {
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: UserListItem(
                    user: searchUsers[index],
                    onTap: () {
                      context.go('/profile/${searchUsers[index].id}');
                    },
                  ),
                );
              }

              // 投稿を表示
              final postIndex = index - searchUsers.length;

              // 広告を表示するかチェック
              if (AdService.shouldShowAd(postIndex)) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PostCardWidget(
                      post: posts[postIndex],
                      onTap: widget.onPostTap != null
                          ? () => widget.onPostTap!(posts[postIndex])
                          : null,
                      onDelete: _canDeletePost(posts[postIndex])
                          ? () => _showDeleteConfirmation(posts[postIndex])
                          : null,
                      fromPage: widget.type == PostListType.following
                          ? 'following'
                          : 'posts',
                    ),
                    // ネイティブ広告を最適化して表示
                    Container(
                      height: 68, // 高さを調整
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: const NativeAdWidget(),
                    ),
                  ],
                );
              } else {
                return PostCardWidget(
                  post: posts[postIndex],
                  onTap: widget.onPostTap != null
                      ? () => widget.onPostTap!(posts[postIndex])
                      : null,
                  onDelete: _canDeletePost(posts[postIndex])
                      ? () => _showDeleteConfirmation(posts[postIndex])
                      : null,
                  fromPage: widget.type == PostListType.following
                      ? 'following'
                      : 'posts',
                );
              }
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
        child: LeafLoadingWidget(
          size: 50,
          color: AppColors.primary,
        ),
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
