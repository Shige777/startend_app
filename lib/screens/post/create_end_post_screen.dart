import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';

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
  final String? communityId; // コミュニティIDを追加

  const CreateEndPostScreen({
    super.key,
    required this.startPostId,
    required this.startPost,
    this.communityId, // コミュニティIDを追加
  });

  @override
  State<CreateEndPostScreen> createState() => _CreateEndPostScreenState();
}

class _CreateEndPostScreenState extends State<CreateEndPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  bool _isLoading = false;
  DateTime? _actualEndTime;

  @override
  void initState() {
    super.initState();
    // デフォルトで現在時刻を設定
    _actualEndTime = DateTime.now();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    '投稿',
                    style: TextStyle(color: Colors.black),
                  ),
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
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'START投稿',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
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
                              const Icon(Icons.schedule,
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

              // 実際の終了時刻の設定
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '実際に終了した時刻',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _selectEndTime,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                _actualEndTime != null
                                    ? _formatDateTime(_actualEndTime!)
                                    : '終了時刻を選択',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down,
                                  color: AppColors.textSecondary),
                            ],
                          ),
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
                  labelText: '完了コメント（任意）',
                  hintText: '目標を達成した感想や学んだことを書いてください（任意）',
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 4,
                maxLength: 500,
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

  Future<void> _selectEndTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _actualEndTime ?? DateTime.now(),
      firstDate: widget.startPost.createdAt,
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_actualEndTime ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _actualEndTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createEndPost() async {
    // 画像が選択されているかチェック
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像を選択してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final postProvider = context.read<PostProvider>();

      if (userProvider.currentUser == null) {
        throw Exception('ユーザー情報が取得できません');
      }

      // 画像をFirebase Storageにアップロード
      String? imageUrl;

      if (_selectedImageBytes != null) {
        imageUrl = await StorageService.uploadPostImageFromBytes(
          bytes: _selectedImageBytes!,
          userId: userProvider.currentUser!.id,
          postId: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: _selectedImageFileName ?? 'image.jpg',
        );
      }

      if (imageUrl == null) {
        throw Exception('画像のアップロードに失敗しました');
      }

      // コミュニティ内で直接END投稿を作成する場合
      if (widget.communityId != null && widget.startPostId == 'dummy') {
        final endPost = PostModel(
          id: '', // Firestoreで自動生成
          userId: userProvider.currentUser!.id,
          type: PostType.end,
          title: 'コミュニティ投稿',
          imageUrl: imageUrl,
          endImageUrl: imageUrl,
          endComment: _commentController.text.trim(),
          actualEndTime: _actualEndTime,
          privacyLevel: PrivacyLevel.public,
          communityIds: [widget.communityId!],
          likedByUserIds: [],
          likeCount: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final success = await postProvider.createPost(endPost);

        if (success != null) {
          // ユーザー情報を更新（投稿数を含む）
          await userProvider.refreshCurrentUser();

          if (mounted) {
            // コミュニティ画面に戻る
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/community/${widget.communityId}');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('END投稿を作成しました'),
                backgroundColor: Colors.black,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(postProvider.errorMessage ?? '投稿の作成に失敗しました'),
              ),
            );
          }
        }
        return;
      }

      // 通常のEND投稿作成（既存のSTART投稿に対して）
      final endPost = PostModel(
        id: '', // Firestoreで自動生成
        userId: userProvider.currentUser!.id,
        type: PostType.end,
        title: widget.startPost.title,
        imageUrl: widget.startPost.imageUrl,
        endImageUrl: imageUrl,
        endComment: _commentController.text.trim(),
        actualEndTime: _actualEndTime,
        privacyLevel: widget.startPost.privacyLevel,
        communityIds: widget.startPost.communityIds,
        likedByUserIds: [],
        likeCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await postProvider.createPost(endPost);

      if (success != null) {
        // 元のSTART投稿を削除
        await postProvider.deleteStartPost(widget.startPostId);

        // ユーザー情報を更新（投稿数を含む）
        await userProvider.refreshCurrentUser();

        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('END投稿を作成しました'),
              backgroundColor: Colors.black,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(postProvider.errorMessage ?? '投稿の作成に失敗しました'),
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
