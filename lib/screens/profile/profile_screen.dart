import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/post_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/post_model.dart';
import '../../widgets/post_grid_widget.dart';
import '../../widgets/post_list_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGridView = true;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2つのタブに変更
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('軌跡'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.go('/profile/settings');
            },
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final user = userProvider.currentUser;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // プロフィール情報
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                color: AppColors.surface,
                child: Column(
                  children: [
                    // プロフィール画像と基本情報
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: user.profileImageUrl != null
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          child: user.profileImageUrl == null
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (user.bio != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  user.bio!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 統計情報
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(context, '投稿', '0'), // TODO: 実際の投稿数を取得
                        _buildStatItem(
                          context,
                          'フォロワー',
                          user.followersCount.toString(),
                        ),
                        _buildStatItem(
                          context,
                          'フォロー中',
                          user.followingCount.toString(),
                        ),
                        _buildStatItem(
                          context,
                          'コミュニティ',
                          user.communitiesCount.toString(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // タブバー（集中・進行中をまとめて「進行中」、「過去」の2つに変更）
              Container(
                color: AppColors.surface,
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '進行中'),
                    Tab(text: '過去'),
                  ],
                ),
              ),

              // タブビュー
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostSection(context, 'active'), // 集中+進行中
                    _buildPostSection(context, 'completed'), // 過去
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _handleNavigation(context, index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '投稿'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: '軌跡'),
        ],
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        // 投稿画面
        context.go('/home');
        break;
      case 1:
        // 軌跡画面 (現在の画面)
        break;
    }
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPostSection(BuildContext context, String category) {
    return Consumer<PostProvider>(
      builder: (context, postProvider, child) {
        List<PostModel> posts;

        if (category == 'active') {
          // 集中と進行中をまとめて表示
          final allPosts = postProvider.followingPosts;
          posts = allPosts.where((post) {
            final status = post.status;
            return status == PostStatus.concentration ||
                status == PostStatus.inProgress;
          }).toList();

          // 集中を上に、進行中を下に並べる
          posts.sort((a, b) {
            if (a.status == PostStatus.concentration &&
                b.status != PostStatus.concentration) {
              return -1;
            } else if (a.status != PostStatus.concentration &&
                b.status == PostStatus.concentration) {
              return 1;
            }
            return b.createdAt.compareTo(a.createdAt); // 新しい順
          });
        } else {
          // 完了した投稿
          final allPosts = postProvider.followingPosts;
          posts = allPosts.where((post) {
            return post.status == PostStatus.completed;
          }).toList();
        }

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getCategoryIcon(category),
                  size: 64,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 16),
                Text(
                  _getCategoryEmptyMessage(category),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          );
        }

        return _isGridView
            ? PostGridWidget(posts: posts)
            : PostListWidget(type: PostListType.user, posts: posts);
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'active':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.timeline;
    }
  }

  String _getCategoryEmptyMessage(String category) {
    switch (category) {
      case 'active':
        return '進行中の投稿はありません';
      case 'completed':
        return '完了した投稿はありません';
      default:
        return '投稿はありません';
    }
  }
}
