import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../../widgets/community_list_widget.dart';
import '../../widgets/wave_loading_widget.dart';
import '../../widgets/platform_image_picker.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedIndex = 2; // コミュニティタブ

  @override
  void initState() {
    super.initState();
    // コミュニティ一覧を読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().searchCommunities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('コミュニティ'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Consumer2<CommunityProvider, UserProvider>(
        builder: (context, communityProvider, userProvider, child) {
          if (communityProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WaveLoadingWidget(
                    size: 80,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'コミュニティを読み込み中...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 全コミュニティ一覧
              Expanded(
                child: CommunityListWidget(
                  communities: communityProvider.communities,
                  onCommunityTap: (community) {
                    context.go('/community/${community.id}');
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateCommunityDialog(context);
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.group_add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _handleNavigation(context, index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '投稿'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: '軌跡'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'コミュニティ'),
        ],
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/profile');
        break;
      case 2:
        // コミュニティ画面 (現在の画面)
        break;
    }
  }

  void _showCreateCommunityDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool requiresApproval = false;
    Uint8List? selectedImageBytes;
    String? selectedImageName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('コミュニティ作成'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // アイコン選択
                    GestureDetector(
                      onTap: () async {
                        // 画像選択ダイアログを表示
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('アイコン選択'),
                            content: PlatformImagePicker(
                              onImageSelected: (bytes, fileName) {
                                setState(() {
                                  selectedImageBytes = bytes;
                                  selectedImageName = fileName;
                                });
                                Navigator.of(context).pop();
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('キャンセル'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: selectedImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Image.memory(
                                  selectedImageBytes!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.add_a_photo,
                                size: 32,
                                color: AppColors.textSecondary,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'アイコンを選択',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'コミュニティ名',
                        hintText: '例: 朝活コミュニティ',
                      ),
                      maxLength: 50,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: '説明',
                        hintText: 'コミュニティの説明を入力してください',
                      ),
                      maxLines: 3,
                      maxLength: 200,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('承認制'),
                      subtitle: const Text('新しいメンバーの参加に承認が必要'),
                      value: requiresApproval,
                      onChanged: (value) {
                        setState(() {
                          requiresApproval = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('コミュニティ名を入力してください')),
                      );
                      return;
                    }

                    final userProvider = context.read<UserProvider>();
                    final currentUser = userProvider.currentUser;

                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ログインが必要です')),
                      );
                      return;
                    }

                    // 画像をアップロード
                    String? imageUrl;
                    if (selectedImageBytes != null &&
                        selectedImageName != null) {
                      // 一時的なコミュニティIDを生成
                      final tempCommunityId =
                          DateTime.now().millisecondsSinceEpoch.toString();

                      imageUrl =
                          await StorageService.uploadCommunityIconFromBytes(
                        bytes: selectedImageBytes!,
                        userId: currentUser.id,
                        communityId: tempCommunityId,
                        fileName: selectedImageName!,
                      );
                    }

                    final success =
                        await context.read<CommunityProvider>().createCommunity(
                              name: nameController.text.trim(),
                              description: descriptionController.text.trim(),
                              userId: currentUser.id,
                              requiresApproval: requiresApproval,
                              imageUrl: imageUrl,
                            );

                    if (success && context.mounted) {
                      // UserProviderのcurrentUserも更新
                      await context.read<UserProvider>().refreshCurrentUser();

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('コミュニティを作成しました')),
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('コミュニティの作成に失敗しました')),
                      );
                    }
                  },
                  child: const Text('作成'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
