import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../providers/post_provider.dart';
import 'advanced_reaction_picker.dart';
import 'enhanced_reaction_display.dart';
import 'reaction_display.dart';
import '../constants/app_colors.dart';
import '../utils/date_time_utils.dart';

class ChatBubbleWidget extends StatefulWidget {
  final PostModel post;
  final bool isOwnMessage;
  final bool showLikeButton; // ハートボタンの表示制御
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ChatBubbleWidget({
    super.key,
    required this.post,
    required this.isOwnMessage,
    this.showLikeButton = false, // デフォルトは非表示
    this.onTap,
    this.onDelete,
  });

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget>
    with SingleTickerProviderStateMixin {
  late PostModel _currentPost;
  bool _isUpdating = false;
  late AnimationController _likeAnimationController;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  // PostProviderと同期
  void _syncWithProvider(PostProvider postProvider) {
    // 最新の投稿データを各リストから検索
    PostModel? updatedPost;

    // 全てのリストから検索
    final allPosts = [
      ...postProvider.userPosts,
      ...postProvider.followingPosts,
      ...postProvider.communityPosts,
    ];

    try {
      updatedPost = allPosts.firstWhere(
        (post) => post.id == _currentPost.id,
      );

      // 更新があった場合のみsetState
      if (updatedPost.reactions != _currentPost.reactions ||
          updatedPost.likeCount != _currentPost.likeCount ||
          updatedPost.likedByUserIds != _currentPost.likedByUserIds) {
        setState(() {
          _currentPost = updatedPost!;
        });
      }
    } catch (e) {
      // 投稿が見つからない場合は現在の状態を維持
      if (kDebugMode) {
        print('投稿が見つかりませんでした: ${_currentPost.id}');
      }
    }
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatBubbleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _currentPost = widget.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Row(
        mainAxisAlignment: widget.isOwnMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 他人のメッセージの場合、左側にアバター表示
          if (!widget.isOwnMessage) ...[
            _buildAvatar(context),
            const SizedBox(width: 8),
          ],

          // メッセージ本体
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: Column(
                crossAxisAlignment: widget.isOwnMessage
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // ユーザー名（他人のメッセージの場合のみ）
                  if (!widget.isOwnMessage) _buildUserName(context),

                  // 吹き出し
                  GestureDetector(
                    onTap: widget.onTap,
                    onLongPress: widget.isOwnMessage ? _showDeleteOption : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.isOwnMessage
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft:
                              Radius.circular(widget.isOwnMessage ? 20 : 4),
                          bottomRight:
                              Radius.circular(widget.isOwnMessage ? 4 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 投稿タイトル
                            if (_currentPost.title.isNotEmpty)
                              Text(
                                _currentPost.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: widget.isOwnMessage
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),

                            // START/END画像セクション（2枚並び）
                            if (_currentPost.title.isNotEmpty)
                              const SizedBox(height: 6),
                            _buildImageSection(context),

                            // START投稿のコメント
                            if (_currentPost.comment != null &&
                                _currentPost.comment!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _currentPost.comment!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: widget.isOwnMessage
                                      ? Colors.white.withOpacity(0.9)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],

                            // END投稿のコメント（完了している場合）
                            if (_currentPost.isCompleted &&
                                _currentPost.endComment != null &&
                                _currentPost.endComment!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _currentPost.endComment!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: widget.isOwnMessage
                                      ? Colors.white.withOpacity(0.9)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],

                            // ステータス・時間情報
                            const SizedBox(height: 6),
                            _buildMetaInfo(context),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // リアクションボタン
                  const SizedBox(height: 2),
                  _buildReactionButton(context),

                  // タイムスタンプ
                  const SizedBox(height: 1),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DateTimeUtils.getRelativeTime(_currentPost.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 自分のメッセージの場合、右側にアバター表示
          if (widget.isOwnMessage) ...[
            const SizedBox(width: 8),
            _buildAvatar(context),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Container(
      height: 140,
      child: Row(
        children: [
          // START画像（左側）
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showImageZoom(context, _currentPost.imageUrl),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImageWidget(_currentPost.imageUrl),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // START画像のラベル
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow,
                      size: 12,
                      color: widget.isOwnMessage
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'START',
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isOwnMessage
                            ? Colors.white.withOpacity(0.8)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // END画像（右側）
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // 投稿者本人のみEND投稿可能
                      final userProvider = context.read<UserProvider>();
                      final currentUser = userProvider.currentUser;

                      if (currentUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ログインが必要です'),
                          ),
                        );
                        return;
                      }

                      // 自分の投稿かどうかを判定
                      final isOwnPost = widget.isOwnMessage;

                      // END投稿可能な条件をチェック（自分の投稿のみ）
                      final canCreateEndPost = isOwnPost;

                      if (canCreateEndPost) {
                        // 自分の投稿またはコミュニティメンバーの場合
                        if (_currentPost.isCompleted &&
                            _currentPost.endImageUrl != null) {
                          // 完了済みで画像がある場合は画像拡大
                          _showImageZoom(context, _currentPost.endImageUrl);
                        } else if (!_currentPost.isCompleted) {
                          // 未完了の場合はEND投稿画面へ
                          // コミュニティ投稿の場合はコミュニティIDも渡す
                          final extra = {
                            'startPostId': _currentPost.id,
                            'startPost': _currentPost,
                          };

                          // コミュニティ投稿の場合はコミュニティIDも追加
                          if (_currentPost.communityIds.isNotEmpty) {
                            extra['communityId'] =
                                _currentPost.communityIds.first;
                          }

                          context.push('/create-end-post', extra: extra);
                        } else {
                          // 完了済みだが画像がない場合は何もしない
                        }
                      } else {
                        // 他人の投稿の場合
                        if (_currentPost.isCompleted &&
                            _currentPost.endImageUrl != null) {
                          // 画像がある場合のみ拡大表示
                          _showImageZoom(context, _currentPost.endImageUrl);
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _currentPost.isCompleted &&
                                _currentPost.endImageUrl != null
                            ? _buildImageWidget(_currentPost.endImageUrl)
                            : _buildEndPlaceholder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // END画像のラベル
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentPost.isCompleted
                          ? Icons.check_circle
                          : Icons.add_photo_alternate,
                      size: 12,
                      color: widget.isOwnMessage
                          ? Colors.white.withOpacity(0.8)
                          : (_currentPost.isCompleted
                              ? AppColors.completed
                              : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'END',
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isOwnMessage
                            ? Colors.white.withOpacity(0.8)
                            : (_currentPost.isCompleted
                                ? AppColors.completed
                                : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndPlaceholder() {
    return Container(
      color: widget.isOwnMessage
          ? Colors.white.withOpacity(0.2)
          : AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isOwnMessage
                  ? Icons.add_photo_alternate
                  : Icons.hourglass_empty,
              color: widget.isOwnMessage
                  ? Colors.white.withOpacity(0.6)
                  : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              widget.isOwnMessage ? 'END投稿' : 'END',
              style: TextStyle(
                color: widget.isOwnMessage
                    ? Colors.white.withOpacity(0.6)
                    : AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _currentPost.isCompleted ? Icons.check_circle : Icons.play_arrow,
              size: 14,
              color: widget.isOwnMessage
                  ? Colors.white.withOpacity(0.8)
                  : (_currentPost.isCompleted
                      ? AppColors.completed
                      : AppColors.inProgress),
            ),
            const SizedBox(width: 4),
            Text(
              _currentPost.isCompleted ? '完了' : '進行中',
              style: TextStyle(
                fontSize: 12,
                color: widget.isOwnMessage
                    ? Colors.white.withOpacity(0.8)
                    : (_currentPost.isCompleted
                        ? AppColors.completed
                        : AppColors.inProgress),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.schedule,
              size: 12,
              color: widget.isOwnMessage
                  ? Colors.white.withOpacity(0.6)
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 2),
            Text(
              _currentPost.isCompleted
                  ? DateTimeUtils.formatDateTime(_currentPost.actualEndTime ??
                      _currentPost.scheduledEndTime!)
                  : _currentPost.scheduledEndTime != null
                      ? DateTimeUtils.formatDateTime(
                          _currentPost.scheduledEndTime!)
                      : '未定',
              style: TextStyle(
                fontSize: 10,
                color: widget.isOwnMessage
                    ? Colors.white.withOpacity(0.6)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        // 集中時間を表示（完了した場合のみ）
        if (_currentPost.isCompleted) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer,
                size: 12,
                color: widget.isOwnMessage
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black,
              ),
              const SizedBox(width: 2),
              Text(
                '集中時間: ${_formatActualDuration(_currentPost)}',
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isOwnMessage
                      ? Colors.white.withOpacity(0.7)
                      : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildReactionButton(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final currentUser = userProvider.currentUser;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // リアクション表示（強化版）
            EnhancedReactionDisplay(
              key: ValueKey(
                  '${_currentPost.id}_${_currentPost.reactions.hashCode}'),
              post: _currentPost,
              currentUserId: currentUser?.id,
              onReactionTap: (emoji) =>
                  _toggleReaction(context, emoji, currentUser),
              onAddReaction: () => _showReactionPicker(context, currentUser),
              maxDisplayed: 4,
              emojiSize: 18,
            ),

            // ハートボタン（従来のいいね機能）- 条件付き表示
            if (widget.showLikeButton) ...[
              const SizedBox(height: 4),
              LikeButton(
                post: _currentPost,
                currentUserId: currentUser?.id,
                onTap: () => _toggleLike(context, currentUser),
                isLoading: _isUpdating,
              ),
            ],
          ],
        );
      },
    );
  }

  // リアクション選択画面を表示
  void _showReactionPicker(BuildContext context, UserModel? currentUser) {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    showAdvancedReactionPicker(context, (emoji) {
      _addReaction(context, emoji, currentUser);
    });
  }

  // リアクション追加
  Future<void> _addReaction(
      BuildContext context, String emoji, UserModel currentUser) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final postProvider = context.read<PostProvider>();

      // PostProviderのaddReactionが即座にローカル状態とnotifyListenersを実行
      final success = await postProvider.addReaction(
          _currentPost.id, emoji, currentUser.id);

      if (success) {
        // PostProviderから最新状態を同期
        _syncWithProvider(postProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(postProvider.errorMessage ?? 'リアクションの追加に失敗しました')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('リアクション追加エラー: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  // リアクションの切り替え（追加/削除）
  void _toggleReaction(
      BuildContext context, String emoji, UserModel? currentUser) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final postProvider = context.read<PostProvider>();
      final hasReaction = _currentPost.hasReaction(emoji, currentUser.id);

      bool success;
      if (hasReaction) {
        success = await postProvider.removeReaction(
            _currentPost.id, emoji, currentUser.id);
      } else {
        success = await postProvider.addReaction(
            _currentPost.id, emoji, currentUser.id);
      }

      if (success) {
        // PostProviderから最新状態を同期
        _syncWithProvider(postProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(postProvider.errorMessage ?? 'リアクションの更新に失敗しました')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('リアクション切り替えエラー: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _toggleLike(BuildContext context, UserModel? currentUser) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    if (_isUpdating) return;

    if (kDebugMode) {
      print(
          'リアクション開始: 投稿ID=${_currentPost.id}, ユーザーID=${currentUser.id}'); // デバッグログ追加
    }

    setState(() {
      _isUpdating = true;
    });

    final postProvider = context.read<PostProvider>();
    final isLiked = _currentPost.isLikedBy(currentUser.id);

    if (kDebugMode) {
      print('現在のいいね状態: $isLiked, いいね数: ${_currentPost.likeCount}'); // デバッグログ追加
    }

    // 即座にローカル状態を更新（楽観的更新）
    final newLikeCount = isLiked
        ? (_currentPost.likeCount > 0 ? _currentPost.likeCount - 1 : 0)
        : _currentPost.likeCount + 1;

    final newLikedByUserIds = isLiked
        ? _currentPost.likedByUserIds
            .where((id) => id != currentUser.id)
            .toList()
        : [..._currentPost.likedByUserIds, currentUser.id];

    if (kDebugMode) {
      print(
          '新しいいいね数: $newLikeCount, いいねユーザー数: ${newLikedByUserIds.length}'); // デバッグログ追加
    }

    // ローカル状態を即座に更新
    setState(() {
      _currentPost = _currentPost.copyWith(
        likeCount: newLikeCount,
        likedByUserIds: newLikedByUserIds,
      );
    });

    try {
      bool success;
      if (isLiked) {
        if (kDebugMode) {
          print('いいね解除を実行'); // デバッグログ追加
        }
        success =
            await postProvider.unlikePost(_currentPost.id, currentUser.id);
      } else {
        if (kDebugMode) {
          print('いいね追加を実行'); // デバッグログ追加
        }
        success = await postProvider.likePost(_currentPost.id, currentUser.id);
      }

      if (kDebugMode) {
        print('サーバー更新結果: $success'); // デバッグログ追加
      }

      if (success) {
        // サーバー更新も成功した場合、PostProviderの各リストも更新
        postProvider.updatePostInLists(_currentPost);
        if (kDebugMode) {
          print('リアクション成功'); // デバッグログ追加
        }
      } else {
        // 失敗した場合は元の状態に戻す
        setState(() {
          _currentPost = widget.post;
        });

        if (kDebugMode) {
          print('リアクション失敗: ${postProvider.errorMessage}'); // デバッグログ追加
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postProvider.errorMessage ?? 'エラーが発生しました')),
        );
      }
    } catch (e) {
      // エラーが発生した場合は元の状態に戻す
      setState(() {
        _currentPost = widget.post;
      });

      if (kDebugMode) {
        print('リアクションエラー: $e'); // デバッグログ追加
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _showImageZoom(BuildContext context, String? imageUrl) {
    if (imageUrl == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: _buildImageWidget(imageUrl),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return FutureBuilder<UserModel?>(
          future: userProvider.getUserById(_currentPost.userId),
          builder: (context, snapshot) {
            final user = snapshot.data;
            return GestureDetector(
              onTap: () {
                if (user != null) {
                  context.go('/profile/${user.id}');
                }
              },
              child: CircleAvatar(
                radius: 16,
                backgroundImage: user?.profileImageUrl != null
                    ? CachedNetworkImageProvider(user!.profileImageUrl!)
                    : null,
                child: user?.profileImageUrl == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserName(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return FutureBuilder<UserModel?>(
          future: userProvider.getUserById(_currentPost.userId),
          builder: (context, snapshot) {
            final user = snapshot.data;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                user?.displayName ?? 'ユーザー名',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null) {
      return Container(
        color: widget.isOwnMessage
            ? Colors.white.withOpacity(0.2)
            : AppColors.surfaceVariant,
        child: Center(
          child: Icon(
            Icons.image,
            size: 32,
            color: widget.isOwnMessage
                ? Colors.white.withOpacity(0.6)
                : AppColors.textHint,
          ),
        ),
      );
    }

    if (_isNetworkUrl(imageUrl)) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: widget.isOwnMessage
              ? Colors.white.withOpacity(0.2)
              : AppColors.surfaceVariant,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: widget.isOwnMessage
              ? Colors.white.withOpacity(0.2)
              : AppColors.surfaceVariant,
          child: Icon(
            Icons.error,
            color: widget.isOwnMessage
                ? Colors.white.withOpacity(0.6)
                : AppColors.error,
          ),
        ),
      );
    } else {
      try {
        return Image.file(
          File(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: widget.isOwnMessage
                ? Colors.white.withOpacity(0.2)
                : AppColors.surfaceVariant,
            child: Icon(
              Icons.error,
              color: widget.isOwnMessage
                  ? Colors.white.withOpacity(0.6)
                  : AppColors.error,
            ),
          ),
        );
      } catch (e) {
        return Container(
          color: widget.isOwnMessage
              ? Colors.white.withOpacity(0.2)
              : AppColors.surfaceVariant,
          child: Icon(
            Icons.error,
            color: widget.isOwnMessage
                ? Colors.white.withOpacity(0.6)
                : AppColors.error,
          ),
        );
      }
    }
  }

  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  void _showDeleteOption() {
    if (widget.onDelete != null) {
      widget.onDelete!();
    }
  }

  // 集中時間を時間分単位で表示するヘルパーメソッド
  String _formatActualDuration(PostModel post) {
    if (post.actualEndTime == null) return '未完了';

    final duration = post.actualEndTime!.difference(post.createdAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
  }
}
