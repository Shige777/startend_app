import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../constants/app_colors.dart';
import '../generated/l10n/app_localizations.dart';

class AdvancedReactionPicker extends StatefulWidget {
  final Function(String emoji) onReactionSelected;

  const AdvancedReactionPicker({
    super.key,
    required this.onReactionSelected,
  });

  @override
  State<AdvancedReactionPicker> createState() => _AdvancedReactionPickerState();
}

class _AdvancedReactionPickerState extends State<AdvancedReactionPicker> {
  
  // カテゴリ別の人気絵文字
  static const Map<String, List<String>> categoryEmojis = {
    '人気': [
      '👍', '❤️', '😊', '😂', '🔥', '💯', '👏', '🎉',
      '😍', '🤔', '👀', '💪', '🚀', '✨', '🙏', '⚡',
    ],
    '感情': [
      '😀', '😃', '😄', '😁', '😆', '😂', '🤣', '😭',
      '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
      '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
      '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏',
    ],
    '反応': [
      '😮', '😯', '😲', '😳', '🥺', '😢', '😰', '😱',
      '🤯', '😤', '😠', '😡', '🤬', '😈', '👿', '💀',
      '☠️', '💩', '🤡', '👹', '👺', '👻', '👽', '🤖',
    ],
    'ジェスチャー': [
      '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤏', '✌️',
      '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕',
      '👇', '☝️', '👍', '👎', '👊', '✊', '🤛', '🤜',
      '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💪',
    ],
    'オブジェクト': [
      '🎯', '🏆', '🏅', '🥇', '🥈', '🥉', '🏵️', '🎖️',
      '💎', '💍', '👑', '🔥', '💡', '⭐', '🌟', '✨',
      '💫', '⚡', '🌈', '☀️', '🌙', '⭐', '🌍', '🚀',
      '🎈', '🎉', '🎊', '🎁', '🏁', '🚩', '💝', '💖',
    ],
    'アクティビティ': [
      '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉',
      '🥅', '🏸', '🏓', '🏒', '🏑', '🥍', '🏏', '🪃',
      '🥊', '🥋', '🎪', '🎭', '🎨', '🎬', '🎤', '🎧',
      '🎼', '🎵', '🎶', '🎯', '🎲', '🎮', '🕹️', '🎰',
    ],
  };

  String selectedCategory = '人気';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              Text(
                'リアクションを選択',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                iconSize: 24,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // カテゴリタブ
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: categoryEmojis.keys.map((category) {
                final isSelected = category == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textHint.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 絵文字グリッド
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: categoryEmojis[selectedCategory]?.length ?? 0,
              itemBuilder: (context, index) {
                final emoji = categoryEmojis[selectedCategory]![index];
                return _buildEmojiButton(emoji);
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // フル絵文字ピッカーボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showFullEmojiPicker(context),
              icon: const Icon(Icons.emoji_emotions),
              label: const Text('すべての絵文字を見る'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppColors.textHint.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiButton(String emoji) {
    return GestureDetector(
      onTap: () {
        widget.onReactionSelected(emoji);
        Navigator.of(context).pop();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.textHint.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(
              fontSize: 28,
            ),
          ),
        ),
      ),
    );
  }

  void _showFullEmojiPicker(BuildContext context) {
    Navigator.of(context).pop(); // 現在のピッカーを閉じる
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ヘッダー
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.allEmojis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // フル絵文字ピッカー
            Expanded(
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  widget.onReactionSelected(emoji.emoji);
                  Navigator.of(context).pop();
                },
                config: Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: Colors.white,
                    columns: 7,
                    emojiSizeMax: 32,
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    gridPadding: EdgeInsets.zero,
                    recentsLimit: 28,
                    replaceEmojiOnLimitExceed: false,
                    noRecents: Text(
                      AppLocalizations.of(context)!.recentEmojis,
                      style: const TextStyle(fontSize: 20, color: Colors.black26),
                      textAlign: TextAlign.center,
                    ),
                    loadingIndicator: const SizedBox.shrink(),
                    buttonMode: ButtonMode.MATERIAL,
                  ),
                  skinToneConfig: const SkinToneConfig(
                    enabled: true,
                    dialogBackgroundColor: Colors.white,
                    indicatorColor: Colors.grey,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    initCategory: Category.RECENT,
                    backgroundColor: const Color(0xFFF2F2F2),
                    indicatorColor: AppColors.primary,
                    iconColor: Colors.grey,
                    iconColorSelected: AppColors.primary,
                    backspaceColor: AppColors.primary,
                    tabIndicatorAnimDuration: kTabScrollDuration,
                    categoryIcons: const CategoryIcons(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 高機能リアクションピッカーを表示する関数
void showAdvancedReactionPicker(BuildContext context, Function(String emoji) onReactionSelected) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AdvancedReactionPicker(
      onReactionSelected: onReactionSelected,
    ),
  );
}
