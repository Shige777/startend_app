import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/post_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../../widgets/post_list_widget.dart';
import '../../widgets/custom_tab_bar.dart';
import '../community/community_screen.dart';
import '../../widgets/platform_image_picker.dart';
import '../profile/profile_screen.dart';
import '../../widgets/leaf_loading_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedIndex = 0; // 0: 投稿, 1: 軌跡
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // 初期化完了後にローディング状態をfalseに設定し、ユーザー情報を確認（フレームレート制御）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // フレーム処理の重複を避けるため、少し遅延させる
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            // ユーザー情報の初期化を確認
            _ensureUserInitialized();
          }
        });
      }
    });

    // URLパラメータからタブを設定（GoRouterStateエラー回避、フレーム処理最適化）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 前のaddPostFrameCallbackと競合しないよう少し遅延
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            try {
              final uri = GoRouterState.of(context).uri;
              final tabParam = uri.queryParameters['tab'];
              if (tabParam == '1') {
                setState(() {
                  _selectedIndex = 1; // 軌跡タブ
                });
              } else if (tabParam == 'community') {
                setState(() {
                  _selectedIndex = 0; // 投稿画面
                });
                // コミュニティタブを選択
                _tabController.index = 1;
              } else {
                // デフォルトまたは投稿タブ
                setState(() {
                  _selectedIndex = 0;
                });
                _tabController.index = 0;
              }
            } catch (e) {
              print('GoRouterState not available: $e');
              // デフォルトタブを使用
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ユーザー情報の初期化を確保
  void _ensureUserInitialized() async {
    try {
      final userProvider = context.read<UserProvider>();
      if (userProvider.currentUser == null && !userProvider.isLoading) {
        await userProvider.refreshCurrentUser();
      }
    } catch (e) {
      print('HomeScreen: Error ensuring user initialized: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: LeafLoadingWidget(color: AppColors.primary, size: 50))
          : _buildContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomTabChanged,
        backgroundColor: Colors.white, // 背景色を白に変更
        elevation: 0, // 影を削除
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '投稿'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: '軌跡'),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildPostScreen();
      case 1:
        // 軌跡画面：自分のプロフィールのみ表示
        return Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final currentUser = userProvider.currentUser;
            if (currentUser == null) {
              // ユーザー情報を再取得し、ローディング状態を表示
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  userProvider.refreshCurrentUser();
                }
              });
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LeafLoadingWidget(
                      size: 80,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'ユーザー情報を読み込み中...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ProfileScreen(
              userId: currentUser.id,
              isOwnProfile: true,
              fromPage: 'home', // ホーム画面から来たことを示す
            );
          },
        );
      default:
        return _buildPostScreen();
    }
  }

  Widget _buildPostScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('startend'),
        backgroundColor: AppColors.background, // 背景色を統一
        elevation: 0,
        scrolledUnderElevation: 0, // スクロール時の影も削除
        actions: [],
        bottom: CustomTabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'フォロー中'),
            Tab(text: 'コミュニティ'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 検索バー
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white, // 背景色を白に変更
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: _tabController.index == 0
                    ? '投稿・ユーザーを検索...'
                    : 'コミュニティを検索...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: InputBorder.none, // 枠線を削除
                focusedBorder: InputBorder.none, // フォーカス時の枠線も削除
                enabledBorder: InputBorder.none, // 通常時の枠線も削除
                filled: true,
                fillColor: Colors.white, // 背景色を白に変更
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _performSearch,
            ),
          ),
          // タブビュー
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PostListWidget(
                  type: PostListType.following,
                  searchQuery: _searchQuery,
                ),
                CommunityScreen(searchQuery: _searchQuery),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_selectedIndex) {
      case 0:
        // 投稿画面：タブに応じてアクションを変更
        if (_tabController.index == 0) {
          // フォロー中タブ：投稿作成
          return FloatingActionButton(
            heroTag: "home_post_fab",
            onPressed: () {
              context.push('/post/create');
            },
            backgroundColor: AppColors.primary,
            child: const Icon(
              Icons.add,
              color: AppColors.textOnPrimary,
            ),
          );
        } else {
          // コミュニティタブ：FloatingActionButtonはCommunityScreenで処理
          return null;
        }
      case 1:
        // 軌跡タブ：FloatingActionButtonは不要
        return null;
      default:
        return null;
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
    });

    if (_tabController.index == 0) {
      // フォロー中タブでの検索（投稿とユーザーを検索）
      if (query.trim().isNotEmpty) {
        _performActualSearch(query.trim());
      }
    } else {
      // コミュニティタブでの検索
      // CommunityScreenで処理される
    }
  }

  Future<void> _performActualSearch(String query) async {
    try {
      final postProvider = context.read<PostProvider>();
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;

      // 投稿検索
      await postProvider.searchPosts(query, currentUserId: currentUser?.id);

      // ユーザー検索
      await userProvider.searchUsers(query);
    } catch (e) {
      print('検索エラー: $e');
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
                      onTap: () => _showImagePickerBottomSheet(
                          context, setState, (bytes, fileName) {
                        selectedImageBytes = bytes;
                        selectedImageName = fileName;
                      }),
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
                    const SizedBox(height: 8),
                    const Text(
                      '※ 大きな画像は自動的に圧縮されます',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
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
                      try {
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
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('アイコンのアップロードに失敗しました: $e')),
                          );
                        }
                        return;
                      }
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

  void _onTabChanged() {
    // タブが変更されたときの処理
    setState(() {}); // FloatingActionButtonのアイコンを更新

    // ユーザー情報の初期化を確認（特にフォロー中タブに切り替わった時）
    if (_tabController.index == 0) {
      _ensureUserInitialized();
    }
  }

  void _onBottomTabChanged(int index) {
    final oldIndex = _selectedIndex;
    setState(() {
      _selectedIndex = index;
    });

    // 軌跡タブに初回切り替え時のみリフレッシュ
    if (index == 1 && oldIndex != 1) {
      _ensureUserInitialized();
    }
  }

  void _showImagePickerBottomSheet(
    BuildContext context,
    StateSetter setState,
    Function(Uint8List, String) onImageSelected,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'アイコンを選択',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // カメラで撮影
                GestureDetector(
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (kIsWeb) {
                      // Web版では画像選択のみ
                      _showWebImagePicker(context, setState, onImageSelected);
                    } else {
                      // モバイル版ではカメラ撮影
                      _pickImageFromCamera(setState, onImageSelected);
                    }
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'カメラで撮影',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ギャラリーから選択
                GestureDetector(
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (kIsWeb) {
                      // Web版では画像選択
                      _showWebImagePicker(context, setState, onImageSelected);
                    } else {
                      // モバイル版ではギャラリー選択
                      _pickImageFromGallery(setState, onImageSelected);
                    }
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'ギャラリーから選択',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showWebImagePicker(
    BuildContext context,
    StateSetter setState,
    Function(Uint8List, String) onImageSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('画像を選択'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: PlatformImagePicker(
            onImageSelected: (bytes, fileName) {
              Navigator.of(context).pop();
              setState(() {
                onImageSelected(bytes, fileName);
              });
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

  Future<void> _pickImageFromCamera(
    StateSetter setState,
    Function(Uint8List, String) onImageSelected,
  ) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          onImageSelected(bytes, pickedFile.name);
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の取得に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery(
    StateSetter setState,
    Function(Uint8List, String) onImageSelected,
  ) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          onImageSelected(bytes, pickedFile.name);
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の取得に失敗しました: $e')),
        );
      }
    }
  }
}
