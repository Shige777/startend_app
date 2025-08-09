import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/community_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/post_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';

import '../../widgets/leaf_loading_widget.dart';
import '../../widgets/chat_bubble_widget.dart'; // チャット風吹き出しウィジェットをインポート

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
  bool _isRefreshing = false;
  bool _hasRequestedJoin = false; // 参加申請済みかどうか
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
    // ただし、初回読み込み時は実行しない
    if (_community != null && !_isLoading) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _loadCommunityPosts(); // 投稿のみ再読み込み
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

  Future<void> _refreshCommunityPosts() async {
    if (_isRefreshing) return; // 既にリフレッシュ中の場合は何もしない

    setState(() {
      _isRefreshing = true;
    });

    if (kDebugMode) {
      print('CommunityChatScreen: 投稿再読み込み開始 - ${widget.communityId}');
    }

    final postProvider = context.read<PostProvider>();
    final posts = await postProvider.getCommunityPosts(widget.communityId);

    if (kDebugMode) {
      print('CommunityChatScreen: 投稿再読み込み完了 - ${posts.length}件');
    }

    if (mounted) {
      setState(() {
        _communityPosts = posts;
        _isRefreshing = false;
      });

      // リフレッシュ時は自動スクロールしない（ユーザーが過去のメッセージを見ている可能性があるため）
    }
  }

  Future<void> _loadCommunityData() async {
    final communityProvider = context.read<CommunityProvider>();
    final userProvider = context.read<UserProvider>();

    // コミュニティ情報を取得
    final community = await communityProvider.getCommunity(widget.communityId);
    if (community != null) {
      final currentUser = userProvider.currentUser;

      setState(() {
        _community = community;
        _isJoined =
            currentUser?.communityIds.contains(widget.communityId) ?? false;
        _isLeader = currentUser?.id == community.leaderId;
        _hasRequestedJoin =
            currentUser?.communityIds.contains(widget.communityId) ?? false;
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
              LeafLoadingWidget(
                size: 50,
                color: AppColors.primary,
              ),
              SizedBox(height: 12),
              Text(
                'コミュニティを読み込み中...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, // 背景色を統一
        elevation: 0, // 影を削除
        scrolledUnderElevation: 0, // スクロール時の影も削除
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
            PopupMenuButton<String>(
              color: Colors.white,
              onSelected: (value) {
                switch (value) {
                  case 'invite':
                    _showInviteDialog();
                    break;
                  case 'progress':
                    context.push('/community/${widget.communityId}/progress');
                    break;
                  case 'settings':
                    if (_isLeader) {
                      context.push('/community/${widget.communityId}/settings');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('リーダーのみアクセス可能です')),
                      );
                    }
                    break;
                  case 'members':
                    if (_isLeader) {
                      context.push('/community/${widget.communityId}/members');
                    } else {
                      _showMembersDialog();
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                if (_isLeader)
                  const PopupMenuItem(
                    value: 'invite',
                    child: Row(
                      children: [
                        Icon(Icons.person_add),
                        SizedBox(width: 8),
                        Text('招待'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'progress',
                  child: Row(
                    children: [
                      Icon(Icons.analytics),
                      SizedBox(width: 8),
                      Text('投稿数'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'members',
                  child: Row(
                    children: [
                      Icon(Icons.people),
                      SizedBox(width: 8),
                      Text(_isLeader ? 'メンバー管理' : 'メンバー一覧'),
                    ],
                  ),
                ),
                if (_isLeader) ...[
                  const PopupMenuDivider(),
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
                ],
              ],
            ),
          ],
          if (!_isJoined)
            TextButton(
              onPressed:
                  _canJoin() && !_hasRequestedJoin ? _joinCommunity : null,
              style: TextButton.styleFrom(
                foregroundColor:
                    _hasRequestedJoin ? AppColors.textSecondary : null,
              ),
              child: Text(_hasRequestedJoin ? '申請済み' : '参加'),
            ),
        ],
      ),
      body: _isJoined ? _buildPostsView() : _buildJoinPrompt(),
      floatingActionButton: _isJoined
          ? FloatingActionButton(
              heroTag: "community_chat_fab",
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              onPressed: () {
                context.push('/post/create?communityId=${widget.communityId}');
              },
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildPostsView() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 投稿一覧（チャット風）
          Expanded(
            child: _communityPosts.isEmpty
                ? NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      // 最下部に到達したときにリフレッシュ
                      if (scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 50) {
                        if (scrollInfo is ScrollEndNotification) {
                          _refreshCommunityPosts();
                        }
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Center(
                          child: _isRefreshing
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      '更新中...',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble_outline,
                                        size: 64, color: AppColors.textHint),
                                    SizedBox(height: 16),
                                    Text(
                                      'まだコミュニティ内で投稿がありません\n最初の投稿をしてみましょう！',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                    ),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        // 最下部に到達したときにリフレッシュ
                        if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 50) {
                          if (scrollInfo is ScrollEndNotification) {
                            _refreshCommunityPosts();
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _communityPosts.length +
                            1, // +1 for refresh indicator
                        itemBuilder: (context, index) {
                          if (index == _communityPosts.length) {
                            // 最下部にリフレッシュインジケーターを表示
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _isRefreshing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : const SizedBox(height: 16), // 空のスペース
                              ),
                            );
                          }
                          final post = _communityPosts[index];
                          return _buildChatBubble(post);
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(PostModel post) {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    final isOwnMessage = currentUser != null && post.userId == currentUser.id;

    return Column(
      children: [
        // 日付ヘッダー（新しい日付の場合のみ表示）
        if (_shouldShowDateHeader(post, _communityPosts.indexOf(post)))
          _buildDateHeader(post.createdAt),

        ChatBubbleWidget(
          post: post,
          isOwnMessage: isOwnMessage,
          showLikeButton: true, // コミュニティチャットではハートボタンを表示
          onTap: () {
            // コミュニティ投稿の詳細画面に遷移する際に、戻り先をコミュニティ画面に指定
            context.push('/post/${post.id}', extra: {
              'post': post,
              'fromCommunity': widget.communityId,
            });
          },
          onDelete: isOwnMessage ? () => _showDeleteConfirmation(post) : null,
        ),
      ],
    );
  }

  // 日付ヘッダーを表示するかどうかを判定
  bool _shouldShowDateHeader(PostModel currentPost, int currentIndex) {
    if (currentIndex == 0) return true;

    final previousPost = _communityPosts[currentIndex - 1];
    final currentDate = DateTime(
      currentPost.createdAt.year,
      currentPost.createdAt.month,
      currentPost.createdAt.day,
    );
    final previousDate = DateTime(
      previousPost.createdAt.year,
      previousPost.createdAt.month,
      previousPost.createdAt.day,
    );

    return !currentDate.isAtSameMomentAs(previousDate);
  }

  // 日付ヘッダーウィジェット
  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final postDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (postDate.isAtSameMomentAs(today)) {
      dateText = '今日';
    } else if (postDate.isAtSameMomentAs(yesterday)) {
      dateText = '昨日';
    } else {
      dateText = '${date.month}月${date.day}日';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dateText,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
        ],
      ),
    );
  }

  Widget _buildJoinPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCommunityImage(_community!.imageUrl, radius: 200),
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
                onPressed:
                    _canJoin() && !_hasRequestedJoin ? _joinCommunity : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      _hasRequestedJoin ? AppColors.surfaceVariant : null,
                ),
                child: Text(_hasRequestedJoin
                    ? '参加申請済み'
                    : (_community!.isPrivate ? '参加申請' : '参加')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canJoin() {
    if (_community == null) return false;
    return _community!.memberIds.length < 8; // 上限8人
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
        setState(() {
          _hasRequestedJoin = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('参加申請を送信しました')),
        );
      }
    } else {
      // オープンの場合は直接参加
      success = await communityProvider.joinCommunity(widget.communityId,
          userId: currentUser.id);
      if (success && mounted) {
        // ユーザー情報を更新
        await userProvider.refreshCurrentUser();

        // 最新のコミュニティ情報を取得
        final updatedCommunity =
            await communityProvider.getCommunity(widget.communityId);
        if (updatedCommunity != null) {
          setState(() {
            _isJoined = true;
            _community = updatedCommunity;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コミュニティに参加しました')),
        );

        // 参加後に投稿を読み込み
        await _loadCommunityPosts();
      }
    }
  }

  void _showMembersDialog() {
    // _isLeaderの値を再計算
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    final isCurrentUserLeader = currentUser != null &&
        _community != null &&
        currentUser.id == _community!.leaderId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Text('メンバー一覧'),
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
          height: 500,
          child: Column(
            children: [
              // 招待ボタン（リーダーのみ表示）
              if (isCurrentUserLeader) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // ダイアログを閉じる
                      _showInviteDialog(); // 招待ダイアログを表示
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('新しいメンバーを招待'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // メンバー一覧
              Expanded(
                child: FutureBuilder<List<UserModel>>(
                  future: _loadMemberDetails(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
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

                        return GestureDetector(
                          onTap: () {
                            // ユーザープロフィール画面に遷移
                            context.go('/profile/${member.id}');
                          },
                          child: Card(
                            color: Colors.white,
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
                              trailing: !isLeader && isCurrentUserLeader
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.admin_panel_settings,
                                              color: AppColors.primary),
                                          onPressed: () =>
                                              _transferLeadership(member.id),
                                          tooltip: 'リーダーに任命',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle,
                                              color: Colors.black),
                                          onPressed: () =>
                                              _removeMember(member.id),
                                          tooltip: 'メンバーを削除',
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
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

    // 全メンバーIDを処理（自分も含む）
    for (final memberId in _community!.memberIds) {
      try {
        final user = await userProvider.getUserById(memberId);
        if (user != null) {
          members.add(user);
        }
      } catch (e) {
        print('メンバー情報取得エラー: $e');
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

    // リーダーを最初に、その後は参加日順にソート
    members.sort((a, b) {
      final aIsLeader = a.id == _community!.leaderId;
      final bIsLeader = b.id == _community!.leaderId;

      if (aIsLeader && !bIsLeader) return -1;
      if (!aIsLeader && bIsLeader) return 1;

      return 0; // 同じ権限の場合は元の順序を保持
    });

    return members;
  }

  Future<void> _removeMember(String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('メンバー削除'),
        content: const Text('このメンバーをコミュニティから削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
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
        backgroundColor: Colors.white,
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
          _isLeader = false; // 自分はもうリーダーではない
        });
        Navigator.pop(context); // メンバー管理ダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リーダーを移譲しました')),
        );
      }
    }
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

  // 削除確認ダイアログを表示
  void _showDeleteConfirmation(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
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

  // 招待ダイアログを表示
  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('コミュニティに招待'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('URLを生成してコミュニティに招待しましょう'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final communityProvider = context.read<CommunityProvider>();
                final inviteUrl = await communityProvider
                    .generateInviteUrl(widget.communityId);

                if (inviteUrl != null) {
                  Navigator.of(context).pop();
                  _showInviteUrlDialog(inviteUrl);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('招待URL生成に失敗しました')),
                  );
                }
              },
              child: const Text('招待URLを生成'),
            ),
          ],
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

  // 招待URLダイアログを表示
  void _showInviteUrlDialog(String inviteUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('招待URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('以下のURLを共有してコミュニティに招待しましょう：'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                inviteUrl,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URLをクリップボードにコピーしました')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('URLをコピー'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final shareText = 'コミュニティに参加しませんか？\n\n'
                          'コミュニティ名: ${_community?.name ?? 'コミュニティ'}\n'
                          '招待URL: $inviteUrl\n\n'
                          'URLをタップしてアプリで開いてください！';

                      await Clipboard.setData(ClipboardData(text: shareText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('招待内容をクリップボードにコピーしました')),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('招待内容をコピー'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• 有効期限: 7日間\n'
              '• 使用回数: 最大10回まで\n'
              '• URLをタップするとアプリが開きます',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
