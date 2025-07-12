import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/community_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import '../../widgets/wave_loading_widget.dart';

class CommunityScreen extends StatefulWidget {
  final String? searchQuery;

  const CommunityScreen({super.key, this.searchQuery});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCommunities();
    });
  }

  @override
  void didUpdateWidget(CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        _performSearch(widget.searchQuery!);
      }
    }
  }

  Future<void> _loadCommunities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final communityProvider = context.read<CommunityProvider>();
      final currentUser = userProvider.currentUser;

      if (currentUser != null) {
        await communityProvider.getUserCommunities(currentUser.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('コミュニティの読み込みに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    final communityProvider = context.read<CommunityProvider>();
    await communityProvider.searchCommunities(query: query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: WaveLoadingWidget())
          : _buildContent(),
      floatingActionButton: FloatingActionButton(
        heroTag: "community_screen_fab",
        onPressed: () {
          context.push('/community/create');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    return Consumer2<CommunityProvider, UserProvider>(
      builder: (context, communityProvider, userProvider, child) {
        final currentUser = userProvider.currentUser;
        if (currentUser == null) {
          return const Center(child: Text('ログインしてください'));
        }

        List<CommunityModel> displayCommunities;
        String sectionTitle;

        final searchQuery = widget.searchQuery ?? '';

        if (searchQuery.isEmpty) {
          displayCommunities = communityProvider.userCommunities;
          sectionTitle = '所属コミュニティ';
        } else {
          displayCommunities = communityProvider.searchResults;
          sectionTitle = '検索結果';
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 16, bottom: 8),
                child: Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              displayCommunities.isEmpty
                  ? SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildEmptyState(),
                    )
                  : _buildCommunityGrid(displayCommunities),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final searchQuery = widget.searchQuery ?? '';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searchQuery.isEmpty ? Icons.group_outlined : Icons.search_off,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty ? '参加しているコミュニティがありません' : '検索結果が見つかりませんでした',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          if (searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/community/create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: const Text('コミュニティを作成'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommunityGrid(List<CommunityModel> communities) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: communities.length,
        itemBuilder: (context, index) {
          return _buildCommunityTile(communities[index]);
        },
      ),
    );
  }

  Widget _buildCommunityTile(CommunityModel community) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final currentUser = userProvider.currentUser;
        final isJoined =
            currentUser != null && community.memberIds.contains(currentUser.id);

        return GestureDetector(
          onTap: () async {
            if (isJoined) {
              // 参加済みの場合はコミュニティ画面に遷移
              context.push('/community/${community.id}');
            } else {
              // 未参加の場合の処理を検索状態によって分ける
              final isSearching = widget.searchQuery?.isNotEmpty ?? false;

              if (isSearching) {
                // 検索結果の場合は詳細画面（参加画面）に遷移
                context.push('/community/${community.id}');
              } else {
                // 所属コミュニティ表示の場合は直接参加（従来の動作）
                await _joinCommunity(community);
              }
            }
          },
          onLongPress: () {
            if (isJoined) {
              _showCommunityOptionsDialog(community);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background, // 背景色を統一
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.divider.withOpacity(0.3), // 境界線を薄く
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // コミュニティ画像
                Expanded(
                  flex: 2,
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
                      child: _buildCommunityImage(community.imageUrl),
                    ),
                  ),
                ),
                // コミュニティ情報
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          community.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (community.description != null &&
                            community.description!.isNotEmpty) ...[
                          Expanded(
                            child: Text(
                              community.description!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else ...[
                          const Expanded(child: SizedBox()),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.people,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${community.memberIds.length}人',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            if (!isJoined &&
                                (widget.searchQuery?.isNotEmpty ?? false))
                              const Icon(
                                Icons.add_circle_outline,
                                size: 18,
                                color: AppColors.primary,
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
      },
    );
  }

  Widget _buildCommunityImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.primary.withOpacity(0.1),
        child: const Icon(
          Icons.group,
          size: 160,
          color: AppColors.primary,
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.primary.withOpacity(0.1),
            child: const Icon(
              Icons.group,
              size: 160,
              color: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  Future<void> _joinCommunity(CommunityModel community) async {
    try {
      final userProvider = context.read<UserProvider>();
      final communityProvider = context.read<CommunityProvider>();
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログインしてください')),
        );
        return;
      }

      final success = await communityProvider.joinCommunity(
        community.id,
        userId: currentUser.id,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${community.name}に参加しました')),
        );

        // ユーザー情報を更新
        await userProvider.refreshCurrentUser();

        // ユーザーのコミュニティ一覧を更新
        await communityProvider.getUserCommunities(currentUser.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('参加に失敗しました: $e')),
        );
      }
    }
  }

  void _showCommunityOptionsDialog(CommunityModel community) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('脱退', style: TextStyle(color: Colors.red)),
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
        );
      },
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
              foregroundColor: Colors.red,
            ),
            child: const Text('脱退'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveCommunity(CommunityModel community) async {
    try {
      final userProvider = context.read<UserProvider>();
      final communityProvider = context.read<CommunityProvider>();
      final currentUser = userProvider.currentUser;

      if (currentUser == null) return;

      final success = await communityProvider.leaveCommunity(
        community.id,
        userId: currentUser.id,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${community.name}」から脱退しました')),
        );

        await communityProvider.getUserCommunities(currentUser.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('脱退に失敗しました: $e')),
        );
      }
    }
  }

  void _showCreateCommunityDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool requiresApproval = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('コミュニティを作成'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'コミュニティ名',
                        hintText: '例: 朝活コミュニティ',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 50,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: '説明（任意）',
                        hintText: 'コミュニティの説明を入力してください',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      maxLength: 200,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('承認制'),
                      subtitle: const Text('新しいメンバーの参加に承認が必要'),
                      value: requiresApproval,
                      onChanged: (value) {
                        setState(() {
                          requiresApproval = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('コミュニティ名を入力してください')),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _createCommunity(
                      nameController.text.trim(),
                      descriptionController.text.trim(),
                      requiresApproval,
                    );
                  },
                  child: const Text('作成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createCommunity(
    String name,
    String description,
    bool requiresApproval,
  ) async {
    try {
      final userProvider = context.read<UserProvider>();
      final communityProvider = context.read<CommunityProvider>();
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログインしてください')),
        );
        return;
      }

      final success = await communityProvider.createCommunity(
        name: name,
        description: description,
        userId: currentUser.id,
        requiresApproval: requiresApproval,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コミュニティを作成しました')),
        );

        await communityProvider.getUserCommunities(currentUser.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('コミュニティの作成に失敗しました: $e')),
        );
      }
    }
  }
}
