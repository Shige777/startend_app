import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../utils/date_time_utils.dart';
import '../providers/user_provider.dart';
import '../providers/post_provider.dart';
import '../models/user_model.dart';
import 'advanced_reaction_picker.dart';
import 'enhanced_reaction_display.dart';

class PostCardWidget extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final bool showActions; // アクションボタンの表示制御
  final VoidCallback? onDelete;
  final String? fromPage; // 遷移元のページ識別子
  final bool enableImageZoom; // 画像拡大機能の有効化

  const PostCardWidget({
    super.key,
    required this.post,
    this.onTap,
    this.showActions = true, // デフォルトは表示
    this.onDelete,
    this.fromPage,
    this.enableImageZoom = false, // デフォルトは無効
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostCardWidget &&
        other.post.id == post.id &&
        other.post.updatedAt == post.updatedAt &&
        other.showActions == showActions;
  }

  @override
  int get hashCode => Object.hash(post.id, post.updatedAt, showActions);

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  late Animation<Offset> _fallingAnimation;
  late Animation<double> _rotationAnimation;
  bool _isProcessingLike = false; // リアクション処理中フラグ

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200), // アニメーション時間を調整
      vsync: this,
    );

    // 落下アニメーション
    _fallingAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0), // 開始位置を調整
      end: const Offset(0, 0), // 終了位置を0に修正
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.easeOut,
    ));

    // 回転アニメーション
    _rotationAnimation = Tween<double>(
      begin: -0.2,
      end: 0.0, // 終了位置を0に修正
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.easeOut,
    ));

    // スケールアニメーション
    _likeAnimation = Tween<double>(
      begin: 0.8, // 開始サイズを調整
      end: 1.0, // 終了サイズを調整
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  // 画像URLがネットワークURLかローカルファイルパスかを判別
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // 画像を表示するWidgetを構築
  Widget _buildImageWidget(String? imageUrl,
      {BoxFit fit = BoxFit.cover, bool enableZoom = false}) {
    if (imageUrl == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(Icons.image, size: 32, color: AppColors.textHint),
        ),
      );
    }

    Widget imageWidget;

    if (_isNetworkUrl(imageUrl)) {
      // ネットワーク画像
      if (kIsWeb) {
        // Web環境ではImage.networkを使用し、エラーハンドリングを改善
        imageWidget = Container(
          width: double.infinity,
          height: double.infinity,
          child: Image.network(
            imageUrl,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: AppColors.surfaceVariant,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print('Web画像読み込みエラー: $error');
              }
              return Container(
                color: AppColors.surfaceVariant,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: AppColors.error, size: 32),
                    SizedBox(height: 8),
                    Text(
                      '画像を読み込めません',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      } else {
        // モバイル環境ではCachedNetworkImageを使用
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12), // 角を丸く
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: AppColors.surfaceVariant,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.surfaceVariant,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: AppColors.error, size: 32),
                    SizedBox(height: 8),
                    Text(
                      '画像を読み込めません',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } else {
      // ローカルファイル
      if (kIsWeb) {
        // Webの場合はエラー画像を表示
        imageWidget = Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.surfaceVariant,
          child: const Icon(Icons.error, color: AppColors.error),
        );
      } else {
        // モバイルの場合はFile.imageを使用
        try {
          imageWidget = ClipRRect(
            borderRadius: BorderRadius.circular(12), // 角を丸く
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: Image.file(
                File(imageUrl),
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.error, color: AppColors.error),
                ),
              ),
            ),
          );
        } catch (e) {
          imageWidget = ClipRRect(
            borderRadius: BorderRadius.circular(12), // 角を丸く
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.error, color: AppColors.error),
            ),
          );
        }
      }
    }

    // 拡大機能が有効な場合はGestureDetectorでラップ
    if (enableZoom) {
      return Builder(
        builder: (context) => GestureDetector(
          onTap: () => _showImageZoomDialog(context, imageUrl),
          child: imageWidget,
        ),
      );
    }

    return imageWidget;
  }

  // 画像拡大ダイアログを表示
  void _showImageZoomDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                // 背景をタップして閉じる
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                  ),
                ),
                // 拡大画像
                Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _isNetworkUrl(imageUrl)
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.error,
                              color: Colors.white,
                              size: 64,
                            ),
                          )
                        : kIsWeb
                            ? const Icon(
                                Icons.error,
                                color: Colors.white,
                                size: 64,
                              )
                            : Image.file(
                                File(imageUrl),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.error,
                                  color: Colors.white,
                                  size: 64,
                                ),
                              ),
                  ),
                ),
                // 閉じるボタン
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;
    final isOwnPost = currentUser?.id == widget.post.userId; // 自分の投稿かどうか判定

    return Card(
      margin: EdgeInsets.zero, // 余白を削除
      elevation: 0, // 影を削除
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // 12から16に変更
      ),
      color: Colors.white, // 背景色を白に統一
      child: InkWell(
        onTap: widget.onTap ??
            () => context.push('/post/${widget.post.id}', extra: {
                  'post': widget.post,
                  'fromPage': widget.fromPage, // 軌跡画面から来たことを識別
                }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー（ユーザー情報）
            Consumer<UserProvider>(
              builder: (context, userProvider, _) {
                return FutureBuilder<UserModel?>(
                  future: userProvider.getUserById(widget.post.userId),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    return Padding(
                      padding:
                          const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (user != null) {
                                context.go('/profile/${user.id}');
                              }
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: user?.profileImageUrl != null
                                  ? CachedNetworkImageProvider(
                                      user!.profileImageUrl!)
                                  : null,
                              child: user?.profileImageUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (user != null) {
                                  context.go('/profile/${user.id}');
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.displayName ?? 'ユーザー名',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    DateTimeUtils.getRelativeTime(
                                        widget.post.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // _buildStatusChip(), // 完了文字を削除
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            // 画像（START投稿は常に2枚表示：左側START、右側END）
            _buildImageSection(context),

            // コンテンツ
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
                vertical: 2, // 上下のパディングを縮小
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // START投稿のコメント
                  if (widget.post.comment != null) ...[
                    Text(
                      widget.post.comment!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),

            // END投稿のコメント（完了している場合）- 画像の下に表示
            if (widget.post.isCompleted && widget.post.endComment != null) ...[
              Padding(
                padding: const EdgeInsets.only(
                  left: AppConstants.defaultPadding,
                  right: AppConstants.defaultPadding,
                  bottom: 2, // 下部パディングも縮小
                ),
                child: Text(
                  widget.post.endComment!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],

            // 終了時刻の表示（完了している場合）
            if (widget.post.isCompleted &&
                widget.post.actualEndTime != null) ...[
              Padding(
                padding: const EdgeInsets.only(
                  left: AppConstants.defaultPadding,
                  right: AppConstants.defaultPadding,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '終了：${DateTimeUtils.formatDateTime(widget.post.actualEndTime!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],

            // アクションボタン
            if (widget.showActions) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultPadding),
                child: Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    final currentUser = userProvider.currentUser;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // リアクション表示（強化版）- 幅制限を回避
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 
                                      (AppConstants.defaultPadding * 2), // パディング考慮
                          ),
                          child: EnhancedReactionDisplay(
                            post: widget.post,
                            currentUserId: currentUser?.id,
                            onReactionTap: (emoji) => _toggleReaction(context, emoji, currentUser),
                            onAddReaction: () => _showReactionPicker(context, currentUser),
                            maxDisplayed: 6, // フォロー中タブでは少し多めに表示
                            emojiSize: 18,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],

            // 投稿間の区切りを削除（シームレス化）
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Container(
      height: 280, // 高さを調整
      child: Column(
        children: [
          // タイトル（タイトルがある場合のみ表示）
          if (widget.post.title.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.background, // 背景色を統一
              child: Text(
                widget.post.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          // 画像セクション
          Expanded(
            child: Row(
              children: [
                // START画像（左側）
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          child: _buildImageWidget(widget.post.imageUrl,
                              fit: BoxFit.cover,
                              enableZoom: widget.enableImageZoom),
                        ),
                      ),
                      // START画像の下にラベル
                      Container(
                        width: double.infinity,
                        height: 20, // 高さを小さくして画像を大きく
                        padding: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 4),
                        color: AppColors.background, // 背景色を統一
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '開始: ${DateTimeUtils.formatDateTime(widget.post.createdAt)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 9,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 区切り線（薄く）
                Container(
                    width: 0.5, color: AppColors.divider.withOpacity(0.3)),
                // END画像（右側）
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) => GestureDetector(
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
                              final isOwnPost =
                                  widget.post.userId == currentUser.id;

                              // END投稿可能な条件をチェック（自分の投稿のみ）
                              final canCreateEndPost = isOwnPost;

                              if (!canCreateEndPost) {
                                // 他人の投稿の場合
                                if (widget.post.isCompleted &&
                                    widget.post.endImageUrl != null) {
                                  // 完了済みで画像がある場合は画像拡大
                                  _showImageZoomDialog(
                                      context, widget.post.endImageUrl!);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('自分の投稿のみEND投稿できます'),
                                    ),
                                  );
                                }
                                return;
                              }

                              // 自分の投稿またはコミュニティメンバーの場合
                              if (widget.post.isCompleted &&
                                  widget.post.endImageUrl != null) {
                                // 完了済みで画像がある場合は画像拡大
                                _showImageZoomDialog(
                                    context, widget.post.endImageUrl!);
                              } else {
                                // 未完了、または完了済みだが画像がない場合（自動完了含む）はEND投稿画面へ
                                // コミュニティ投稿の場合はコミュニティIDも渡す
                                final extra = {
                                  'startPostId': widget.post.id,
                                  'startPost': widget.post,
                                };

                                // コミュニティ投稿の場合はコミュニティIDも追加
                                if (widget.post.communityIds.isNotEmpty) {
                                  extra['communityId'] =
                                      widget.post.communityIds.first;
                                }

                                context.push('/create-end-post', extra: extra);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              color: AppColors.surfaceVariant,
                              child: widget.post.isCompleted
                                  ? (widget.post.endImageUrl != null
                                      ? _buildImageWidget(
                                          widget.post.endImageUrl,
                                          fit: BoxFit.cover,
                                          enableZoom: widget.enableImageZoom)
                                      : const Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.add_photo_alternate,
                                                  color:
                                                      AppColors.textSecondary,
                                                  size: 32),
                                              SizedBox(height: 4),
                                              Text('END投稿',
                                                  style: TextStyle(
                                                      color: AppColors
                                                          .textSecondary)),
                                            ],
                                          ),
                                        ))
                                  : const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate,
                                              color: AppColors.textSecondary,
                                              size: 32),
                                          SizedBox(height: 4),
                                          Text('END投稿',
                                              style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      // END画像の下にラベル
                      Container(
                        width: double.infinity,
                        height: 20, // 高さを小さくして画像を大きく
                        padding: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 4),
                        color: AppColors.background, // 背景色を統一
                        child: widget.post.scheduledEndTime != null
                            ? Row(
                                children: [
                                  Icon(
                                    widget.post.isCompleted
                                        ? Icons.check_circle
                                        : Icons.schedule,
                                    size: 12,
                                    color: widget.post.isOverdue
                                        ? AppColors.error
                                        : widget.post.isCompleted
                                            ? AppColors.completed
                                            : AppColors.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      widget.post.isCompleted
                                          ? '完了: ${DateTimeUtils.formatDateTime(widget.post.actualEndTime ?? widget.post.scheduledEndTime!)}'
                                          : '予定: ${DateTimeUtils.formatDateTime(widget.post.scheduledEndTime!)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: widget.post.isOverdue
                                                ? AppColors.error
                                                : widget.post.isCompleted
                                                    ? AppColors.completed
                                                    : AppColors.primary,
                                            fontSize: 9,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox(height: 16), // 空のスペース
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // 投稿開始時刻
        Row(
          children: [
            const Icon(Icons.play_arrow,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              '開始: ${DateTimeUtils.formatDateTime(widget.post.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 完了予定時刻 or 完了時刻
        if (widget.post.scheduledEndTime != null) ...[
          // 進行期間（予定時間）を表示
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '進行期間: ${_formatScheduledDuration(widget.post)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ],
          ),

          // 集中時間（実際にかかった時間）を表示（完了した場合のみ）
          if (widget.post.isCompleted && widget.post.actualEndTime != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: AppColors.completed,
                ),
                const SizedBox(width: 4),
                Text(
                  '集中時間: ${_formatActualDuration(widget.post)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.completed,
                      ),
                ),
              ],
            ),
          ],
        ] else if (widget.post.isCompleted &&
            widget.post.actualEndTime != null) ...[
          // scheduledEndTimeがない場合でも、actualEndTimeがあれば表示
          Row(
            children: [
              Icon(
                Icons.timer,
                size: 16,
                color: AppColors.completed,
              ),
              const SizedBox(width: 4),
              Text(
                '集中時間: ${_formatActualDuration(widget.post)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.completed,
                    ),
              ),
            ],
          ),
        ],

        // 使用時間を表示（完了した場合のみ）
        if (widget.post.isCompleted) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.timer,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 4),
              Text(
                '使用時間: ${widget.post.totalUsageTimeString}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip() {
    Color chipColor;
    Widget chipContent;

    switch (widget.post.status) {
      case PostStatus.concentration:
        chipColor = AppColors.textPrimary;
        chipContent =
            const Icon(Icons.flash_on, color: AppColors.textPrimary, size: 16);
        break;
      case PostStatus.inProgress:
        chipColor = AppColors.inProgress;
        chipContent = Text(
          '進行中',
          style: TextStyle(
            color: chipColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case PostStatus.completed:
        chipColor = AppColors.completed;
        chipContent = Text(
          '完了',
          style: TextStyle(
            color: chipColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case PostStatus.overdue:
        chipColor = AppColors.error;
        chipContent = Text(
          '期限切れ',
          style: TextStyle(
            color: chipColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: chipContent,
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
  Future<void> _addReaction(BuildContext context, String emoji, UserModel currentUser) async {
    if (_isProcessingLike) return;

    setState(() {
      _isProcessingLike = true;
    });

    try {
      final postProvider = context.read<PostProvider>();
      final success = await postProvider.addReaction(widget.post.id, emoji, currentUser.id);

      if (success) {
        // PostProviderの各リストも更新
        final updatedPost = widget.post.copyWith(
          reactions: {
            ...widget.post.reactions,
            emoji: [
              ...(widget.post.reactions[emoji] ?? []),
              if (!(widget.post.reactions[emoji]?.contains(currentUser.id) ?? false)) currentUser.id,
            ],
          },
        );
        postProvider.updatePostInLists(updatedPost);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postProvider.errorMessage ?? 'リアクションの追加に失敗しました')),
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
        _isProcessingLike = false;
      });
    }
  }

  // リアクションの切り替え（追加/削除）
  void _toggleReaction(BuildContext context, String emoji, UserModel? currentUser) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    if (_isProcessingLike) return;

    setState(() {
      _isProcessingLike = true;
    });

    try {
      final postProvider = context.read<PostProvider>();
      final hasReaction = widget.post.hasReaction(emoji, currentUser.id);
      
      bool success;
      if (hasReaction) {
        success = await postProvider.removeReaction(widget.post.id, emoji, currentUser.id);
      } else {
        success = await postProvider.addReaction(widget.post.id, emoji, currentUser.id);
      }

      if (success) {
        // ローカル状態を更新
        final newReactions = Map<String, List<String>>.from(widget.post.reactions);
        
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

        final updatedPost = widget.post.copyWith(reactions: newReactions);
        postProvider.updatePostInLists(updatedPost);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postProvider.errorMessage ?? 'リアクションの更新に失敗しました')),
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
        _isProcessingLike = false;
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

    final postProvider = context.read<PostProvider>();
    final isLiked = widget.post.isLikedBy(currentUser.id);

    try {
      bool success;
      if (isLiked) {
        success = await postProvider.unlikePost(widget.post.id, currentUser.id);
      } else {
        success = await postProvider.likePost(widget.post.id, currentUser.id);
      }

      if (success) {
        // 成功時にローカルの投稿データを安全に更新
        final newLikeCount = isLiked
            ? (widget.post.likeCount > 0
                ? widget.post.likeCount - 1
                : 0) // マイナスにならないように制御
            : widget.post.likeCount + 1;

        final newLikedByUserIds = isLiked
            ? widget.post.likedByUserIds
                .where((id) => id != currentUser.id)
                .toList()
            : [...widget.post.likedByUserIds, currentUser.id];

        final updatedPost = widget.post.copyWith(
          likeCount: newLikeCount,
          likedByUserIds: newLikedByUserIds,
        );

        // PostProviderの各リストを更新
        postProvider.updatePostInLists(updatedPost);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postProvider.errorMessage ?? 'エラーが発生しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  // 進行期間を日単位で表示するヘルパーメソッド
  String _formatScheduledDuration(PostModel post) {
    if (post.scheduledEndTime == null) return '予定なし';

    final duration = post.scheduledEndTime!.difference(post.createdAt);
    final days = duration.inDays;
    final hours = duration.inHours % 24;

    if (days > 0) {
      return '${days}日';
    } else if (hours > 0) {
      return '${hours}時間';
    } else {
      return '1日未満';
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
