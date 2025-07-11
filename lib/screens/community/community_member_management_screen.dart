import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/community_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/community_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/wave_loading_widget.dart';

class CommunityMemberManagementScreen extends StatefulWidget {
  final String communityId;

  const CommunityMemberManagementScreen({
    super.key,
    required this.communityId,
  });

  @override
  State<CommunityMemberManagementScreen> createState() =>
      _CommunityMemberManagementScreenState();
}

class _CommunityMemberManagementScreenState
    extends State<CommunityMemberManagementScreen> {
  final CommunityService _communityService = CommunityService();
  CommunityModel? _community;
  bool _isLoading = true;
  String? _inviteCode;
  bool _isGeneratingInvite = false;

  @override
  void initState() {
    super.initState();
    _loadCommunityData();
  }

  Future<void> _loadCommunityData() async {
    try {
      final community =
          await _communityService.getCommunity(widget.communityId);
      setState(() {
        _community = community;
        _inviteCode = community?.inviteCode;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  Future<void> _generateInviteCode() async {
    setState(() {
      _isGeneratingInvite = true;
    });

    try {
      final code =
          await _communityService.generateInviteCode(widget.communityId);
      setState(() {
        _inviteCode = code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('招待コードを生成しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('招待コード生成に失敗しました: $e')),
      );
    } finally {
      setState(() {
        _isGeneratingInvite = false;
      });
    }
  }

  Future<void> _copyInviteCode() async {
    if (_inviteCode != null) {
      await Clipboard.setData(ClipboardData(text: _inviteCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('招待コードをコピーしました')),
      );
    }
  }

  Future<void> _removeMember(String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メンバーを削除'),
        content: const Text('このメンバーをコミュニティから削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await _communityService.removeMember(widget.communityId, memberId);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('メンバーを削除しました')),
          );
          _loadCommunityData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('メンバーの削除に失敗しました')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  Future<void> _toggleSuccessorCandidate(
      String memberId, bool isCandidate) async {
    try {
      bool success;
      if (isCandidate) {
        success = await _communityService.removeSuccessorCandidate(
            widget.communityId, memberId);
      } else {
        success = await _communityService.addSuccessorCandidate(
            widget.communityId, memberId);
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCandidate ? '後継者候補から削除しました' : '後継者候補に追加しました'),
          ),
        );
        _loadCommunityData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作に失敗しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('メンバー管理'),
        ),
        body: const Center(
          child: WaveLoadingWidget(
            size: 80,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_community == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('メンバー管理'),
        ),
        body: const Center(
          child: Text('コミュニティが見つかりません'),
        ),
      );
    }

    final currentUser = context.watch<UserProvider>().currentUser;
    final isLeader =
        currentUser != null && _community!.isLeader(currentUser.id);

    if (!isLeader) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('メンバー管理'),
        ),
        body: const Center(
          child: Text('この機能を使用する権限がありません'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバー管理'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 招待セクション
            _buildInviteSection(),
            const SizedBox(height: 24),

            // メンバー一覧
            _buildMembersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '招待管理',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_inviteCode != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '現在の招待コード',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _inviteCode!,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _copyInviteCode,
                      icon: const Icon(Icons.copy),
                      tooltip: 'コピー',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingInvite ? null : _generateInviteCode,
                    icon: _isGeneratingInvite
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_link),
                    label: Text(_inviteCode == null ? '招待コードを生成' : '新しいコードを生成'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '招待コードは7日間有効で、最大10回まで使用できます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'メンバー一覧',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '${_community!.memberCount}/${_community!.maxMembers}人',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // memberIdsから全メンバーを表示（自分も含む）
            FutureBuilder<List<UserModel>>(
              future: _loadAllMembers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('メンバー情報を取得できませんでした'),
                  );
                }

                final members = snapshot.data!;
                return Column(
                  children: members.map((user) {
                    // CommunityMemberオブジェクトを作成または取得
                    final existingMember = _community!.getMember(user.id);
                    final member = existingMember ??
                        CommunityMember(
                          userId: user.id,
                          role: _community!.isLeader(user.id)
                              ? CommunityRole.leader
                              : CommunityRole.member,
                          joinedAt: DateTime.now(),
                          lastActive: DateTime.now(),
                        );
                    return _buildMemberItem(member, user: user);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<UserModel>> _loadAllMembers() async {
    final userProvider = context.read<UserProvider>();
    final List<UserModel> members = [];

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

    // 参加日順にソート（リーダーを最初に）
    members.sort((a, b) {
      final aIsLeader = _community!.isLeader(a.id);
      final bIsLeader = _community!.isLeader(b.id);

      if (aIsLeader && !bIsLeader) return -1;
      if (!aIsLeader && bIsLeader) return 1;

      // 両方ともリーダーでない場合は参加日順
      final aMember = _community!.getMember(a.id);
      final bMember = _community!.getMember(b.id);

      if (aMember != null && bMember != null) {
        return aMember.joinedAt.compareTo(bMember.joinedAt);
      }

      return 0;
    });

    return members;
  }

  Widget _buildMemberItem(CommunityMember member, {UserModel? user}) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // 渡されたuserを使用、なければFutureBuilderで取得
        if (user != null) {
          return _buildMemberItemContent(
              member, user, userProvider.currentUser);
        }

        return FutureBuilder<UserModel?>(
          future: userProvider.getUserById(member.userId),
          builder: (context, snapshot) {
            final userData = snapshot.data;
            if (userData == null) {
              return const SizedBox.shrink();
            }
            return _buildMemberItemContent(
                member, userData, userProvider.currentUser);
          },
        );
      },
    );
  }

  Widget _buildMemberItemContent(
      CommunityMember member, UserModel user, UserModel? currentUser) {
    final isLeader = member.role == CommunityRole.leader;
    final isSuccessorCandidate =
        _community!.isSuccessorCandidate(member.userId);
    final isCurrentUser = currentUser?.id == member.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLeader
            ? AppColors.primary.withOpacity(0.1)
            : isCurrentUser
                ? AppColors.accent.withOpacity(0.1)
                : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLeader
              ? AppColors.primary
              : isCurrentUser
                  ? AppColors.accent
                  : AppColors.divider,
          width: isLeader || isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // アバター
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: user.profileImageUrl != null
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              if (member.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // ユーザー情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.nickname ?? user.displayName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '自分',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isLeader)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'リーダー',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isSuccessorCandidate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.completed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '後継者候補',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '参加日: ${_formatDate(member.joinedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                if (member.bio != null && member.bio!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    member.bio!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // アクションボタン（自分以外のメンバーに対してのみ表示）
          if (!isLeader && !isCurrentUser) ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'successor':
                    _toggleSuccessorCandidate(
                        member.userId, isSuccessorCandidate);
                    break;
                  case 'remove':
                    _removeMember(member.userId);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'successor',
                  child: Row(
                    children: [
                      Icon(
                        isSuccessorCandidate
                            ? Icons.remove_circle
                            : Icons.add_circle,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(isSuccessorCandidate ? '後継者候補から削除' : '後継者候補に追加'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline,
                          size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('削除', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
