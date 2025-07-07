import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/post_model.dart';
import '../../services/storage_service.dart';
import '../../widgets/platform_image_picker.dart';

class CreateEndPostScreen extends StatefulWidget {
  final String startPostId;
  final PostModel startPost;

  const CreateEndPostScreen({
    super.key,
    required this.startPostId,
    required this.startPost,
  });

  @override
  State<CreateEndPostScreen> createState() => _CreateEndPostScreenState();
}

class _CreateEndPostScreenState extends State<CreateEndPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  String? _selectedImagePath;
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('END投稿'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createEndPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('投稿'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // START投稿の情報
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.play_arrow,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'START投稿',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.startPost.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.startPost.comment != null)
                        Text(
                          widget.startPost.comment!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '開始: ${_formatDateTime(widget.startPost.createdAt)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                      if (widget.startPost.scheduledEndTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.flag,
                                  size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '予定: ${_formatDateTime(widget.startPost.scheduledEndTime!)}',
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // END投稿の内容
              Text(
                'END投稿の内容',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // 完了時の画像
              PlatformImagePicker(
                height: 200,
                placeholder: '完了時の画像を追加',
                onImageSelected: (bytes, fileName) {
                  setState(() {
                    _selectedImageBytes = bytes;
                    _selectedImageFileName = fileName;
                  });
                },
              ),
              const SizedBox(height: 16),

              // コメント
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: '完了コメント',
                  hintText: '目標を達成した感想や学んだことを書いてください',
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 4,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '完了コメントを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 実際にかかった時間の表示
              Card(
                color: AppColors.completed.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer, color: AppColors.completed),
                          const SizedBox(width: 8),
                          Text(
                            '実際にかかった時間',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.completed,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getElapsedTime(),
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.completed,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getElapsedTime() {
    final elapsed = DateTime.now().difference(widget.startPost.createdAt);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;

    if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
  }

  Future<void> _createEndPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final postProvider = context.read<PostProvider>();

      final currentUser = userProvider.currentUser;
      if (currentUser == null) {
        throw Exception('ユーザー情報が取得できません');
      }

      // 画像をFirebase Storageにアップロード
      String? imageUrl;

      if (_selectedImageBytes != null) {
        // バイトデータからアップロード（Web・モバイル共通）
        imageUrl = await StorageService.uploadPostImageFromBytes(
          bytes: _selectedImageBytes!,
          userId: currentUser.id,
          postId: widget.startPostId,
          fileName: _selectedImageFileName ?? 'end_image.jpg',
        );
      }

      if (imageUrl == null && _selectedImageBytes != null) {
        throw Exception('画像のアップロードに失敗しました');
      }

      final success = await postProvider.createEndPost(
        widget.startPostId,
        _commentController.text.trim(),
        imageUrl,
      );

      if (success != null) {
        if (mounted) {
          // START投稿がコミュニティ投稿の場合は、コミュニティ画面に戻る
          if (widget.startPost.communityIds.isNotEmpty) {
            context.go('/community/${widget.startPost.communityIds.first}');
          } else {
            // より安全なナビゲーション処理
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('END投稿を作成しました！')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(postProvider.errorMessage ?? 'END投稿の作成に失敗しました'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
