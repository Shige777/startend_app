import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/post_model.dart';

// リアクション数の短縮表示用ヘルパー関数
String _formatReactionCount(int count) {
  if (count < 1000) {
    return count.toString();
  } else if (count < 1000000) {
    final k = count / 1000;
    return k >= 100 ? '${k.round()}K' : '${k.toStringAsFixed(1).replaceAll('.0', '')}K';
  } else {
    final m = count / 1000000;
    return m >= 100 ? '${m.round()}M' : '${m.toStringAsFixed(1).replaceAll('.0', '')}M';
  }
}

class ReactionDisplay extends StatelessWidget {
  final PostModel post;
  final String? currentUserId;
  final Function(String emoji) onReactionTap;
  final VoidCallback onAddReaction;
  final int maxDisplayed;

  const ReactionDisplay({
    super.key,
    required this.post,
    this.currentUserId,
    required this.onReactionTap,
    required this.onAddReaction,
    this.maxDisplayed = 5,
  });

  @override
  Widget build(BuildContext context) {
    final reactions = post.reactions;
    
    if (reactions.isEmpty) {
      return _buildAddButton(context);
    }

    // リアクション数でソート
    final sortedReactions = reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // 表示するリアクションを制限
    final displayedReactions = sortedReactions.take(maxDisplayed).toList();
    
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150), // 最大高さ制限
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
        // リアクションボタン
        ...displayedReactions.map((entry) {
          final emoji = entry.key;
          final userIds = entry.value;
          final count = userIds.length;
          final isReactedByUser = currentUserId != null && userIds.contains(currentUserId);
          
          return _buildReactionChip(
            context,
            emoji,
            count,
            isReactedByUser,
            () => onReactionTap(emoji),
          );
        }),
        
        // 追加のリアクションがある場合の表示
        if (sortedReactions.length > maxDisplayed)
          _buildMoreIndicator(context, sortedReactions.length - maxDisplayed),
        
        // 追加ボタン
        _buildAddButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionChip(
    BuildContext context,
    String emoji,
    int count,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textHint.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 4),
            Text(
              _formatReactionCount(count), // 短縮表示を使用
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreIndicator(BuildContext context, int hiddenCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textHint.withOpacity(0.3),
        ),
      ),
      child: Text(
        '+$hiddenCount',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: onAddReaction,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textHint.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.sentiment_satisfied_alt_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ハートアイコン表示（従来のいいね機能との併用）
class LikeButton extends StatelessWidget {
  final PostModel post;
  final String? currentUserId;
  final VoidCallback onTap;
  final bool isLoading;

  const LikeButton({
    super.key,
    required this.post,
    this.currentUserId,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = currentUserId != null && post.isLikedBy(currentUserId!);
    
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isLiked
              ? AppColors.flame.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(isLiked),
                color: isLiked ? AppColors.flame : AppColors.textSecondary,
                size: 18,
              ),
            ),
            if (post.likeCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                post.likeCount.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: isLiked ? AppColors.flame : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
