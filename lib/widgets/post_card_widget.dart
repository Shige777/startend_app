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

class PostCardWidget extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final bool showActions;
  final VoidCallback? onDelete;

  const PostCardWidget({
    super.key,
    required this.post,
    this.onTap,
    this.showActions = true,
    this.onDelete,
  });

  // 画像URLがネットワークURLかローカルファイルパスかを判別
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // 画像を表示するWidgetを構築
  Widget _buildImageWidget(String? imageUrl, {BoxFit fit = BoxFit.cover}) {
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

    if (_isNetworkUrl(imageUrl)) {
      // ネットワーク画像
      return Container(
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
            child: const Icon(Icons.error, color: AppColors.error),
          ),
        ),
      );
    } else {
      // ローカルファイル
      if (kIsWeb) {
        // Webの場合はエラー画像を表示
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.surfaceVariant,
          child: const Icon(Icons.error, color: AppColors.error),
        );
      } else {
        // モバイルの場合はFile.imageを使用
        try {
          return Container(
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
          );
        } catch (e) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.surfaceVariant,
            child: const Icon(Icons.error, color: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppConstants.smallPadding / 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(0), // ボーダーレス
      ),
      child: InkWell(
        onTap: onTap ?? () => context.go('/post/${post.id}', extra: post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー（ユーザー情報）
            Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Row(
                children: [
                  const CircleAvatar(radius: 20, child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ユーザー名', // TODO: 実際のユーザー名を取得
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          DateTimeUtils.getRelativeTime(post.createdAt),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // _buildStatusChip(), // 完了文字を削除
                ],
              ),
            ),

            // 画像（START投稿は常に2枚表示：左側START、右側END）
            _buildImageSection(context),

            // コンテンツ
            Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // START投稿のコメント
                  if (post.comment != null) ...[
                    Text(
                      post.comment!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),

            // END投稿のコメント（完了している場合）- 画像の下に表示
            if (post.isCompleted && post.endComment != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.completed.withOpacity(0.1),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.completed.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Text(
                  post.endComment!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.completed,
                      ),
                ),
              ),
            ],

            // アクション（いいね、コメント）
            if (showActions)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                  vertical: AppConstants.smallPadding,
                ),
                child: Row(
                  children: [
                    // いいねボタン
                    Consumer<UserProvider>(
                      builder: (context, userProvider, _) {
                        final currentUser = userProvider.currentUser;
                        final isLiked = currentUser != null &&
                            post.isLikedBy(currentUser.id);

                        return InkWell(
                          onTap: () => _toggleLike(context, currentUser),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  size: 20,
                                  color: isLiked
                                      ? AppColors.flame
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  post.likeCount.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(),

                    // 投稿者本人の場合のみ削除ボタンを表示
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 16),
                        onPressed: onDelete,
                        color: AppColors.error,
                      ),

                    // END投稿ボタン（START投稿の場合のみ）
                    if (post.type == PostType.start && !post.isCompleted)
                      TextButton.icon(
                        onPressed: () {
                          // END投稿作成画面への遷移
                          context.go('/create-end-post', extra: {
                            'startPostId': post.id,
                            'startPost': post,
                          });
                        },
                        icon: const Icon(Icons.flag, size: 16),
                        label: const Text('END投稿'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Container(
      height: 280, // 高さを調整（タイトルとラベル分を追加）
      child: Column(
        children: [
          // タイトル
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.surface,
            child: Text(
              post.title,
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
                        child: _buildImageWidget(post.imageUrl),
                      ),
                      // START画像の下にラベル
                      Container(
                        width: double.infinity,
                        height: 28, // 固定高さ
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: AppColors.surface,
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '開始: ${DateTimeUtils.formatDateTime(post.createdAt)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
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
                // 区切り線
                Container(width: 2, color: AppColors.divider),
                // END画像（右側）
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) => GestureDetector(
                            onTap: post.isCompleted
                                ? null
                                : () {
                                    // END投稿作成画面への遷移
                                    context.go('/create-end-post', extra: {
                                      'startPostId': post.id,
                                      'startPost': post,
                                    });
                                  },
                            child: Container(
                              width: double.infinity,
                              color: AppColors.surfaceVariant,
                              child: post.isCompleted
                                  ? (post.endImageUrl != null
                                      ? _buildImageWidget(post.endImageUrl)
                                      : const Center(
                                          child: Icon(Icons.flag,
                                              color: AppColors.completed,
                                              size: 32),
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
                        height: 28, // 固定高さ
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: AppColors.surface,
                        child: post.scheduledEndTime != null
                            ? Row(
                                children: [
                                  Icon(
                                    post.isCompleted
                                        ? Icons.flag
                                        : Icons.schedule,
                                    size: 16,
                                    color: post.isOverdue
                                        ? AppColors.error
                                        : post.isCompleted
                                            ? AppColors.completed
                                            : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      post.isCompleted
                                          ? '完了: ${DateTimeUtils.formatDateTime(post.actualEndTime ?? post.scheduledEndTime!)}'
                                          : '予定: ${DateTimeUtils.formatDateTime(post.scheduledEndTime!)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: post.isOverdue
                                                ? AppColors.error
                                                : post.isCompleted
                                                    ? AppColors.completed
                                                    : AppColors.textSecondary,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox(height: 20), // 空のスペース
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
              '開始: ${DateTimeUtils.formatDateTime(post.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 完了予定時刻 or 完了時刻
        if (post.scheduledEndTime != null)
          Row(
            children: [
              Icon(
                post.isCompleted ? Icons.flag : Icons.schedule,
                size: 16,
                color: post.isOverdue
                    ? AppColors.error
                    : post.isCompleted
                        ? AppColors.completed
                        : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                post.isCompleted
                    ? '完了: ${DateTimeUtils.formatDateTime(post.actualEndTime ?? post.scheduledEndTime!)}'
                    : '予定: ${DateTimeUtils.formatDateTime(post.scheduledEndTime!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: post.isOverdue
                          ? AppColors.error
                          : post.isCompleted
                              ? AppColors.completed
                              : AppColors.textSecondary,
                    ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatusChip() {
    Color chipColor;
    Widget chipContent;

    switch (post.status) {
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

  void _toggleLike(BuildContext context, UserModel? currentUser) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    final postProvider = context.read<PostProvider>();
    final isLiked = post.isLikedBy(currentUser.id);

    try {
      bool success;
      if (isLiked) {
        success = await postProvider.unlikePost(post.id, currentUser.id);
      } else {
        success = await postProvider.likePost(post.id, currentUser.id);
      }

      if (!success) {
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
}
