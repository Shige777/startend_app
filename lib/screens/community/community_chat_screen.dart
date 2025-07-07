import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/community_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/post_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/wave_loading_widget.dart';
import '../../widgets/post_card_widget.dart';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面に戻ってきた時に投稿を再読み込み
    if (_community != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _loadCommunityPosts();
      });
    }
  }

  @override
  void didUpdateWidget(CommunityChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ウィジェットが更新された時も投稿を再読み込み
    if (oldWidget.communityId != widget.communityId) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _loadCommunityData();
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _createPost() async {
    final result = await context
        .push('/create-post', extra: {'communityId': widget.communityId});
    // 投稿作成から戻ってきた時に投稿を再読み込み（常に実行）
    await _loadCommunityPosts();
  }

  void _createEndPost(PostModel startPost) async {
    final result = await context.push('/create-end-post', extra: {
      'startPostId': startPost.id,
      'startPost': startPost,
    });
    // END投稿作成から戻ってきた時に投稿を再読み込み（常に実行）
    await _loadCommunityPosts();
  }

  Future<void> _loadCommunityPosts() async {
    if (kDebugMode) {
      print('CommunityChatScreen: 投稿読み込み開始 - ${widget.communityId}');
    }

    final postProvider = context.read<PostProvider>();
    final posts = await postProvider.getCommunityPosts(widget.communityId);

    if (kDebugMode) {
      print('CommunityChatScreen: 投稿読み込み完了 - ${posts.length}件');
    }

    if (mounted) {
      setState(() {
        _communityPosts = posts;
      });

      // 投稿読み込み後に最下部にスクロール
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
      await _loadCommunityPosts();
      setState(() {
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
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: _communityPosts.length,
                  itemBuilder: (context, index) {
                    final post = _communityPosts[index];
                    return _buildCommunityPostCard(post);
                  },
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
            _buildCommunityImage(_community!.imageUrl, radius: 80),
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

  Widget _buildCommunityPostCard(PostModel post) {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    final isOwnPost = currentUser != null && post.userId == currentUser.id;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      decoration: BoxDecoration(
        color:
            isOwnPost ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
        // 自分の投稿には左側に濃い青い線を追加
        border: isOwnPost
            ? const Border(left: BorderSide(color: AppColors.primary, width: 6))
            : Border.all(color: AppColors.divider.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Transform.scale(
        scale: 0.95, // 全体的に5%小さく
        child: PostCardWidget(
          post: post,
          onTap: () {
            // コミュニティ投稿の詳細画面に遷移する際に、戻り先をコミュニティ画面に指定
            context.push('/post/${post.id}', extra: {
              'post': post,
              'fromCommunity': widget.communityId,
            });
          },
          onDelete: isOwnPost ? () => _showDeleteConfirmation(post) : null,
          showActions: true, // アクションボタンを表示してリアクション可能に
        ),
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
    if (success != null) {
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
  Widget _buildCommunityImage(String? imageUrl, {double radius = 40}) {
    if (imageUrl == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceVariant,
        child: Icon(Icons.group, size: radius),
      );
    }

    if (_isNetworkUrl(imageUrl)) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // エラーハンドリング
        },
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceVariant,
        child: Icon(Icons.group, size: radius),
      );
    }
  }

  Widget _buildPostImage(String imageUrl) {
    return Container(
      width: double.infinity,
      height: 200, // 画像の高さを大きく
      child: _isNetworkUrl(imageUrl)
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 200,
                  color: AppColors.surface,
                  child: const Icon(Icons.image_not_supported),
                );
              },
            )
          : Container(
              width: double.infinity,
              height: 200,
              color: AppColors.surface,
              child: const Icon(Icons.image_not_supported),
            ),
    );
  }

  // 削除確認ダイアログを表示
  void _showDeleteConfirmation(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿削除'),
        content: const Text('この投稿を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePost(post);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // 投稿削除処理
  Future<void> _deletePost(PostModel post) async {
    final postProvider = context.read<PostProvider>();

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await postProvider.deletePost(post.id);

      if (mounted) {
        Navigator.of(context).pop(); // ローディング終了

        if (success) {
          // ローカルリストからも削除
          setState(() {
            _communityPosts.removeWhere((p) => p.id == post.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿を削除しました')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿の削除に失敗しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // ローディング終了
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }
}
