import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';

import '../../models/post_model.dart';
import '../../widgets/platform_image_picker.dart';
import '../../services/storage_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedImagePath;
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  bool _isPrivate = false;
  bool _requiresApproval = false;
  bool _isLoading = false;
  PrivacyLevel _defaultPrivacyLevel = PrivacyLevel.public;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = context.read<UserProvider>().currentUser;
    if (user != null) {
      _displayNameController.text = user.displayName;
      _bioController.text = user.bio ?? '';
      _selectedImagePath = user.profileImageUrl;
      _isPrivate = user.isPrivate;
      _requiresApproval = user.requiresApproval;
    }
  }

  // 画像URLがネットワークURLかローカルファイルパスかを判別
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // プロフィール画像を表示するWidgetを構築
  Widget _buildProfileImage() {
    if (_selectedImageBytes != null) {
      // Web環境で選択した画像
      return CircleAvatar(
        radius: 60,
        backgroundImage: MemoryImage(_selectedImageBytes!),
      );
    } else if (_selectedImagePath != null) {
      if (_isNetworkUrl(_selectedImagePath!)) {
        // ネットワーク画像
        return CircleAvatar(
          radius: 60,
          backgroundImage: NetworkImage(_selectedImagePath!),
        );
      } else {
        // ローカルファイル
        if (kIsWeb) {
          // Webの場合はエラー表示
          return const CircleAvatar(
            radius: 60,
            child: Icon(Icons.error, size: 60),
          );
        } else {
          // モバイルの場合はFileImageを使用
          try {
            return CircleAvatar(
              radius: 60,
              backgroundImage: FileImage(File(_selectedImagePath!)),
            );
          } catch (e) {
            return const CircleAvatar(
              radius: 60,
              child: Icon(Icons.error, size: 60),
            );
          }
        }
      }
    } else {
      // 画像なし
      return const CircleAvatar(
        radius: 60,
        child: Icon(Icons.person, size: 60),
      );
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('プロフィール設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // 自分のプロフィール設定から戻る場合は軌跡画面に遷移
              context.go('/home?tab=1');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
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
              // プロフィール画像
              Center(
                child: kIsWeb
                    ? Column(
                        children: [
                          _buildProfileImage(),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickImageWeb,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('画像を選択'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '※ 大きな画像は自動的に圧縮されます',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Stack(
                            children: [
                              _buildProfileImage(),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      color: AppColors.textOnPrimary,
                                      size: 20,
                                    ),
                                    onPressed: _pickImage,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '※ 大きな画像は自動的に圧縮されます',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),

              // 表示名
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: '表示名',
                  hintText: 'あなたの名前を入力してください',
                  prefixIcon: Icon(Icons.person),
                ),
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '表示名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 自己紹介
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: '自己紹介',
                  hintText: 'あなたについて教えてください',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                maxLength: 200,
              ),
              const SizedBox(height: 24),

              // プライバシー設定
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'プライバシー設定',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),

                      // 軌跡の公開範囲
                      DropdownButtonFormField<PrivacyLevel>(
                        value: _defaultPrivacyLevel,
                        decoration: const InputDecoration(
                          labelText: '軌跡の公開範囲',
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
                              _defaultPrivacyLevel = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // プライベートアカウント
                      SwitchListTile(
                        title: const Text('プライベートアカウント'),
                        subtitle: const Text('フォローリクエストが必要になります'),
                        value: _isPrivate,
                        onChanged: (value) {
                          setState(() {
                            _isPrivate = value;
                          });
                        },
                      ),

                      // フォロー承認
                      SwitchListTile(
                        title: const Text('フォロー承認'),
                        subtitle: const Text('フォローリクエストを手動で承認します'),
                        value: _requiresApproval,
                        onChanged: (value) {
                          setState(() {
                            _requiresApproval = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 保存ボタン
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
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
                    : const Text('プロフィールを保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImagePath = pickedFile.path;
      });
    }
  }

  void _pickImageWeb() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プロフィール画像を選択'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: PlatformImagePicker(
            width: 300,
            height: 300,
            placeholder: 'プロフィール画像を選択',
            onImageSelected: (bytes, fileName) {
              setState(() {
                _selectedImageBytes = bytes;
                _selectedImageFileName = fileName;
              });
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final authProvider = context.read<AuthProvider>();

      final currentUser = userProvider.currentUser;
      if (currentUser == null || authProvider.user == null) {
        throw Exception('ユーザー情報が取得できません');
      }

      // 画像をFirebase Storageにアップロード
      String? imageUrl = _selectedImagePath;

      if (kIsWeb && _selectedImageBytes != null) {
        // Web環境：バイトデータからアップロード
        try {
          imageUrl = await StorageService.uploadProfileImageFromBytes(
            bytes: _selectedImageBytes!,
            userId: currentUser.id,
            fileName: _selectedImageFileName ?? 'profile.jpg',
          );
          if (imageUrl == null) {
            throw Exception('画像のアップロードに失敗しました');
          }
        } catch (e) {
          throw Exception('画像アップロードエラー: $e');
        }
      } else if (!kIsWeb &&
          _selectedImagePath != null &&
          !_selectedImagePath!.startsWith('http')) {
        // モバイル環境：ファイルパスからアップロード
        try {
          imageUrl = await StorageService.uploadProfileImage(
            filePath: _selectedImagePath!,
            userId: currentUser.id,
          );
          if (imageUrl == null) {
            throw Exception('画像のアップロードに失敗しました');
          }
        } catch (e) {
          throw Exception('画像アップロードエラー: $e');
        }
      }

      final updatedUser = currentUser.copyWith(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        profileImageUrl: imageUrl,
        isPrivate: _isPrivate,
        requiresApproval: _requiresApproval,
        updatedAt: DateTime.now(),
      );

      final success = await userProvider.updateUser(updatedUser);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('プロフィールを更新しました')),
          );

          // 安全なナビゲーション
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            // 自分のプロフィール設定から戻る場合は軌跡画面に遷移
            context.go('/home?tab=1');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userProvider.errorMessage ?? 'プロフィールの更新に失敗しました'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'エラーが発生しました';

        // エラーメッセージを解析してユーザーフレンドリーなメッセージに変換
        final errorString = e.toString();
        if (errorString.contains('圧縮後もファイルサイズが大きすぎます')) {
          errorMessage = '画像が非常に大きいため、圧縮後も制限を超えています。\nより小さい画像を選択してください。';
        } else if (errorString.contains('画像の圧縮に失敗しました')) {
          errorMessage = '画像の圧縮に失敗しました。\n別の画像を選択してください。';
        } else if (errorString.contains('Message too long')) {
          errorMessage = '画像が大きすぎます。\nより小さいサイズの画像を選択してください。';
        } else if (errorString.contains('画像アップロードエラー')) {
          errorMessage = '画像のアップロードに失敗しました。\nネットワーク接続を確認してください。';
        } else if (errorString.contains('アップロード権限がありません')) {
          errorMessage = 'アップロード権限がありません。\nアプリを再起動してください。';
        } else if (errorString.contains('ネットワークエラー')) {
          errorMessage = 'ネットワークエラーが発生しました。\n接続を確認してから再試行してください。';
        } else if (errorString.contains('タイムアウト')) {
          errorMessage = 'アップロードがタイムアウトしました。\nファイルサイズを小さくしてください。';
        } else if (errorString.contains('ファイルが空です')) {
          errorMessage = '選択した画像ファイルが無効です。\n別の画像を選択してください。';
        } else {
          errorMessage =
              'エラーが発生しました: ${e.toString().replaceAll('Exception: ', '')}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
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
