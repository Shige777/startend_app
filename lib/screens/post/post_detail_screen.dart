import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/post_model.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/post_card_widget.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final PostModel? post;
  final String? fromCommunity; // コミュニティから遷移してきた場合のコミュニティID

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.post,
    this.fromCommunity,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  PostModel? _post;
  bool _isLoading = false;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadPostDetails();
  }

  Future<void> _loadPostDetails() async {
    if (_post != null) {
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;
      if (currentUser != null) {
        setState(() {
          _isLiked = _post!.isLikedBy(currentUser.id);
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: PostProviderに個別投稿取得メソッドを追加
      // 現在は仮実装
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿の読み込みに失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;

    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    setState(() {
      _isLiked = !_isLiked;
      _post = _post!.copyWith(
        likeCount: _isLiked ? _post!.likeCount + 1 : _post!.likeCount - 1,
        likedByUserIds: _isLiked
            ? [..._post!.likedByUserIds, currentUser.id]
            : _post!.likedByUserIds
                .where((id) => id != currentUser.id)
                .toList(),
      );
    });

    try {
      bool success;
      if (_isLiked) {
        success = await postProvider.likePost(_post!.id, currentUser.id);
      } else {
        success = await postProvider.unlikePost(_post!.id, currentUser.id);
      }

      if (!success) {
        // エラーの場合は状態を戻す
        setState(() {
          _isLiked = !_isLiked;
          _post = _post!.copyWith(
            likeCount: _isLiked ? _post!.likeCount + 1 : _post!.likeCount - 1,
            likedByUserIds: _isLiked
                ? [..._post!.likedByUserIds, currentUser.id]
                : _post!.likedByUserIds
                    .where((id) => id != currentUser.id)
                    .toList(),
          );
        });
      }
    } catch (e) {
      // エラーの場合は状態を戻す
      setState(() {
        _isLiked = !_isLiked;
        _post = _post!.copyWith(
          likeCount: _isLiked ? _post!.likeCount + 1 : _post!.likeCount - 1,
          likedByUserIds: _isLiked
              ? [..._post!.likedByUserIds, currentUser.id]
              : _post!.likedByUserIds
                  .where((id) => id != currentUser.id)
                  .toList(),
        );
      });
    }
  }

  // 投稿者本人かどうかを判定
  bool _isPostOwner() {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    return currentUser != null && _post?.userId == currentUser.id;
  }

  // 削除確認ダイアログを表示
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿削除'),
        content: const Text('この投稿を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePost();
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
  Future<void> _deletePost() async {
    if (_post == null) return;

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
      final success = await postProvider.deletePost(_post!.id);

      if (mounted) {
        Navigator.of(context).pop(); // ローディング終了

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿を削除しました')),
          );
          // 前の画面に戻る
          if (widget.fromCommunity != null) {
            context.go('/community/${widget.fromCommunity}');
          } else if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('投稿詳細')),
        body: const Center(
          child: Text('投稿が見つかりません'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // コミュニティから遷移してきた場合は、コミュニティ画面に戻る
            if (widget.fromCommunity != null) {
              context.go('/community/${widget.fromCommunity}');
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('投稿詳細'),
        actions: [
          // 投稿者本人の場合のみ削除ボタンを表示
          if (_isPostOwner())
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: シェア機能の実装
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 投稿内容（アクションボタン非表示）
            PostCardWidget(
              post: _post!,
              showActions: false,
              onDelete: _isPostOwner() ? _showDeleteConfirmation : null,
            ),

            // 実際にかかった時間の表示（完了した投稿の場合のみ）
            if (_post!.status == PostStatus.completed &&
                _post!.actualEndTime != null)
              Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Card(
                  color: AppColors.completed.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer, color: AppColors.completed),
                            const SizedBox(width: 8),
                            Text(
                              '実際にかかった時間',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.completed,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getElapsedTime(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.completed,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '開始: ${DateTimeUtils.formatDateTime(_post!.createdAt)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                        Text(
                          '完了: ${DateTimeUtils.formatDateTime(_post!.actualEndTime!)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // カスタムアクションボタン
            Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Row(
                children: [
                  // いいねボタン
                  InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 24,
                            color: _isLiked
                                ? AppColors.flame
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _post!.likeCount.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: _isLiked
                                      ? AppColors.flame
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // END投稿作成ボタン（進行中の投稿で投稿者本人の場合のみ）
            if (_post!.status == PostStatus.inProgress && _isPostOwner())
              Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/create-end-post', extra: {
                        'startPostId': _post!.id,
                        'startPost': _post!,
                        'fromCommunity': widget.fromCommunity,
                      });
                    },
                    icon: const Icon(Icons.flag),
                    label: const Text('END投稿を作成'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.completed,
                      foregroundColor: AppColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 実際にかかった時間を計算する関数
  String _getElapsedTime() {
    if (_post?.actualEndTime == null) return '';

    final elapsed = _post!.actualEndTime!.difference(_post!.createdAt);
    final days = elapsed.inDays;
    final hours = elapsed.inHours % 24;
    final minutes = elapsed.inMinutes % 60;

    if (days > 0) {
      return '${days}日${hours}時間${minutes}分';
    } else if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
  }
}
