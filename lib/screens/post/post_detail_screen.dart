import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  @override
  void initState() {
    super.initState();
    _post = widget.post; // 初期化を追加

    // 投稿詳細を読み込む
    _loadPostDetails();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPostDetails() async {
    print('_loadPostDetails called - widget.postId: ${widget.postId}');

    if (_post != null) {
      print('_post already exists, skipping load');
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;
      if (currentUser != null) {}
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

  // PostProviderから最新の投稿データで_postを同期
  void _syncPostWithProvider(PostProvider postProvider) {
    if (_post == null) return;

    // 全てのリストから検索
    final allPosts = [
      ...postProvider.userPosts,
      ...postProvider.followingPosts,
      ...postProvider.communityPosts,
    ];

    try {
      final updatedPost = allPosts.firstWhere(
        (post) => post.id == _post!.id,
      );

      // 更新があった場合のみsetState
      if (updatedPost.reactions != _post!.reactions ||
          updatedPost.likeCount != _post!.likeCount ||
          updatedPost.likedByUserIds != _post!.likedByUserIds) {
        setState(() {
          _post = updatedPost;
        });
      }
    } catch (e) {
      // 投稿が見つからない場合は現在の状態を維持
      if (kDebugMode) {
        print('投稿が見つかりませんでした: ${_post!.id}');
      }
    }
  }

  // リアクション追加
  Future<void> _addReaction(String emoji, UserModel currentUser) async {
    if (_post == null) return;

    try {
      final postProvider = context.read<PostProvider>();
      final success =
          await postProvider.addReaction(_post!.id, emoji, currentUser.id);

      if (success) {
        // PostProviderから最新の投稿データで_postを更新
        _syncPostWithProvider(postProvider);
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
        // PostProviderから最新の投稿データで_postを更新
        _syncPostWithProvider(postProvider);

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
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width -
                                  32, // パディング考慮
                            ),
                            child: EnhancedReactionDisplay(
                              post: _post!,
                              currentUserId: currentUser?.id,
                              onReactionTap: (emoji) =>
                                  _toggleReaction(emoji, currentUser),
                              onAddReaction: () =>
                                  _showReactionPicker(currentUser),
                              maxDisplayed: 8, // 投稿詳細では多めに表示
                              emojiSize: 22,
                            ),
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
