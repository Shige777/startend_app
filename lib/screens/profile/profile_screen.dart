import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../widgets/post_grid_widget.dart';
import '../../widgets/post_list_widget.dart';
import '../../widgets/post_card_widget.dart';
import '../../widgets/wave_loading_widget.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // 他のユーザーのプロフィールを表示する場合に使用
  final bool isOwnProfile; // 自分のプロフィールかどうかを明示的に指定

  const ProfileScreen({super.key, this.userId, this.isOwnProfile = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum TimePeriod { day, week, month, year, all }

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGridView = true;
  bool _hasLoadedPosts = false;
  UserModel? _profileUser; // 表示するユーザー情報
  TimePeriod _selectedPeriod = TimePeriod.all;

  // 画像URLがネットワークURLかローカルファイルパスかを判別
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // プロフィール画像を表示するWidgetを構築
  Widget _buildProfileImage(String? imageUrl) {
    if (imageUrl == null) {
      return const CircleAvatar(
        radius: 40,
        child: Icon(Icons.person, size: 40),
      );
    }

    if (_isNetworkUrl(imageUrl)) {
      // ネットワーク画像
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(imageUrl),
      );
    } else {
      // ローカルファイル
      if (kIsWeb) {
        // Webの場合はエラー表示
        return const CircleAvatar(
          radius: 40,
          child: Icon(Icons.error, size: 40),
        );
      } else {
        // モバイルの場合はFileImageを使用
        try {
          return CircleAvatar(
            radius: 40,
            backgroundImage: FileImage(File(imageUrl)),
          );
        } catch (e) {
          return const CircleAvatar(
            radius: 40,
            child: Icon(Icons.error, size: 40),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // ビルド完了後に非同期処理を実行
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    if (_hasLoadedPosts) return;

    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();

    try {
      if (widget.isOwnProfile) {
        // 自分のプロフィールの場合
        _profileUser = userProvider.currentUser;
        if (_profileUser != null) {
          if (kDebugMode) {
            print('軌跡画面: 自分の投稿を読み込み開始 - ${_profileUser!.id}');
          }
          await postProvider.getUserPosts(_profileUser!.id);
        }
      } else {
        // 他のユーザーのプロフィールの場合
        if (widget.userId != null) {
          _profileUser = await userProvider.getUser(widget.userId!);
          if (_profileUser != null) {
            if (kDebugMode) {
              print('他のユーザーのプロフィール: 投稿を読み込み開始 - ${_profileUser!.id}');
            }
            await postProvider.getUserPosts(_profileUser!.id);
          }
        }
      }

      setState(() {
        _hasLoadedPosts = true;
      });

      if (kDebugMode) {
        print('プロフィールデータの読み込み完了');
      }
    } catch (e) {
      if (kDebugMode) {
        print('プロフィールデータの読み込みエラー: $e');
      }
    }
  }

  // 期間フィルタ機能
  Map<String, List<PostModel>> _groupPostsByPeriod(List<PostModel> posts) {
    if (_selectedPeriod == TimePeriod.all) {
      return {'すべて': posts};
    }

    final Map<String, List<PostModel>> groupedPosts = {};

    for (final post in posts) {
      final postDate = post.createdAt;
      String groupKey;

      switch (_selectedPeriod) {
        case TimePeriod.day:
          groupKey = '${postDate.month}月${postDate.day}日';
          break;
        case TimePeriod.week:
          // 年の第何週かを計算
          final weekOfYear = _getWeekOfYear(postDate);
          groupKey = '${postDate.year}年第${weekOfYear}週';
          break;
        case TimePeriod.month:
          groupKey = '${postDate.year}年${postDate.month}月';
          break;
        case TimePeriod.year:
          groupKey = '${postDate.year}年';
          break;
        case TimePeriod.all:
          groupKey = 'すべて';
          break;
      }

      if (!groupedPosts.containsKey(groupKey)) {
        groupedPosts[groupKey] = [];
      }
      groupedPosts[groupKey]!.add(post);
    }

    // 期間順にソート
    final sortedKeys = groupedPosts.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final sortedGroupedPosts = <String, List<PostModel>>{};
    for (final key in sortedKeys) {
      sortedGroupedPosts[key] = groupedPosts[key]!;
    }

    return sortedGroupedPosts;
  }

  // 年の第何週かを計算するヘルパーメソッド
  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays + 1;
    return ((dayOfYear - 1) ~/ 7) + 1;
  }

  String _getPeriodText(TimePeriod period) {
    switch (period) {
      case TimePeriod.day:
        return '日';
      case TimePeriod.week:
        return '週';
      case TimePeriod.month:
        return '月';
      case TimePeriod.year:
        return '年';
      case TimePeriod.all:
        return 'すべて';
    }
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
        // 軌跡画面（自分のプロフィール）では戻るボタンを表示しない
        automaticallyImplyLeading: !widget.isOwnProfile,
        leading: !widget.isOwnProfile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              )
            : null,
        title: Text(widget.isOwnProfile
            ? '軌跡'
            : (_profileUser?.displayName ?? 'プロフィール')),
        actions: widget.isOwnProfile
            ? [
                PopupMenuButton<TimePeriod>(
                  icon: const Icon(Icons.date_range),
                  onSelected: (period) {
                    setState(() {
                      _selectedPeriod = period;
                    });
                  },
                  itemBuilder: (BuildContext context) => TimePeriod.values
                      .map((period) => PopupMenuItem<TimePeriod>(
                            value: period,
                            child: Row(
                              children: [
                                Icon(
                                  _selectedPeriod == period
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(_getPeriodText(period)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'logout') {
                      _showLogoutDialog();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text('ログアウト', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [
                PopupMenuButton<TimePeriod>(
                  icon: const Icon(Icons.date_range),
                  onSelected: (period) {
                    setState(() {
                      _selectedPeriod = period;
                    });
                  },
                  itemBuilder: (BuildContext context) => TimePeriod.values
                      .map((period) => PopupMenuItem<TimePeriod>(
                            value: period,
                            child: Row(
                              children: [
                                Icon(
                                  _selectedPeriod == period
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(_getPeriodText(period)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
              ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final user = _profileUser ?? userProvider.currentUser;

          if (user == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WaveLoadingWidget(
                    size: 80,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '読み込み中...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
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
                        _buildProfileImage(user.profileImageUrl),
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

                    // フォローボタン（他のユーザーのプロフィールの場合）
                    if (!widget.isOwnProfile) ...[
                      const SizedBox(height: 16),
                      Consumer<UserProvider>(
                        builder: (context, userProvider, child) {
                          final currentUser = userProvider.currentUser;

                          // 自分自身のプロフィールの場合はフォローボタンを表示しない
                          if (currentUser == null ||
                              currentUser.id == user.id) {
                            return const SizedBox.shrink();
                          }

                          final isFollowing =
                              currentUser.followingIds.contains(user.id);

                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  if (isFollowing) {
                                    // アンフォロー
                                    final success = await userProvider
                                        .unfollowUser(user.id);
                                    if (success && mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('フォローを解除しました')),
                                      );
                                      // プロフィールユーザー情報を更新
                                      final updatedUser =
                                          await userProvider.getUser(user.id);
                                      if (updatedUser != null) {
                                        setState(() {
                                          _profileUser = updatedUser;
                                        });
                                      }
                                    }
                                  } else {
                                    // フォロー
                                    final success =
                                        await userProvider.followUser(user.id);
                                    if (success && mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('フォローしました')),
                                      );
                                      // プロフィールユーザー情報を更新
                                      final updatedUser =
                                          await userProvider.getUser(user.id);
                                      if (updatedUser != null) {
                                        setState(() {
                                          _profileUser = updatedUser;
                                        });
                                      }
                                    }
                                  }

                                  // 現在のユーザー情報を再読み込み
                                  await userProvider.refreshCurrentUser();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('エラーが発生しました: $e')),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? AppColors.surfaceVariant
                                    : AppColors.primary,
                                foregroundColor: isFollowing
                                    ? AppColors.textPrimary
                                    : AppColors.textOnPrimary,
                              ),
                              child: Text(isFollowing ? 'フォロー中' : 'フォロー'),
                            ),
                          );
                        },
                      ),
                    ],

                    // 統計情報
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(context, '投稿',
                            user.postCount.toString()), // 実際の投稿数を表示
                        _buildStatItem(
                          context,
                          'フォロワー',
                          user.followersCount.toString(),
                          onTap: () {
                            context.go('/follow-list/${user.id}/followers');
                          },
                        ),
                        _buildStatItem(
                          context,
                          'フォロー中',
                          user.followingCount.toString(),
                          onTap: () {
                            context.go('/follow-list/${user.id}/following');
                          },
                        ),
                        _buildStatItem(
                          context,
                          'コミュニティ',
                          user.communitiesCount.toString(),
                          onTap: () {
                            context.go('/community-list/${user.id}');
                          },
                        ),
                      ],
                    ),

                    // プロフィール編集ボタン（自分のプロフィールの場合）
                    if (widget.isOwnProfile) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            context.go('/profile/settings');
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text('プロフィールを編集'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // タブバー（集中・進行中をまとめて「集中・進行中」、「過去」の2つに変更）
              Container(
                color: AppColors.surface,
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '集中・進行中'),
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
      // 他のユーザーのプロフィールの場合はナビゲーションバーを追加
      bottomNavigationBar: !widget.isOwnProfile
          ? BottomNavigationBar(
              currentIndex: 0, // 投稿タブを選択状態にする
              onTap: (index) {
                if (index == 0) {
                  context.go('/home');
                } else if (index == 1) {
                  context.go('/home?tab=1');
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: '投稿',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.trending_up),
                  label: '軌跡',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value,
      {VoidCallback? onTap}) {
    Widget content = Column(
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

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildPostSection(BuildContext context, String category) {
    return Consumer2<PostProvider, UserProvider>(
      builder: (context, postProvider, userProvider, child) {
        // プロフィールデータが読み込まれていない場合は読み込む
        if (!_hasLoadedPosts && _profileUser != null) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _loadProfileData();
          });
        }

        List<PostModel> posts;

        if (category == 'active') {
          // 集中と進行中をまとめて表示
          final allPosts = postProvider.userPosts;
          posts = allPosts.where((post) {
            // 軌跡画面では自分の投稿のみを表示
            if (widget.isOwnProfile) {
              final currentUser = userProvider.currentUser;
              if (currentUser != null && post.userId != currentUser.id) {
                return false;
              }
            } else {
              // 他のユーザーのプロフィールでは指定されたユーザーの投稿のみを表示
              if (_profileUser != null && post.userId != _profileUser!.id) {
                return false;
              }
            }

            final status = post.status;
            final now = DateTime.now();

            // 集中投稿は常に表示
            if (status == PostStatus.concentration) {
              return true;
            }

            // 進行中投稿は、終了予定時刻から24時間以内なら表示
            if (status == PostStatus.inProgress) {
              if (post.scheduledEndTime != null) {
                final hoursSinceScheduledEnd =
                    now.difference(post.scheduledEndTime!).inHours;
                return hoursSinceScheduledEnd <= 24;
              }
              return true; // 終了予定時刻が設定されていない場合は表示
            }

            return false;
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
          final allPosts = postProvider.userPosts;
          posts = allPosts.where((post) {
            // 軌跡画面では自分の投稿のみを表示
            if (widget.isOwnProfile) {
              final currentUser = userProvider.currentUser;
              if (currentUser != null && post.userId != currentUser.id) {
                return false;
              }
            } else {
              // 他のユーザーのプロフィールでは指定されたユーザーの投稿のみを表示
              if (_profileUser != null && post.userId != _profileUser!.id) {
                return false;
              }
            }

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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // 期間でグループ化
        final groupedPosts = _groupPostsByPeriod(posts);

        if (category == 'active') {
          // 集中と進行中を分けて表示（すべての期間をまとめて）
          final allPosts =
              groupedPosts.values.expand((posts) => posts).toList();
          final concentrationPosts = allPosts
              .where((post) => post.status == PostStatus.concentration)
              .toList();
          final inProgressPosts = allPosts
              .where((post) => post.status == PostStatus.inProgress)
              .toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 集中セクション（集中投稿がある場合のみ表示）
                if (concentrationPosts.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(
                      '集中',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  // 集中の投稿を表示
                  _isGridView
                      ? _buildPostGrid(concentrationPosts)
                      : _buildPostList(concentrationPosts),
                  const SizedBox(height: 24),
                ],

                // 進行中セクション
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    '進行中',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
                // 進行中の投稿を表示
                if (inProgressPosts.isNotEmpty) ...[
                  _isGridView
                      ? _buildPostGrid(inProgressPosts)
                      : _buildPostList(inProgressPosts),
                ] else ...[
                  // 進行中投稿がない場合の表示
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Center(
                      child: Text(
                        '進行中の投稿はありません',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          );
        } else {
          // 過去の投稿を期間別に表示
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in groupedPosts.entries) ...[
                  // 期間ラベル
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  // 投稿表示
                  _isGridView
                      ? _buildPostGrid(entry.value)
                      : _buildPostList(entry.value),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        }
      },
    );
  }

  // グリッド表示用のWidget（START/END画像を2つ並べて表示）
  Widget _buildPostGrid(List<PostModel> posts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return GestureDetector(
            onTap: () => context.go('/post/${post.id}', extra: {
              'post': post,
            }),
            onDoubleTap: () => _toggleLike(post),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: AppColors.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPostGridItem(post),
                    // リアクション数を右下に表示
                    if (post.likeCount > 0)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 12,
                                color: AppColors.flame,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                post.likeCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 投稿ステータスを左上に表示
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(post.status).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _getStatusIcon(post.status),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 投稿のグリッドアイテム（START/END画像を表示）
  Widget _buildPostGridItem(PostModel post) {
    // 完了した投稿の場合、START/END画像を並べて表示
    if (post.status == PostStatus.completed && post.endImageUrl != null) {
      return Row(
        children: [
          // START画像
          Expanded(
            child: post.imageUrl != null
                ? Image.network(
                    post.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.surface,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      );
                    },
                  )
                : Container(
                    color: AppColors.surface,
                    child: const Icon(
                      Icons.image,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ),
          ),
          // 区切り線
          Container(
            width: 1,
            color: AppColors.divider,
          ),
          // END画像
          Expanded(
            child: Image.network(
              post.endImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.surface,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                );
              },
            ),
          ),
        ],
      );
    } else {
      // 進行中や集中の投稿の場合、START画像のみ表示
      return post.imageUrl != null
          ? Image.network(
              post.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.surface,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            )
          : Container(
              color: AppColors.surface,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.image,
                    color: AppColors.textSecondary,
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
    }
  }

  // リスト表示用のWidget（PostCardWidgetを使用）
  Widget _buildPostList(List<PostModel> posts) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: posts.map((post) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: PostCardWidget(
            post: post,
            onTap: () => context.go('/post/${post.id}', extra: {
              'post': post,
            }),
            showActions: true, // アクションボタンを表示してリアクション可能に
          ),
        );
      }).toList(),
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ログアウト'),
          content: const Text('本当にログアウトしますか？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('ログアウト'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();

      await authProvider.signOut();
      userProvider.clearCurrentUser();

      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ログアウトに失敗しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 投稿ステータスの色を取得
  Color _getStatusColor(PostStatus status) {
    switch (status) {
      case PostStatus.concentration:
        return AppColors.primary;
      case PostStatus.inProgress:
        return AppColors.inProgress;
      case PostStatus.completed:
        return AppColors.completed;
      case PostStatus.overdue:
        return AppColors.error;
    }
  }

  // 投稿ステータスのアイコンを取得
  Widget _getStatusIcon(PostStatus status) {
    switch (status) {
      case PostStatus.concentration:
        return const Icon(
          Icons.flash_on,
          size: 12,
          color: Colors.white,
        );
      case PostStatus.inProgress:
        return const Icon(
          Icons.play_arrow,
          size: 12,
          color: Colors.white,
        );
      case PostStatus.completed:
        return const Icon(
          Icons.check,
          size: 12,
          color: Colors.white,
        );
      case PostStatus.overdue:
        return const Icon(
          Icons.warning,
          size: 12,
          color: Colors.white,
        );
    }
  }

  void _toggleLike(PostModel post) async {
    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    final isLiked = post.isLikedBy(currentUser.id);

    try {
      bool success;
      if (isLiked) {
        success = await postProvider.unlikePost(post.id, currentUser.id);
      } else {
        success = await postProvider.likePost(post.id, currentUser.id);
      }

      if (success) {
        // 成功時にローカルの投稿データを安全に更新
        final newLikeCount = isLiked
            ? (post.likeCount > 0 ? post.likeCount - 1 : 0)
            : post.likeCount + 1;

        final newLikedByUserIds = isLiked
            ? post.likedByUserIds.where((id) => id != currentUser.id).toList()
            : [...post.likedByUserIds, currentUser.id];

        final updatedPost = post.copyWith(
          likeCount: newLikeCount,
          likedByUserIds: newLikedByUserIds,
        );

        // PostProviderの各リストを更新
        postProvider.updatePostInLists(updatedPost);

        // UI更新のためのsetState
        if (mounted) {
          setState(() {});
        }

        // フィードバックアニメーション
        if (!isLiked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department,
                      color: AppColors.flame),
                  const SizedBox(width: 8),
                  Text('${post.title}にリアクションしました'),
                ],
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postProvider.errorMessage ?? 'エラーが発生しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }
}
