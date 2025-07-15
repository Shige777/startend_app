import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../constants/app_colors.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';

class PostGridWidget extends StatelessWidget {
  final List<PostModel> posts;
  final String? periodLabel;

  const PostGridWidget({super.key, required this.posts, this.periodLabel});

  // 画像URLがネットワークURLかローカルファイルパスかを判別
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // 画像を表示するWidgetを構築
  Widget _buildImageWidget(String? imageUrl, {BoxFit fit = BoxFit.cover}) {
    if (imageUrl == null) {
      return Container(
        color: AppColors.surfaceVariant,
        child: const Icon(
          Icons.image,
          size: 32,
          color: AppColors.textHint,
        ),
      );
    }

    if (_isNetworkUrl(imageUrl)) {
      // ネットワーク画像
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        placeholder: (context, url) => Container(
          color: AppColors.surfaceVariant,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.surfaceVariant,
          child: const Icon(Icons.error, color: AppColors.error),
        ),
      );
    } else {
      // ローカルファイル
      if (kIsWeb) {
        // Webの場合はエラー画像を表示
        return Container(
          color: AppColors.surfaceVariant,
          child: const Icon(Icons.error, color: AppColors.error),
        );
      } else {
        // モバイルの場合はFile.imageを使用
        try {
          return Image.file(
            File(imageUrl),
            fit: fit,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.error, color: AppColors.error),
            ),
          );
        } catch (e) {
          return Container(
            color: AppColors.surfaceVariant,
            child: const Icon(Icons.error, color: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 期間ラベル表示
        if (periodLabel != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              periodLabel!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
        // グリッド表示
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 0,
              mainAxisSpacing: 0,
              childAspectRatio: 1,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return _buildGridItem(context, posts[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(BuildContext context, PostModel post) {
    return GestureDetector(
      onTap: () {
        context.push('/post/${post.id}', extra: {
          'post': post,
          'fromPage': 'profile', // 軌跡画面から来たことを識別
        });
      },
      onLongPress: () {
        if (_canDeletePost(context, post)) {
          _showDeleteConfirmation(context, post);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 2枚画像表示（常に左側START、右側END）
          Row(
            children: [
              // 左側：START投稿画像
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: _buildImageWidget(post.imageUrl),
                ),
              ),
              // 右側：END投稿画像 or プレースホルダー
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: post.isCompleted
                      ? (post.endImageUrl != null
                          ? _buildImageWidget(post.endImageUrl)
                          : Container(
                              color: AppColors.surfaceVariant,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate,
                                        color: AppColors.textSecondary,
                                        size: 24),
                                    SizedBox(height: 4),
                                    Text('END',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                            ))
                      : Container(
                          color: AppColors.surfaceVariant.withOpacity(0.8),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate,
                                    color: AppColors.textSecondary, size: 24),
                                SizedBox(height: 4),
                                Text('END',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 投稿削除権限があるかチェック
  bool _canDeletePost(BuildContext context, PostModel post) {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    return currentUser != null && post.userId == currentUser.id;
  }

  // 削除確認ダイアログを表示
  void _showDeleteConfirmation(BuildContext context, PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿削除'),
        content: const Text('この投稿を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePost(context, post);
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
  Future<void> _deletePost(BuildContext context, PostModel post) async {
    final postProvider = context.read<PostProvider>();

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await postProvider.deletePost(post.id);

      if (context.mounted) {
        Navigator.of(context).pop(); // ローディング終了

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿を削除しました')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿の削除に失敗しました')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // ローディング終了
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }
}
