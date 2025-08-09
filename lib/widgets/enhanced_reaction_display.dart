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

class EnhancedReactionDisplay extends StatelessWidget {
  final PostModel post;
  final String? currentUserId;
  final Function(String emoji) onReactionTap;
  final VoidCallback onAddReaction;
  final int maxDisplayed;
  final double emojiSize;
  final bool showAddButton;

  const EnhancedReactionDisplay({
    super.key,
    required this.post,
    this.currentUserId,
    required this.onReactionTap,
    required this.onAddReaction,
    this.maxDisplayed = 5,
    this.emojiSize = 18,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final reactions = post.reactions;
    
    // リアクション数でソート（カウントが0のものは除外）
    final sortedReactions = reactions.entries
        .where((entry) => entry.value.isNotEmpty) // カウント0のリアクションを除外
        .toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    if (sortedReactions.isEmpty && showAddButton) {
      return _buildAddButton(context);
    }

    // 表示するリアクションを制限
    final displayedReactions = sortedReactions.take(maxDisplayed).toList();
    
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200), // 最大高さ制限
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // リアクションボタン（カウントが0でないもののみ）
              ...displayedReactions.map((entry) {
                final emoji = entry.key;
                final userIds = entry.value;
                final count = userIds.length;
                final isReactedByUser = currentUserId != null && userIds.contains(currentUserId);
                
                // カウントが0の場合は表示しない（念のため再チェック）
                if (count == 0) return const SizedBox.shrink();
                
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
              if (showAddButton) _buildAddButton(context),
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
        constraints: const BoxConstraints(
          minWidth: 50,
          maxWidth: 120, // 最大幅制限
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textHint.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 絵文字を少し大きく、鮮明に表示
            Text(
              emoji,
              style: TextStyle(
                fontSize: emojiSize,
                fontFamily: 'NotoColorEmoji', // より良い絵文字レンダリング
              ),
            ),
            const SizedBox(width: 5),
            // カウントのスタイリング強化
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatReactionCount(count), // 短縮表示を使用
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis, // テキスト溢れ対策
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreIndicator(BuildContext context, int hiddenCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textHint.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.more_horiz,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 3),
          Text(
            '+${_formatReactionCount(hiddenCount)}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: onAddReaction,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              AppColors.primary.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.add,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '😊',
              style: TextStyle(
                fontSize: emojiSize - 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 詳細なリアクション情報を表示するダイアログ
class ReactionDetailsDialog extends StatelessWidget {
  final PostModel post;
  final String emoji;

  const ReactionDetailsDialog({
    super.key,
    required this.post,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final userIds = post.reactions[emoji] ?? [];
    
    return AlertDialog(
      title: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 8),
          Text(
            'リアクションした人 (${userIds.length})',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 200,
        child: ListView.builder(
          itemCount: userIds.length,
          itemBuilder: (context, index) {
            final userId = userIds[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(userId.substring(0, 2).toUpperCase()),
              ),
              title: Text('ユーザー $userId'),
              dense: true,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

// リアクション詳細を表示する関数
void showReactionDetails(BuildContext context, PostModel post, String emoji) {
  showDialog(
    context: context,
    builder: (context) => ReactionDetailsDialog(
      post: post,
      emoji: emoji,
    ),
  );
}
