import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/community_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/post_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/post_model.dart';
import '../../widgets/post_list_widget.dart';
import '../../widgets/wave_loading_widget.dart';
import '../../widgets/platform_image_picker_mobile.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;

  const CommunityDetailScreen({
    super.key,
    required this.communityId,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  bool _isJoined = false;
  bool _isLoading = true;
  CommunityModel? _community;
  List<PostModel> _communityPosts = [];

  @override
  void initState() {
    super.initState();
    _loadCommunityData();
  }

  Future<void> _loadCommunityData() async {
    final communityProvider = context.read<CommunityProvider>();
    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();

    // コミュニティ情報を取得
    final community = await communityProvider.getCommunity(widget.communityId);
    if (community != null) {
      setState(() {
        _community = community;
        _isJoined = userProvider.currentUser?.communityIds
                .contains(widget.communityId) ??
            false;
      });

      // コミュニティの投稿を取得
      final posts = await postProvider.getCommunityPosts(widget.communityId);
      setState(() {
        _communityPosts = posts;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 画像URLがネットワークURLかローカルファイルパスかを判別
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // コミュニティ画像を表示するWidgetを構築
  Widget _buildCommunityImage(String? imageUrl, {double radius = 30}) {
    if (imageUrl == null) {
      return CircleAvatar(
        radius: radius,
        child: Icon(Icons.group, size: radius),
      );
    }

    if (_isNetworkUrl(imageUrl)) {
      // ネットワーク画像
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl),
      );
    } else {
      // ローカルファイル
      if (kIsWeb) {
        // Webの場合はエラー表示
        return CircleAvatar(
          radius: radius,
          child: Icon(Icons.error, size: radius),
        );
      } else {
        // モバイルの場合はFileImageを使用
        try {
          return CircleAvatar(
            radius: radius,
            backgroundImage: FileImage(File(imageUrl)),
          );
        } catch (e) {
          return CircleAvatar(
            radius: radius,
            child: Icon(Icons.error, size: radius),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('コミュニティ'),
        ),
        body: const Center(
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
        ),
      );
    }

    if (_community == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('コミュニティ'),
        ),
        body: const Center(
          child: Text('コミュニティが見つかりません'),
        ),
      );
    }

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
        title: Text(_community!.name),
        actions: [
          if (_isJoined) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.go('/post/create?communityId=${widget.communityId}');
              },
            ),
            if (_isLeader())
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditCommunityDialog();
                      break;
                    case 'members':
                      _showMembersDialog();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('コミュニティ設定'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'members',
                    child: Row(
                      children: [
                        Icon(Icons.people),
                        SizedBox(width: 8),
                        Text('メンバー管理'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          // コミュニティ情報
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildCommunityImage(_community!.imageUrl, radius: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _community!.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_community!.memberIds.length}人のメンバー',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_community!.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _community!.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canJoin() ? _toggleJoin : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isJoined ? Colors.grey : AppColors.primary,
                    ),
                    child: Text(_isJoined ? '脱退' : '参加'),
                  ),
                ),
              ],
            ),
          ),

          // 投稿一覧
          Expanded(
            child: _isJoined
                ? Column(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(AppConstants.defaultPadding),
                        color: AppColors.surface,
                        child: Row(
                          children: [
                            const Icon(Icons.post_add,
                                color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'コミュニティ投稿',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _communityPosts.isEmpty
                            ? const Center(
                                child: Text(
                                  'まだ投稿がありません\n最初の投稿をしてみましょう！',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : PostListWidget(
                                type: PostListType.community,
                                posts: _communityPosts,
                                onPostTap: (post) {
                                  context.go('/post/${post.id}');
                                },
                              ),
                      ),
                    ],
                  )
                : const Center(
                    child: Text(
                      'コミュニティに参加すると\n投稿を見ることができます',
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _isJoined
          ? FloatingActionButton(
              onPressed: () {
                context.go('/post/create?communityId=${widget.communityId}');
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  bool _canJoin() {
    if (_community == null) return false;
    if (_isJoined) return true; // 脱退は常に可能
    return _community!.memberIds.length < _community!.maxMembers;
  }

  bool _isLeader() {
    final userProvider = context.read<UserProvider>();
    return _community?.leaderId == userProvider.currentUser?.id;
  }

  void _showEditCommunityDialog() {
    final nameController = TextEditingController(text: _community!.name);
    final descriptionController =
        TextEditingController(text: _community!.description);
    Uint8List? selectedImageBytes;
    String? selectedImageName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('コミュニティ設定'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // アイコン選択
                GestureDetector(
                  onTap: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('アイコンを変更'),
                        content: SizedBox(
                          width: 300,
                          height: 300,
                          child: PlatformImagePickerWidget(
                            onImageSelected: (bytes, fileName) {
                              Navigator.of(context).pop({
                                'bytes': bytes,
                                'fileName': fileName,
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
                    if (result != null) {
                      setState(() {
                        selectedImageBytes = result['bytes'];
                        selectedImageName = result['fileName'];
                      });
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: selectedImageBytes != null
                          ? Image.memory(
                              selectedImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : _buildCommunityImage(_community!.imageUrl,
                              radius: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'アイコンをタップして変更',
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
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '説明',
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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

                final updatedCommunity = _community!.copyWith(
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  updatedAt: DateTime.now(),
                );

                final success = await context
                    .read<CommunityProvider>()
                    .updateCommunity(updatedCommunity);

                if (success && mounted) {
                  setState(() {
                    _community = updatedCommunity;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('コミュニティ設定を更新しました')),
                  );
                }
              },
              child: const Text('更新'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMembersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メンバー管理'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: FutureBuilder<List<String>>(
            future: Future.value(_community!.memberIds),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final memberIds = snapshot.data!;
              return ListView.builder(
                itemCount: memberIds.length,
                itemBuilder: (context, index) {
                  final memberId = memberIds[index];
                  final isLeader = memberId == _community!.leaderId;

                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(isLeader ? 'リーダー' : 'メンバー'),
                    subtitle: Text(memberId),
                    trailing: !isLeader
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            onPressed: () => _removeMember(memberId),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メンバー削除'),
        content: const Text('このメンバーをコミュニティから削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await context
          .read<CommunityProvider>()
          .removeMember(widget.communityId, memberId);

      if (success && mounted) {
        setState(() {
          _community = _community!.copyWith(
            memberIds:
                _community!.memberIds.where((id) => id != memberId).toList(),
          );
        });
        Navigator.pop(context); // メンバー管理ダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メンバーを削除しました')),
        );
      }
    }
  }

  Future<void> _toggleJoin() async {
    final communityProvider = context.read<CommunityProvider>();
    final userProvider = context.read<UserProvider>();

    if (_isJoined) {
      // 脱退
      final currentUser = userProvider.currentUser;
      if (currentUser == null) return;

      final success = await communityProvider.leaveCommunity(
        widget.communityId,
        userId: currentUser.id,
      );
      if (success) {
        setState(() {
          _isJoined = false;
          _community = _community!.copyWith(
            memberIds: _community!.memberIds
                .where((id) => id != currentUser.id)
                .toList(),
          );
        });

        // UserProviderの現在のユーザー情報も更新
        await userProvider.refreshCurrentUser();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('コミュニティから脱退しました')),
          );
        }
      }
    } else {
      // 参加
      final success = await communityProvider.joinCommunity(widget.communityId);
      if (success) {
        setState(() {
          _isJoined = true;
          _community = _community!.copyWith(
            memberIds: [..._community!.memberIds, userProvider.currentUser!.id],
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('コミュニティに参加しました')),
          );
        }
        // 参加後に投稿を再読み込み
        _loadCommunityData();
      }
    }
  }
}
