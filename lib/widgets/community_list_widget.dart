import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/community_model.dart';
import '../providers/community_provider.dart';
import '../constants/app_colors.dart';

class CommunityListWidget extends StatefulWidget {
  const CommunityListWidget({super.key});

  @override
  State<CommunityListWidget> createState() => _CommunityListWidgetState();
}

class _CommunityListWidgetState extends State<CommunityListWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        // コミュニティ一覧
        Expanded(
          child: Consumer<CommunityProvider>(
            builder: (context, communityProvider, child) {
              final communities =
                  _getFilteredCommunities(communityProvider.joinedCommunities);

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
                            ? '参加しているコミュニティはありません'
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
    if (_searchQuery.isEmpty) {
      return communities;
    }

    return communities.where((community) {
      return community.name.toLowerCase().contains(_searchQuery) ||
          (community.description?.toLowerCase().contains(_searchQuery) ??
              false);
    }).toList();
  }

  Widget _buildCommunityCard(CommunityModel community) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            community.name.isNotEmpty ? community.name[0].toUpperCase() : 'C',
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          community.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (community.description != null) ...[
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
                  '${community.memberCount}人',
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
          context.go('/community/${community.id}');
        },
      ),
    );
  }
}
