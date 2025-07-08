import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'dart:io';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/community_model.dart';
import '../../models/user_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/post_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/post_model.dart';
import '../../widgets/wave_loading_widget.dart';
import '../../widgets/platform_image_picker_mobile.dart';
import '../../utils/date_time_utils.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面に戻ってきた時に投稿を再読み込み
    if (_community != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCommunityData();
      });
    }
  }

  Future<void> _loadCommunityData() async {
    final communityProvider = context.read<CommunityProvider>();
    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();

    print('CommunityDetailScreen: データ読み込み開始 - ${widget.communityId}');

    // コミュニティ情報を取得
    final community = await communityProvider.getCommunity(widget.communityId);
    if (community != null) {
      print('CommunityDetailScreen: コミュニティ情報取得成功 - ${community.name}');

      // ユーザーの最新情報を取得
      await userProvider.refreshCurrentUser();

      setState(() {
        _community = community;
        _isJoined = userProvider.currentUser?.communityIds
                .contains(widget.communityId) ??
            false;
      });

      print('CommunityDetailScreen: 参加状態 - $_isJoined');

      // コミュニティの投稿を取得
      final posts = await postProvider.getCommunityPosts(widget.communityId);
      print('CommunityDetailScreen: 投稿取得完了 - ${posts.length}件');

      setState(() {
        _communityPosts = posts;
        _isLoading = false;
      });
    } else {
      print('CommunityDetailScreen: コミュニティ情報取得失敗');
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
            if (context.canPop()) {
              context.pop();
            } else {
              // コミュニティ画面から戻る時はコミュニティタブを選択
              context.go('/home?tab=community');
            }
          },
        ),
        title: Text(_community!.name),
        actions: [
          if (_isJoined) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.push('/post/create?communityId=${widget.communityId}');
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
                            : ListView.builder(
                                itemCount: _communityPosts.length,
                                itemBuilder: (context, index) {
                                  final post = _communityPosts[index];
                                  return _buildCompactPostCard(post);
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
              heroTag: "community_detail_fab",
              onPressed: () {
                context.push('/post/create?communityId=${widget.communityId}');
              },
              child: const Icon(Icons.add),
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
                const SizedBox(height: 16),
                // メンバー上限数の表示（編集不可）
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      const Text(
                        'メンバー上限数: ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        '8人（固定）',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
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

                final success =
                    await context.read<CommunityProvider>().updateCommunityInfo(
                          communityId: widget.communityId,
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                        );

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
        title: Row(
          children: [
            const Text('メンバー管理'),
            const Spacer(),
            Text(
              '${_community!.memberIds.length}/8',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: FutureBuilder<List<UserModel>>(
            future: _loadMemberDetails(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('メンバー情報を取得できませんでした'),
                );
              }

              final members = snapshot.data!;
              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isLeader = member.id == _community!.leaderId;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: member.profileImageUrl != null
                            ? NetworkImage(member.profileImageUrl!)
                            : null,
                        child: member.profileImageUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.email),
                          if (isLeader)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'リーダー',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: !isLeader && _isLeader()
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.admin_panel_settings,
                                      color: AppColors.primary),
                                  onPressed: () =>
                                      _transferLeadership(member.id),
                                  tooltip: 'リーダーに任命',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle,
                                      color: Colors.red),
                                  onPressed: () => _removeMember(member.id),
                                  tooltip: 'メンバーを削除',
                                ),
                              ],
                            )
                          : null,
                    ),
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

  Future<List<UserModel>> _loadMemberDetails() async {
    final userProvider = context.read<UserProvider>();
    final List<UserModel> members = [];

    for (final memberId in _community!.memberIds) {
      try {
        final user = await userProvider.getUserById(memberId);
        if (user != null) {
          members.add(user);
        }
      } catch (e) {
        // エラーの場合は基本的なユーザー情報を作成
        members.add(UserModel(
          id: memberId,
          displayName: 'Unknown User',
          email: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          followingIds: [],
          followerIds: [],
          communityIds: [],
          isPrivate: false,
          requiresApproval: false,
        ));
      }
    }

    return members;
  }

  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null) {
      return Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(Icons.image, color: AppColors.textSecondary),
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.surfaceVariant,
          child: const Center(
            child: Icon(Icons.error, color: AppColors.error),
          ),
        );
      },
    );
  }

  Widget _buildCompactPostCard(PostModel post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/post/${post.id}', extra: {
          'post': post,
        }),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイトル
              Text(
                post.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 画像セクション（小さく）
              Container(
                height: 120, // 高さを小さく
                child: Row(
                  children: [
                    // START画像
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: _buildImageWidget(post.imageUrl),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // END画像
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: post.isCompleted && post.endImageUrl != null
                              ? _buildImageWidget(post.endImageUrl)
                              : Container(
                                  color: AppColors.surfaceVariant,
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate,
                                            color: AppColors.textSecondary,
                                            size: 24),
                                        SizedBox(height: 4),
                                        Text('END',
                                            style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // メタ情報
              Row(
                children: [
                  Icon(
                    post.isCompleted ? Icons.check_circle : Icons.play_arrow,
                    size: 16,
                    color: post.isCompleted
                        ? AppColors.completed
                        : AppColors.inProgress,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    post.isCompleted ? '完了' : '進行中',
                    style: TextStyle(
                      fontSize: 12,
                      color: post.isCompleted
                          ? AppColors.completed
                          : AppColors.inProgress,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateTimeUtils.getRelativeTime(post.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Future<void> _transferLeadership(String newLeaderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('リーダー移譲'),
        content: const Text('このメンバーを新しいリーダーに任命しますか？\nあなたは通常のメンバーになります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('任命'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await context
          .read<CommunityProvider>()
          .transferLeadership(widget.communityId, newLeaderId);

      if (success && mounted) {
        setState(() {
          _community = _community!.copyWith(leaderId: newLeaderId);
        });
        Navigator.pop(context); // メンバー管理ダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リーダーを移譲しました')),
        );
      }
    }
  }

  Future<void> _toggleJoin() async {
    final communityProvider = context.read<CommunityProvider>();
    final userProvider = context.read<UserProvider>();

    if (_isJoined) {
      // 脱退確認ダイアログを表示
      final confirmed = await _showLeaveCommunityDialog();
      if (!confirmed) return;

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

        // 投稿を再読み込み
        await _loadCommunityData();

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
        await _loadCommunityData();
      }
    }
  }

  Future<bool> _showLeaveCommunityDialog() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    final isLeader = _community?.leaderId == currentUser?.id;
    final memberCount = _community?.memberIds.length ?? 0;

    String message = 'このコミュニティから脱退しますか？';
    String warning = '';

    if (isLeader) {
      if (memberCount == 1) {
        warning = '⚠️ あなたがリーダーで最後のメンバーです。\n脱退するとコミュニティは自動的に削除されます。';
      } else {
        warning = '⚠️ あなたはリーダーです。\n脱退すると他のメンバーが新しいリーダーになります。';
      }
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('コミュニティ脱退'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (warning.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      warning,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('脱退'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
