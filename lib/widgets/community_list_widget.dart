import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/community_model.dart';
import '../providers/community_provider.dart';
import '../constants/app_colors.dart';
import '../providers/user_provider.dart';
import '../widgets/leaf_loading_widget.dart';
import '../widgets/user_avatar.dart';

class CommunityListWidget extends StatefulWidget {
  final List<CommunityModel>? communities;
  final Function(CommunityModel)? onCommunityTap;

  const CommunityListWidget({
    super.key,
    this.communities,
    this.onCommunityTap,
  });

  @override
  State<CommunityListWidget> createState() => _CommunityListWidgetState();
}

class _CommunityListWidgetState extends State<CommunityListWidget> {
  @override
  void initState() {
    super.initState();

    // コミュニティ一覧を初期読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.communities == null) {
        final userProvider = context.read<UserProvider>();
        final currentUser = userProvider.currentUser;
        if (currentUser != null) {
          context.read<CommunityProvider>().getUserCommunities(currentUser.id);
        }
      }
    });
  }

  @override
  void didUpdateWidget(CommunityListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 検索機能を削除したため、このメソッドは空にする
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 検索バーを削除
        // 所属コミュニティのセクションヘッダー
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '所属コミュニティ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        // コミュニティ一覧
        Expanded(
          child: Consumer<CommunityProvider>(
            builder: (context, communityProvider, child) {
              final communities =
                  widget.communities ?? communityProvider.userCommunities;

              if (communityProvider.isLoading && communities.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LeafLoadingWidget(
                        size: 50,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        '読み込み中...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (communities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '参加しているコミュニティがありません',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2列表示
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1, // 正方形
                ),
                itemCount: communities.length,
                itemBuilder: (context, index) {
                  return _buildCommunityTile(communities[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityTile(CommunityModel community) {
    return GestureDetector(
      onTap: () {
        if (widget.onCommunityTap != null) {
          widget.onCommunityTap!(community);
        } else {
          context.push('/community/${community.id}');
        }
      },
      onLongPress: () {
        _showCommunityOptionsDialog(community);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // コミュニティ画像
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: _buildCommunityTileImage(community.imageUrl),
                ),
              ),
            ),
            // コミュニティ情報
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        community.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (community.description != null &&
                        community.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          community.description!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${community.memberIds.length}人',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  void _showCommunityOptionsDialog(CommunityModel community) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(community.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('詳細を見る'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/community/${community.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.black),
              title: const Text('脱退', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.of(context).pop();
                _showLeaveCommunityDialog(community);
              },
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

  void _showLeaveCommunityDialog(CommunityModel community) {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    final isLeader = community.leaderId == currentUser?.id;
    final memberCount = community.memberIds.length;

    String message = '「${community.name}」から脱退しますか？';
    String warning = '';

    if (isLeader) {
      if (memberCount == 1) {
        warning = '⚠️ あなたがリーダーで最後のメンバーです。\n脱退するとコミュニティは自動的に削除されます。';
      } else {
        warning = '⚠️ あなたはリーダーです。\n脱退すると他のメンバーが新しいリーダーになります。';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _leaveCommunity(community);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
            ),
            child: const Text('脱退'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveCommunity(CommunityModel community) async {
    final userProvider = context.read<UserProvider>();
    final communityProvider = context.read<CommunityProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) return;

    final success = await communityProvider.leaveCommunity(
      community.id,
      userId: currentUser.id,
    );

    if (success && mounted) {
      // UserProviderの現在のユーザー情報を更新
      await userProvider.refreshCurrentUser();

      // コミュニティ一覧を再読み込み
      await communityProvider.getUserCommunities(currentUser.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${community.name}」から脱退しました')),
      );
    }
  }

  // コミュニティタイル用画像を表示するWidgetを構築
  Widget _buildCommunityTileImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.primary,
        child: const Icon(
          Icons.group,
          size: 40,
          color: AppColors.textOnPrimary,
        ),
      );
    }

    try {
      return Container(
        width: double.infinity,
        height: double.infinity,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.primary,
              child: const Icon(
                Icons.group,
                size: 40,
                color: AppColors.textOnPrimary,
              ),
            );
          },
        ),
      );
    } catch (e) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.primary,
        child: const Icon(
          Icons.group,
          size: 40,
          color: AppColors.textOnPrimary,
        ),
      );
    }
  }
}
