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

class EditPostScreen extends StatefulWidget {
  final PostModel post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _commentController;

  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;

  bool _isLoading = false;
  bool _imageChanged = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _commentController = TextEditingController(text: widget.post.comment ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onImageSelected(Uint8List bytes, String fileName) {
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageFileName = fileName;
      _imageChanged = true;
    });
  }

  Future<void> _handleSubmit() async {
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

      String? imageUrl = widget.post.imageUrl;

      // 画像が変更された場合のみアップロード
      if (_imageChanged && _selectedImageBytes != null) {
        imageUrl = await StorageService.uploadPostImageFromBytes(
          bytes: _selectedImageBytes!,
          userId: currentUser.id,
          postId: widget.post.id,
          fileName: _selectedImageFileName ?? 'image.jpg',
        );

        if (imageUrl == null) {
          throw Exception('画像のアップロードに失敗しました');
        }
      }

      final updatedPost = widget.post.copyWith(
        title: _titleController.text.trim(),
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        imageUrl: imageUrl,
      );

      final success = await postProvider.updatePost(updatedPost);

      if (success) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿を更新しました')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(postProvider.errorMessage ?? '投稿の更新に失敗しました'),
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
        title: const Text('投稿編集'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('更新'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイトル入力
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // コメント入力
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'コメント（任意）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // 画像選択
              PlatformImagePicker(
                height: 200,
                placeholder: '画像を選択してください',
                onImageSelected: _onImageSelected,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
