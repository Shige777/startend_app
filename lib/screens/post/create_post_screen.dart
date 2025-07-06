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
import '../../utils/date_time_utils.dart';
import '../../services/storage_service.dart';
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
  String? _selectedImagePath;
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  PrivacyLevel _selectedPrivacyLevel = PrivacyLevel.public;
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.communityId != null ? 'コミュニティ投稿' : 'START投稿'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSubmit,
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
              // 画像選択
              PlatformImagePicker(
                height: 200,
                placeholder: '画像を選択してください',
                onImageSelected: (bytes, fileName) {
                  setState(() {
                    _selectedImageBytes = bytes;
                    _selectedImageFileName = fileName;
                    // モバイル環境では従来のパスも保持
                    if (!kIsWeb) {
                      _selectedImagePath = fileName;
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // タイトル入力
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  hintText: '何を始めますか？',
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: AppConstants.maxTitleLength,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 完了予定時刻選択
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('完了予定時刻'),
                subtitle: Text(
                  _selectedDateTime != null
                      ? DateTimeUtils.formatDateTime(_selectedDateTime!)
                      : '設定してください',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectDateTime,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                  side: const BorderSide(color: AppColors.divider),
                ),
              ),
              const SizedBox(height: 16),

              // 公開範囲選択
              DropdownButtonFormField<PrivacyLevel>(
                value: _selectedPrivacyLevel,
                decoration: const InputDecoration(
                  labelText: '公開範囲',
                  prefixIcon: Icon(Icons.visibility),
                ),
                items: PrivacyLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(_getPrivacyLevelText(level)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPrivacyLevel = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // 投稿ボタン
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
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

  String _getPrivacyLevelText(PrivacyLevel level) {
    switch (level) {
      case PrivacyLevel.public:
        return '全体公開';
      case PrivacyLevel.mutualFollowersOnly:
        return '相互フォローのみ';
      case PrivacyLevel.communityOnly:
        return 'コミュニティのみ';
      case PrivacyLevel.mutualFollowersAndCommunity:
        return '相互フォロー + コミュニティのみ';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // 画像が選択されているかチェック
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('画像を選択してください')));
      return;
    }

    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('完了予定時刻を設定してください')));
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
        privacyLevel: _selectedPrivacyLevel,
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
      }

      final success = await postProvider.createPost(post);

      if (success) {
        if (kDebugMode) {
          print('投稿作成成功');
        }

        // 投稿作成後にユーザーの投稿一覧を更新
        await postProvider.getUserPosts(userProvider.currentUser!.id);

        if (mounted) {
          if (widget.communityId != null) {
            Navigator.of(context).pop(); // コミュニティ画面に戻る
          } else {
            context.go('/home');
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
