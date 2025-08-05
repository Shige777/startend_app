import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart' as auth;
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('ProfileSettingsScreen: initState called');
    // ビルド完了後にユーザーデータを読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  void _loadUserData() {
    print('ProfileSettingsScreen: _loadUserData called');
    final user = context.read<UserProvider>().currentUser;
    print('ProfileSettingsScreen: Loading user data - ${user?.displayName}');
    if (user != null) {
      setState(() {
        _displayNameController.text = user.displayName;
        _bioController.text = user.bio ?? '';
        _selectedImagePath = user.profileImageUrl;
        _isPrivate = user.isPrivate;
      });
      print('ProfileSettingsScreen: User data loaded successfully');
      print(
          'ProfileSettingsScreen: Display Name: ${_displayNameController.text}');
      print('ProfileSettingsScreen: Bio: ${_bioController.text}');
      print('ProfileSettingsScreen: Image Path: $_selectedImagePath');
    } else {
      print('ProfileSettingsScreen: No user data available');
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
        if (kIsWeb) {
          // Web環境では画像読み込みエラーを適切に処理
          return CircleAvatar(
            radius: 60,
            backgroundColor: AppColors.surfaceVariant,
            child: ClipOval(
              child: Image.network(
                _selectedImagePath!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('プロフィール画像読み込みエラー: $error');
                  print('URL: $_selectedImagePath');
                  return const Icon(Icons.person, size: 60);
                },
              ),
            ),
          );
        } else {
          // モバイル環境では従来通り
          return CircleAvatar(
            radius: 60,
            backgroundImage: NetworkImage(_selectedImagePath!),
          );
        }
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
    print('ProfileSettingsScreen: build called');
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.currentUser;
        print(
            'ProfileSettingsScreen: build - user is ${user != null ? 'available' : 'null'}');

        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('プロフィール設定'),
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'ユーザー情報を取得できません',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('プロフィール設定'),
            backgroundColor: AppColors.background, // 背景色を統一
            elevation: 0, // 影を削除
            scrolledUnderElevation: 0, // スクロール時の影も削除
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '保存',
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
                  // プロフィール画像
                  Center(
                    child: Column(
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
                    style: const TextStyle(color: Colors.black),
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
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: '自己紹介',
                      hintText: 'あなたについて教えてください',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                    maxLength: 200,
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
                        : const Text(
                            'プロフィールを保存',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        // Web環境では、バイトデータを取得
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFileName = pickedFile.name;
          _selectedImagePath = null; // 既存のパスをクリア
        });
      } else {
        // モバイル環境では、パスを設定
        setState(() {
          _selectedImagePath = pickedFile.path;
          _selectedImageBytes = null; // 既存のバイトデータをクリア
          _selectedImageFileName = null;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final authProvider = context.read<auth.AuthProvider>();

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
        requiresApproval: false, // フォロー承認機能は無効
        updatedAt: DateTime.now(),
      );

      final success = await userProvider.updateUser(updatedUser);

      if (success) {
        // ユーザー情報を再取得して投稿画面での表示を即座に更新
        await userProvider.refreshCurrentUser();

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
            backgroundColor: Colors.black,
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
