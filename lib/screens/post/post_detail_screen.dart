import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/post_card_widget.dart';
import '../../widgets/advanced_reaction_picker.dart';
import '../../widgets/enhanced_reaction_display.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final PostModel? post;
  final String? fromCommunity; // コミュニティから遷移してきた場合のコミュニティID
  final String? fromPage; // 遷移元のページ識別子

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.post,
    this.fromCommunity,
    this.fromPage,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  PostModel? _post;
  bool _isLoading = false;
  bool _isLiked = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _post = widget.post; // 初期化を追加
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200), // アニメーション時間を調整
      vsync: this,
    );

    // 回転アニメーション
    _rotationAnimation = Tween<double>(
      begin: -0.2,
      end: 0.0, // 終了位置を0に修正
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.easeInOut,
    ));

    // スケールアニメーション
    _likeAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));

    // 投稿詳細を読み込む
    _loadPostDetails();
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadPostDetails() async {
    print('_loadPostDetails called - widget.postId: ${widget.postId}');

    if (_post != null) {
      print('_post already exists, skipping load');
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
      final postProvider = context.read<PostProvider>();
      final postId = widget.postId; // widget.postIdを使用
      print('Loading post with ID: $postId');
      final post = await postProvider.getPostById(postId);

      if (post != null) {
        setState(() {
          _post = post;
          final userProvider = context.read<UserProvider>();
          final currentUser = userProvider.currentUser;
          if (currentUser != null) {
            _isLiked = post.isLikedBy(currentUser.id);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿が見つかりません')),
          );
        }
      }
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

  // リアクション選択画面を表示
  void _showReactionPicker(UserModel? currentUser) {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    showAdvancedReactionPicker(context, (emoji) {
      _addReaction(emoji, currentUser);
    });
  }

  // リアクション追加
  Future<void> _addReaction(String emoji, UserModel currentUser) async {
    if (_post == null) return;

    try {
      final postProvider = context.read<PostProvider>();
      final success =
          await postProvider.addReaction(_post!.id, emoji, currentUser.id);

      if (success) {
        // ローカル状態を更新
        setState(() {
          final newReactions = Map<String, List<String>>.from(_post!.reactions);
          if (newReactions[emoji] == null) {
            newReactions[emoji] = [];
          }
          if (!newReactions[emoji]!.contains(currentUser.id)) {
            newReactions[emoji]!.add(currentUser.id);
          }
          _post = _post!.copyWith(reactions: newReactions);
        });

        // PostProviderの各リストも更新
        postProvider.updatePostInLists(_post!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(postProvider.errorMessage ?? 'リアクションの追加に失敗しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  // リアクションの切り替え（追加/削除）
  Future<void> _toggleReaction(String emoji, UserModel? currentUser) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    if (_post == null) return;

    try {
      final postProvider = context.read<PostProvider>();
      final hasReaction = _post!.hasReaction(emoji, currentUser.id);

      bool success;
      if (hasReaction) {
        success =
            await postProvider.removeReaction(_post!.id, emoji, currentUser.id);
      } else {
        success =
            await postProvider.addReaction(_post!.id, emoji, currentUser.id);
      }

      if (success) {
        // ローカル状態を更新
        setState(() {
          final newReactions = Map<String, List<String>>.from(_post!.reactions);

          if (hasReaction) {
            // リアクション削除
            newReactions[emoji]?.remove(currentUser.id);
            if (newReactions[emoji]?.isEmpty == true) {
              newReactions.remove(emoji);
            }
          } else {
            // リアクション追加
            if (newReactions[emoji] == null) {
              newReactions[emoji] = [];
            }
            if (!newReactions[emoji]!.contains(currentUser.id)) {
              newReactions[emoji]!.add(currentUser.id);
            }
          }

          _post = _post!.copyWith(reactions: newReactions);
        });

        // PostProviderの各リストも更新
        postProvider.updatePostInLists(_post!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(postProvider.errorMessage ?? 'リアクションの更新に失敗しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
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
              Navigator.of(context).pop();
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
        child: CircularProgressIndicator(
          color: Colors.black,
        ),
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
          Navigator.of(context).pop();
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
    // デバッグ情報を追加
    print(
        'PostDetailScreen build - _isLoading: $_isLoading, _post: ${_post?.id}');

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.black,
          ),
        ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 前の画面に戻る
            if (context.canPop()) {
              context.pop();
            } else {
              // 戻る先がない場合はホーム画面に戻る
              context.go('/home');
            }
          },
        ),
        title: const Text('投稿詳細'),
        actions: [
          // 投稿者本人の場合のみ削除ボタンを表示
          if (_isPostOwner()) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 投稿内容（アクションボタン非表示、画像拡大機能有効）
            PostCardWidget(
              post: _post!,
              showActions: false,
              onDelete: _isPostOwner() ? _showDeleteConfirmation : null,
              fromPage: 'detail', // 詳細画面内での使用
              enableImageZoom: true, // 画像拡大機能を有効化
            ),

            // 実際にかかった時間の表示（完了投稿の場合）
            if (_post!.isCompleted && _post!.actualEndTime != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: Colors.black, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _getElapsedTime(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                    ),
                  ],
                ),
              ),
            ],

            // カスタムアクションボタン
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // リアクションシステム
                  Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      final currentUser = userProvider.currentUser;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // リアクション表示（強化版）
                          EnhancedReactionDisplay(
                            post: _post!,
                            currentUserId: currentUser?.id,
                            onReactionTap: (emoji) =>
                                _toggleReaction(emoji, currentUser),
                            onAddReaction: () =>
                                _showReactionPicker(currentUser),
                            maxDisplayed: 6,
                            emojiSize: 24,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 日時フォーマット関数
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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

  // 残り時間を計算する関数
  String _getRemainingTime() {
    if (_post?.scheduledEndTime == null) return '未定';

    final now = DateTime.now();
    final remaining = _post!.scheduledEndTime!.difference(now);

    if (remaining.isNegative) {
      final overdue = now.difference(_post!.scheduledEndTime!);
      final days = overdue.inDays;
      final hours = overdue.inHours % 24;
      final minutes = overdue.inMinutes % 60;

      if (days > 0) {
        return '予定時刻を${days}日${hours}時間${minutes}分経過';
      } else if (hours > 0) {
        return '予定時刻を${hours}時間${minutes}分経過';
      } else {
        return '予定時刻を${minutes}分経過';
      }
    } else {
      final days = remaining.inDays;
      final hours = remaining.inHours % 24;
      final minutes = remaining.inMinutes % 60;

      if (days > 0) {
        return '残り${days}日${hours}時間${minutes}分';
      } else if (hours > 0) {
        return '残り${hours}時間${minutes}分';
      } else {
        return '残り${minutes}分';
      }
    }
  }
}
