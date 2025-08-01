import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:provider/provider.dart';

import 'package:go_router/go_router.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/post_model.dart';
import '../../utils/date_time_utils.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/platform_image_picker.dart';

class CreatePostScreen extends StatefulWidget {
  final String? communityId;

  const CreatePostScreen({super.key, this.communityId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();

  DateTime? _selectedDateTime;

  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
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
        title: Text(widget.communityId != null ? 'コミュニティ投稿' : 'START投稿'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSubmit,
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
              // 画像選択
              PlatformImagePicker(
                height: 200,
                placeholder: '画像を選択してください',
                onImageSelected: (bytes, fileName) {
                  setState(() {
                    _selectedImageBytes = bytes;
                    _selectedImageFileName = fileName;
                  });
                },
              ),
              const SizedBox(height: 24),

              // タイトル入力
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル（任意）',
                  hintText: '何を始めますか？（任意）',
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: AppConstants.maxTitleLength,
              ),
              const SizedBox(height: 16),

              // 完了予定時刻選択
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: Colors.black),
                          const SizedBox(width: 8),
                          const Text(
                            '完了予定時刻（任意）',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 現在の選択状態を表示
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedDateTime != null
                                  ? DateTimeUtils.formatDateTime(
                                      _selectedDateTime!)
                                  : '未設定',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_selectedDateTime != null) ...[
                              const SizedBox(height: 4),
                              Builder(
                                builder: (context) {
                                  final now = DateTime.now();
                                  final duration =
                                      _selectedDateTime!.difference(now);

                                  if (duration.isNegative) {
                                    return const Text(
                                      '⚠️ 過去の時刻です',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                      ),
                                    );
                                  }

                                  final hours = duration.inHours;
                                  final minutes = duration.inMinutes % 60;
                                  final durationText = hours > 0
                                      ? '$hours時間${minutes > 0 ? '$minutes分' : ''}'
                                      : '${minutes}分';

                                  // 2時間を超える場合は警告表示
                                  if (duration.inMinutes > 120) {
                                    return Text(
                                      '⚠️ 集中時間が長すぎます（$durationText）',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                      ),
                                    );
                                  }

                                  return Text(
                                    '集中時間: $durationText',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 時刻設定ボタン
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectDateTime,
                          icon: const Icon(Icons.schedule, size: 16),
                          label: const Text('時刻を設定'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 投稿ボタン
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textOnPrimary,
                          ),
                        ),
                      )
                    : const Text('START投稿を作成'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    // 画像が選択されているかチェック
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('画像を選択してください')));
      return;
    }

    // 完了予定時刻が設定されている場合のみバリデーション
    if (_selectedDateTime != null) {
      // 集中時間の制限チェック
      final now = DateTime.now();
      final duration = _selectedDateTime!.difference(now);

      if (duration.isNegative) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('完了予定時刻は現在時刻より後に設定してください'),
            backgroundColor: Colors.black,
          ),
        );
        return;
      }

      // 最大集中時間を2時間（120分）に制限
      const maxDurationMinutes = 120;
      if (duration.inMinutes > maxDurationMinutes) {
        final hours = maxDurationMinutes ~/ 60;
        final minutes = maxDurationMinutes % 60;
        final maxDurationText = hours > 0
            ? '$hours時間${minutes > 0 ? '$minutes分' : ''}'
            : '${minutes}分';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('集中時間は最大$maxDurationTextまでです'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
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
        // バイトデータからアップロード（Web・モバイル共通）
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

      final post = PostModel(
        id: '', // Firestoreで自動生成
        userId: userProvider.currentUser!.id,
        type: PostType.start,
        title: _titleController.text.trim(),
        imageUrl: imageUrl,
        scheduledEndTime: _selectedDateTime,
        privacyLevel: PrivacyLevel.public,
        communityIds: widget.communityId != null ? [widget.communityId!] : [],
        likedByUserIds: [],
        likeCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (kDebugMode) {
        print('投稿作成開始: ${post.title}');
        print('ユーザーID: ${post.userId}');
        print('投稿タイプ: ${post.type}');
        print('コミュニティID: ${post.communityIds}');
      }

      final success = await postProvider.createPost(post);

      if (success != null) {
        if (kDebugMode) {
          print('投稿作成成功');
        }

        // 終了予定時刻が設定されている場合は通知をスケジュール
        if (_selectedDateTime != null) {
          await NotificationService().scheduleReminderNotification(
            postId: success,
            title: post.title,
            scheduledTime: _selectedDateTime!,
            userId: userProvider.currentUser!.id,
          );
        }

        // 投稿作成後にユーザーの投稿一覧を更新
        await postProvider.getUserPosts(userProvider.currentUser!.id,
            currentUserId: userProvider.currentUser!.id);

        // ユーザー情報を更新（投稿数を含む）
        await userProvider.refreshCurrentUser();

        if (mounted) {
          if (widget.communityId != null) {
            // コミュニティ投稿の場合は、コミュニティ画面に戻る
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/community/${widget.communityId}');
            }
          } else {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('投稿を作成しました')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
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
