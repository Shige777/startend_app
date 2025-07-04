import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';

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
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _selectedImagePath != null
                          ? NetworkImage(_selectedImagePath!)
                          : null,
                      child: _selectedImagePath == null
                          ? const Icon(Icons.person, size: 60)
                          : null,
                    ),
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

      // TODO: 画像をFirebase Storageにアップロード
      String? imageUrl = _selectedImagePath;
      if (_selectedImagePath != null &&
          !_selectedImagePath!.startsWith('http')) {
        // 新しい画像が選択された場合のアップロード処理
        // imageUrl = await uploadImageToStorage(_selectedImagePath!);
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
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('プロフィールを更新しました')),
          );
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
