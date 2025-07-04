import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../utils/date_time_utils.dart';

class PostCardWidget extends StatelessWidget {
  final PostModel post;

  const PostCardWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.smallPadding,
        vertical: AppConstants.smallPadding / 2,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
          ),

          // 画像（START投稿は1枚、END投稿は2枚）
          if (post.imageUrl != null) _buildImageSection(),

          // コンテンツ
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // タイトル
                Text(
                  post.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                // コメント
                if (post.comment != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.comment!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],

                // 時刻情報
                _buildTimeInfo(context),
              ],
            ),
          ),

          // アクション（いいね、コメント）
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
              vertical: AppConstants.smallPadding,
            ),
            child: Row(
              children: [
                // いいねボタン
                InkWell(
                  onTap: () {
                    // TODO: いいね機能の実装
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 20,
                          color: post.isLikedBy(
                            'current_user_id',
                          ) // TODO: 現在のユーザーIDを取得
                              ? AppColors.flame
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.likeCount.toString(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // END投稿ボタン（START投稿の場合のみ）
                if (post.type == PostType.start && !post.isCompleted)
                  TextButton.icon(
                    onPressed: () {
                      // TODO: END投稿作成画面への遷移
                    },
                    icon: const Icon(Icons.flag, size: 16),
                    label: const Text('END投稿'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    if (post.type == PostType.start && post.endPostId != null) {
      // START投稿でEND投稿がある場合は2枚画像表示
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Row(
          children: [
            // START画像（左側）
            Expanded(
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.error, color: AppColors.error),
                ),
              ),
            ),
            // 区切り線
            Container(width: 2, color: AppColors.divider),
            // END画像（右側）- TODO: END投稿の画像を取得
            Expanded(
              child: Container(
                color: AppColors.surfaceVariant,
                child: const Center(
                  child: Icon(Icons.flag, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 通常の1枚画像表示
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: CachedNetworkImage(
          imageUrl: post.imageUrl!,
          fit: BoxFit.cover,
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
    }
  }

  Widget _buildTimeInfo(BuildContext context) {
    if (post.type == PostType.start) {
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
                            : AppColors.textSecondary,
                      ),
                ),
              ],
            ),
        ],
      );
    } else {
      // END投稿の場合
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag, size: 16, color: AppColors.completed),
              const SizedBox(width: 4),
              Text(
                '完了: ${DateTimeUtils.formatDateTime(post.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildStatusChip() {
    Color chipColor;
    String chipText;

    switch (post.status) {
      case PostStatus.concentration:
        chipColor = AppColors.concentration;
        chipText = '集中';
        break;
      case PostStatus.inProgress:
        chipColor = AppColors.inProgress;
        chipText = '進行中';
        break;
      case PostStatus.completed:
        chipColor = AppColors.completed;
        chipText = '完了';
        break;
      case PostStatus.overdue:
        chipColor = AppColors.error;
        chipText = '期限切れ';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        chipText,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
