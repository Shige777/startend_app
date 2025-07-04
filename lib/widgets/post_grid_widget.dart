import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../constants/app_colors.dart';

class PostGridWidget extends StatelessWidget {
  final List<PostModel> posts;

  const PostGridWidget({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return _buildGridItem(context, posts[index]);
      },
    );
  }

  Widget _buildGridItem(BuildContext context, PostModel post) {
    return GestureDetector(
      onTap: () {
        // TODO: 投稿詳細画面への遷移
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 背景画像
              if (post.imageUrl != null)
                CachedNetworkImage(
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
                )
              else
                Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(
                    Icons.image,
                    size: 48,
                    color: AppColors.textHint,
                  ),
                ),

              // オーバーレイ
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),

              // ステータスチップ
              Positioned(top: 8, right: 8, child: _buildStatusChip(post)),

              // タイトル
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  post.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(PostModel post) {
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        chipText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
