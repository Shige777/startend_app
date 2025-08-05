import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/storage_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/community_model.dart';
import 'package:image_picker/image_picker.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _requiresApproval = false;
  bool _isLoading = false;

  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 今日のコミュニティ作成数を取得
  Future<int> _getTodayCommunityCount() async {
    try {
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;
      if (currentUser == null) return 0;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final firestore = FirebaseFirestore.instance;
      final todayCommunitiesSnapshot = await firestore
          .collection('communities')
          .where('leaderId', isEqualTo: currentUser.id)
          .get();

      final todayCommunities = todayCommunitiesSnapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .where((community) => 
              community.createdAt.isAfter(startOfDay) && 
              community.createdAt.isBefore(endOfDay))
          .toList();

      return todayCommunities.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _handleImageSelection() async {
    try {
      print('コミュニティアイコン選択開始');
      // 直接ギャラリーから画像を選択
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (pickedFile != null) {
        print('画像が選択されました: ${pickedFile.name}');
        final bytes = await pickedFile.readAsBytes();
        print('画像バイト数: ${bytes.length}');
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFileName = pickedFile.name;
        });
        print('画像が設定されました');
      } else {
        print('画像が選択されませんでした');
      }
    } catch (e) {
      print('画像選択エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の選択に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final communityProvider = context.read<CommunityProvider>();
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログインが必要です')),
        );
        return;
      }

      // 画像をアップロード
      String? imageUrl;
      if (_selectedImageBytes != null && _selectedImageFileName != null) {
        try {
          // 一時的なコミュニティIDを生成
          final tempCommunityId =
              DateTime.now().millisecondsSinceEpoch.toString();

          imageUrl = await StorageService.uploadCommunityIconFromBytes(
            bytes: _selectedImageBytes!,
            userId: currentUser.id,
            communityId: tempCommunityId,
            fileName: _selectedImageFileName!,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('アイコンのアップロードに失敗しました: $e')),
            );
          }
          return;
        }
      }

      final success = await communityProvider.createCommunity(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        userId: currentUser.id,
        requiresApproval: _requiresApproval,
        imageUrl: imageUrl,
      );

      if (success && mounted) {
        // UserProviderのcurrentUserも更新
        await userProvider.refreshCurrentUser();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コミュニティを作成しました')),
        );

        // 作成したコミュニティの詳細画面に直接遷移
        final communityId = communityProvider.lastCreatedCommunityId;
        if (communityId != null) {
          context.go('/community/$communityId');
        } else {
          // 成功時は前の画面に戻る
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home?tab=community');
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(communityProvider.errorMessage ?? 'コミュニティの作成に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
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
    print('CreateCommunityScreen build メソッドが実行されました');
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // タイトル
                const Text(
                  'コミュニティを作成',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // 今日のコミュニティ作成数表示
                Consumer<CommunityProvider>(
                  builder: (context, communityProvider, child) {
                    return FutureBuilder<int>(
                      future: _getTodayCommunityCount(),
                      builder: (context, snapshot) {
                        final todayCount = snapshot.data ?? 0;
                        if (todayCount >= 5) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red[200]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: Colors.red[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '今日のコミュニティ作成制限に達しました（5個）',
                                    style: TextStyle(
                                      color: Colors.red[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),

                // アイコン選択
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'コミュニティアイコン',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              print('アイコン選択ボタンがタップされました');
                              await _handleImageSelection();
                              print(
                                  '_selectedImageBytes:  [32m [1m [4m${_selectedImageBytes?.length} [0m');
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                    color: AppColors.divider, width: 2),
                              ),
                              child: _selectedImageBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(50),
                                      child: Image.memory(
                                        _selectedImageBytes!,
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 100,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.image,
                                          size: 40,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '画像を選択',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'アイコンを選択（任意）',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // コミュニティ名
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'コミュニティ名',
                    hintText: '例: 朝活コミュニティ',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 50,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'コミュニティ名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 説明
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '説明（任意）',
                    hintText: 'コミュニティの説明を入力してください',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 24),

                // 設定
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'プライバシー設定',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<bool>(
                      title: const Text('オープン'),
                      subtitle: const Text('誰でも参加可能'),
                      value: false,
                      groupValue: _requiresApproval,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setState(() {
                          _requiresApproval = value ?? false;
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      title: const Text('承認制'),
                      subtitle: const Text('コミュニティ管理者の承認が必要'),
                      value: true,
                      groupValue: _requiresApproval,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        print('承認制が選択されました: $value');
                        setState(() {
                          _requiresApproval = value ?? false;
                        });
                        print('_requiresApprovalが更新されました: $_requiresApproval');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ボタン
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home?tab=community');
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('キャンセル'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('作成'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
