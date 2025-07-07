import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/community_model.dart';
import '../providers/community_provider.dart';
import '../constants/app_colors.dart';
import '../providers/user_provider.dart';

class CommunityListWidget extends StatefulWidget {
  final List<CommunityModel>? communities;
  final Function(CommunityModel)? onCommunityTap;
  final String? searchQuery;

  const CommunityListWidget({
    super.key,
    this.communities,
    this.onCommunityTap,
    this.searchQuery,
  });

  @override
  State<CommunityListWidget> createState() => _CommunityListWidgetState();
}

class _CommunityListWidgetState extends State<CommunityListWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchQuery ?? '';
    _searchController.text = _searchQuery;

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
    if (widget.searchQuery != oldWidget.searchQuery) {
      _searchQuery = widget.searchQuery ?? '';
      _searchController.text = _searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // HomeScreenから検索バーが提供される場合は表示しない
        if (widget.searchQuery == null) ...[
          // 検索バー
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'コミュニティを検索...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
        ],
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
              final communities = _getFilteredCommunities(
                widget.communities ?? communityProvider.userCommunities,
              );

              if (communityProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (communities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty
                            ? Icons.group_outlined
                            : Icons.search_off,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? '参加しているコミュニティがありません'
                            : '検索結果が見つかりませんでした',
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

  List<CommunityModel> _getFilteredCommunities(
      List<CommunityModel> communities) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) {
      return communities;
    }

    return communities.where((community) {
      return community.name.toLowerCase().contains(query) ||
          (community.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Widget _buildCommunityTile(CommunityModel community) {
    return GestureDetector(
      onTap: () {
        if (widget.onCommunityTap != null) {
          widget.onCommunityTap!(community);
        } else {
          context.go('/community/${community.id}');
        }
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (community.description != null &&
                        community.description!.isNotEmpty) ...[
                      Text(
                        community.description!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const Spacer(),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${community.memberIds.length}人',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
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
