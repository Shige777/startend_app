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

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: communities.length,
                itemBuilder: (context, index) {
                  return _buildCommunityCard(communities[index]);
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

  Widget _buildCommunityCard(CommunityModel community) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _buildCommunityImage(community.imageUrl),
        title: Text(
          community.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (community.description != null &&
                community.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                community.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${community.memberIds.length}人',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.article,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'ジャンル: ${community.genre}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (widget.onCommunityTap != null) {
            widget.onCommunityTap!(community);
          } else {
            context.go('/community/${community.id}');
          }
        },
      ),
    );
  }

  // コミュニティ画像を表示するWidgetを構築
  Widget _buildCommunityImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Icon(
          Icons.group,
          color: AppColors.textOnPrimary,
        ),
      );
    }

    try {
      return CircleAvatar(
        backgroundImage: NetworkImage(imageUrl),
        backgroundColor: AppColors.primary,
        onBackgroundImageError: (exception, stackTrace) {
          // エラー時はアイコンを表示
        },
        child: null,
      );
    } catch (e) {
      return CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Icon(
          Icons.group,
          color: AppColors.textOnPrimary,
        ),
      );
    }
  }
}
