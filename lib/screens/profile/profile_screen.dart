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
import '../../widgets/wave_loading_widget.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // 他のユーザーのプロフィールを表示する場合に使用
  final bool isOwnProfile; // 自分のプロフィールかどうかを明示的に指定

  const ProfileScreen({super.key, this.userId, this.isOwnProfile = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGridView = true;
  bool _hasLoadedPosts = false;
  UserModel? _profileUser; // 表示するユーザー情報

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
        title: Text(widget.isOwnProfile
            ? '軌跡'
            : (_profileUser?.displayName ?? 'プロフィール')),
        actions: widget.isOwnProfile
            ? [
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
                      Consumer<UserProvider>(
                        builder: (context, userProvider, child) {
                          final currentUser = userProvider.currentUser;
                          final isFollowing =
                              currentUser?.followingIds.contains(user.id) ??
                                  false;

                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (currentUser != null) {
                                  try {
                                    if (isFollowing) {
                                      // アンフォロー
                                      final updatedFollowingIds =
                                          List<String>.from(
                                              currentUser.followingIds)
                                            ..remove(user.id);
                                      final updatedCurrentUser =
                                          currentUser.copyWith(
                                        followingIds: updatedFollowingIds,
                                        updatedAt: DateTime.now(),
                                      );
                                      await userProvider
                                          .updateUser(updatedCurrentUser);

                                      // フォローされるユーザーのフォロワー数も更新
                                      final updatedFollowerIds =
                                          List<String>.from(user.followerIds)
                                            ..remove(currentUser.id);
                                      final updatedUser = user.copyWith(
                                        followerIds: updatedFollowerIds,
                                        updatedAt: DateTime.now(),
                                      );
                                      await userProvider
                                          .updateUser(updatedUser);

                                      // プロフィールユーザー情報を更新
                                      setState(() {
                                        _profileUser = updatedUser;
                                      });

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('フォローを解除しました')),
                                      );
                                    } else {
                                      // フォロー
                                      final updatedFollowingIds =
                                          List<String>.from(
                                              currentUser.followingIds)
                                            ..add(user.id);
                                      final updatedCurrentUser =
                                          currentUser.copyWith(
                                        followingIds: updatedFollowingIds,
                                        updatedAt: DateTime.now(),
                                      );
                                      await userProvider
                                          .updateUser(updatedCurrentUser);

                                      // フォローされるユーザーのフォロワー数も更新
                                      final updatedFollowerIds =
                                          List<String>.from(user.followerIds)
                                            ..add(currentUser.id);
                                      final updatedUser = user.copyWith(
                                        followerIds: updatedFollowerIds,
                                        updatedAt: DateTime.now(),
                                      );
                                      await userProvider
                                          .updateUser(updatedUser);

                                      // プロフィールユーザー情報を更新
                                      setState(() {
                                        _profileUser = updatedUser;
                                      });

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('フォローしました')),
                                      );
                                    }

                                    // 現在のユーザー情報を再読み込み
                                    await userProvider.refreshCurrentUser();
                                  } catch (e) {
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
                      const SizedBox(height: 16),
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
              currentIndex: 1, // 軌跡タブを選択状態にする
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

        return _isGridView
            ? PostGridWidget(posts: posts)
            : PostListWidget(
                type: PostListType.user,
                posts: posts,
                userId: _profileUser?.id,
                onPostTap: (post) {
                  context.go('/post/${post.id}', extra: post);
                },
              );
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
}
