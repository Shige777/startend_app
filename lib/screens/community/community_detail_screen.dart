import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/community_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';

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
  CommunityModel? _community;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    final communityProvider = context.read<CommunityProvider>();
    final community = await communityProvider.getCommunity(widget.communityId);

    if (mounted) {
      setState(() {
        _community = community;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_community == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('コミュニティ')),
        body: const Center(
          child: Text('コミュニティが見つかりませんでした'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_community!.name),
        actions: [
          if (_community!.isLeader(_getCurrentUserId()))
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // TODO: コミュニティ設定画面への遷移
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // コミュニティ情報
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // コミュニティ名とアイコン
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            _community!.name.isNotEmpty
                                ? _community!.name[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              color: AppColors.textOnPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                                _community!.genre,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 説明
                    if (_community!.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _community!.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 統計情報
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          context,
                          'メンバー',
                          '${_community!.memberCount}/${_community!.maxMembers}',
                        ),
                        _buildStatItem(
                          context,
                          '待機中',
                          _community!.pendingCount.toString(),
                        ),
                        _buildStatItem(
                          context,
                          'プライベート',
                          _community!.isPrivate ? 'はい' : 'いいえ',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 参加ボタン
                    _buildActionButton(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // メンバー一覧
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'メンバー (${_community!.memberCount})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _community!.memberIds.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final memberId = _community!.memberIds[index];
                        final isLeader = memberId == _community!.leaderId;

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(memberId[0].toUpperCase()),
                          ),
                          title: Text('ユーザー $memberId'), // TODO: 実際のユーザー名を取得
                          trailing: isLeader
                              ? Chip(
                                  label: const Text('リーダー'),
                                  backgroundColor: AppColors.primary,
                                  labelStyle: const TextStyle(
                                    color: AppColors.textOnPrimary,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    final currentUserId = _getCurrentUserId();
    final isMember = _community!.isMember(currentUserId);
    final hasPendingRequest = _community!.hasPendingRequest(currentUserId);
    final canJoin = _community!.canJoin(currentUserId);

    if (isMember) {
      if (_community!.isLeader(currentUserId)) {
        return ElevatedButton.icon(
          onPressed: null, // リーダーは脱退できない
          icon: const Icon(Icons.star),
          label: const Text('リーダー'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
          ),
        );
      } else {
        return OutlinedButton.icon(
          onPressed: _leaveCommunity,
          icon: const Icon(Icons.exit_to_app),
          label: const Text('コミュニティを脱退'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
        );
      }
    } else if (hasPendingRequest) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_empty),
        label: const Text('承認待ち'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceVariant,
          foregroundColor: AppColors.textSecondary,
        ),
      );
    } else if (canJoin) {
      return ElevatedButton.icon(
        onPressed: _joinCommunity,
        icon: const Icon(Icons.group_add),
        label: Text(_community!.isPrivate ? '参加申請' : 'コミュニティに参加'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.block),
        label: const Text('満員'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceVariant,
          foregroundColor: AppColors.textSecondary,
        ),
      );
    }
  }

  String _getCurrentUserId() {
    // TODO: 実際の現在のユーザーIDを取得
    return context.read<UserProvider>().currentUser?.id ?? 'dummy_user';
  }

  Future<void> _joinCommunity() async {
    final communityProvider = context.read<CommunityProvider>();
    final currentUserId = _getCurrentUserId();

    final success = await communityProvider.requestJoinCommunity(
      _community!.id,
      currentUserId,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _community!.isPrivate ? '参加申請を送信しました' : 'コミュニティに参加しました',
            ),
          ),
        );
        _loadCommunity(); // 状態を更新
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityProvider.errorMessage ?? '参加に失敗しました',
            ),
          ),
        );
      }
    }
  }

  Future<void> _leaveCommunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('コミュニティを脱退'),
        content: const Text('本当にこのコミュニティを脱退しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('脱退'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final communityProvider = context.read<CommunityProvider>();
      final currentUserId = _getCurrentUserId();

      final success = await communityProvider.leaveCommunity(
        _community!.id,
        currentUserId,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('コミュニティを脱退しました')),
          );
          context.pop(); // 詳細画面を閉じる
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                communityProvider.errorMessage ?? '脱退に失敗しました',
              ),
            ),
          );
        }
      }
    }
  }
}
