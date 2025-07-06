import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/community_model.dart';
import '../../models/post_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/post_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/wave_loading_widget.dart';

class CommunityChatScreen extends StatefulWidget {
  final String communityId;

  const CommunityChatScreen({
    super.key,
    required this.communityId,
  });

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  bool _isJoined = false;
  bool _isLoading = true;
  bool _isLeader = false;
  CommunityModel? _community;
  List<PostModel> _communityPosts = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadCommunityData();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _createPost() {
    context.go('/create-post', extra: {'communityId': widget.communityId});
  }

  Future<void> _loadCommunityData() async {
    final communityProvider = context.read<CommunityProvider>();
    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();

    // コミュニティ情報を取得
    final community = await communityProvider.getCommunity(widget.communityId);
    if (community != null) {
      final currentUser = userProvider.currentUser;
      setState(() {
        _community = community;
        _isJoined =
            currentUser?.communityIds.contains(widget.communityId) ?? false;
        _isLeader = currentUser?.id == community.leaderId;
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_community!.name),
        actions: [
          if (_isLeader)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'settings':
                    _showSettingsDialog();
                    break;
                  case 'members':
                    _showMembersDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 8),
                      Text('設定'),
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
          if (!_isJoined)
            TextButton(
              onPressed: _canJoin() ? _joinCommunity : null,
              child: const Text('参加'),
            ),
        ],
      ),
      body: _isJoined ? _buildPostsView() : _buildJoinPrompt(),
      floatingActionButton: _isJoined
          ? FloatingActionButton(
              onPressed: _createPost,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildPostsView() {
    return Column(
      children: [
        // 投稿一覧
        Expanded(
          child: _communityPosts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.post_add, size: 64, color: AppColors.textHint),
                      SizedBox(height: 16),
                      Text(
                        'まだ投稿がありません\n最初の投稿を作成してみましょう！',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  itemCount: _communityPosts.length,
                  itemBuilder: (context, index) {
                    final post = _communityPosts[index];
                    return _buildMessageBubble(post);
                  },
                ),
        ),

        // メッセージ入力欄
        Container(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.divider),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'メッセージを入力...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
                color: AppColors.primary,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJoinPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCommunityImage(_community!.imageUrl, radius: 50),
            const SizedBox(height: 24),
            Text(
              _community!.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${_community!.memberIds.length}人のメンバー',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (_community!.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _community!.description,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canJoin() ? _joinCommunity : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_community!.isPrivate ? '参加申請' : '参加'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(PostModel post) {
    final currentUser = context.read<UserProvider>().currentUser;
    final isMyMessage = post.userId == currentUser?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMyMessage ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage)
                    Text(
                      'ユーザー名', // TODO: 実際のユーザー名を取得
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (post.title.isNotEmpty)
                    Text(
                      post.title,
                      style: TextStyle(
                        color: isMyMessage
                            ? AppColors.textOnPrimary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (post.comment != null && post.comment!.isNotEmpty)
                    Text(
                      post.comment!,
                      style: TextStyle(
                        color: isMyMessage
                            ? AppColors.textOnPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  if (post.imageUrl != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        post.imageUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DateTimeUtils.formatTime(post.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMyMessage
                          ? AppColors.textOnPrimary.withOpacity(0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  bool _canJoin() {
    if (_community == null) return false;
    return _community!.memberIds.length < _community!.maxMembers;
  }

  Future<void> _joinCommunity() async {
    final communityProvider = context.read<CommunityProvider>();
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) return;

    bool success;
    if (_community!.isPrivate) {
      // 承認制の場合は参加申請
      success = await communityProvider.requestJoinCommunity(
          widget.communityId, currentUser.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('参加申請を送信しました')),
        );
      }
    } else {
      // オープンの場合は直接参加
      success = await communityProvider.joinCommunity(widget.communityId,
          userId: currentUser.id);
      if (success && mounted) {
        setState(() {
          _isJoined = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コミュニティに参加しました')),
        );
        _loadCommunityData();
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) return;

    final post = PostModel(
      id: '',
      userId: currentUser.id,
      type: PostType.start,
      title: '',
      comment: _messageController.text.trim(),
      imageUrl: null,
      privacyLevel: PrivacyLevel.communityOnly,
      communityIds: [widget.communityId],
      likedByUserIds: [],
      likeCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await postProvider.createPost(post);
    if (success) {
      _messageController.clear();
      _loadCommunityData(); // メッセージ一覧を更新
    }
  }

  void _showSettingsDialog() {
    bool isPrivate = _community!.isPrivate;
    int maxMembers = _community!.maxMembers;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('コミュニティ設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('承認制'),
                    subtitle: const Text('新しいメンバーの参加に承認が必要'),
                    value: isPrivate,
                    onChanged: (value) {
                      setState(() {
                        isPrivate = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('最大メンバー数: '),
                      Expanded(
                        child: Slider(
                          value: maxMembers.toDouble(),
                          min: 2,
                          max: 50,
                          divisions: 48,
                          label: maxMembers.toString(),
                          onChanged: (value) {
                            setState(() {
                              maxMembers = value.round();
                            });
                          },
                        ),
                      ),
                      Text(maxMembers.toString()),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final success = await context
                        .read<CommunityProvider>()
                        .updateCommunitySettings(
                          communityId: widget.communityId,
                          isPrivate: isPrivate,
                          maxMembers: maxMembers,
                        );

                    if (success && context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('設定を更新しました')),
                      );
                      _loadCommunityData();
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMembersDialog() {
    // TODO: メンバー管理ダイアログの実装
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('メンバー管理'),
          content: const Text('メンバー管理機能は今後実装予定です'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  // 画像URLがネットワークURLかローカルファイルパスかを判別
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // コミュニティ画像を表示するWidgetを構築
  Widget _buildCommunityImage(String? imageUrl, {double radius = 50}) {
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
}
