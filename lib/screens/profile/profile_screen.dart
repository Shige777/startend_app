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

import '../../widgets/post_card_widget.dart';
import '../../widgets/wave_loading_widget.dart';
import 'profile_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // 他のユーザーのプロフィールを表示する場合に使用
  final bool isOwnProfile; // 自分のプロフィールかどうかを明示的に指定
  final String? fromPage; // 遷移元のページ識別子
  final String? searchQuery; // 検索クエリ（検索画面から来た場合）

  const ProfileScreen({
    super.key,
    this.userId,
    this.isOwnProfile = false,
    this.fromPage,
    this.searchQuery,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum TimePeriod { day, week, month, year, all }

// 投稿の並び順を選択するenum
enum PostSortType { startDate, endDate }

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGridView = true;
  bool _hasLoadedPosts = false;
  UserModel? _profileUser; // 表示するユーザー情報
  TimePeriod _selectedPeriod = TimePeriod.day;
  bool _showCommunityPosts = true; // コミュニティ投稿を表示するかどうか
  PostSortType _sortType = PostSortType.startDate; // デフォルトはSTART投稿の日付

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
      if (kIsWeb) {
        // Web環境では画像読み込みエラーを適切に処理
        return CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.surfaceVariant,
          child: ClipOval(
            child: Image.network(
              imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('プロフィール画像読み込みエラー: $error');
                  print('URL: $imageUrl');
                }
                return const Icon(Icons.person, size: 40);
              },
            ),
          ),
        );
      } else {
        // モバイル環境では従来通り
        return CircleAvatar(
          radius: 40,
          backgroundImage: NetworkImage(imageUrl),
          onBackgroundImageError: (error, stackTrace) {
            print('プロフィール画像読み込みエラー: $error');
          },
        );
      }
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

    // 他のユーザーのプロフィールの場合は、初期状態で_profileUserをnullに設定
    if (!widget.isOwnProfile) {
      _profileUser = null;
    }

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
          // 期限切れ投稿を自動更新してから投稿を取得
          await postProvider.updateExpiredPosts();
          await postProvider.getUserPosts(_profileUser!.id,
              currentUserId: userProvider.currentUser?.id);
        }
      } else {
        // 他のユーザーのプロフィールの場合
        if (widget.userId != null) {
          // 他のユーザーのプロフィールでは、まず_profileUserをnullにしてから読み込む
          setState(() {
            _profileUser = null;
          });

          _profileUser = await userProvider.getUser(widget.userId!);
          if (_profileUser != null) {
            if (kDebugMode) {
              print('他のユーザーのプロフィール: 投稿を読み込み開始 - ${_profileUser!.id}');
            }
            // 期限切れ投稿を自動更新してから投稿を取得
            await postProvider.updateExpiredPosts();
            await postProvider.getUserPosts(_profileUser!.id,
                currentUserId: userProvider.currentUser?.id);
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

  Future<void> _refreshProfileData() async {
    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();

    try {
      if (widget.isOwnProfile) {
        // 自分のプロフィールの場合
        await userProvider.refreshCurrentUser();
        _profileUser = userProvider.currentUser;
        if (_profileUser != null) {
          if (kDebugMode) {
            print('軌跡画面: 自分の投稿を再読み込み開始 - ${_profileUser!.id}');
          }
          // 期限切れ投稿を自動更新してから投稿を取得
          await postProvider.updateExpiredPosts();
          await postProvider.getUserPosts(_profileUser!.id,
              currentUserId: userProvider.currentUser?.id);
        }
      } else {
        // 他のユーザーのプロフィールの場合
        if (widget.userId != null) {
          if (mounted) {
            setState(() {
              _profileUser = null;
            });
          }

          _profileUser = await userProvider.getUser(widget.userId!);
          if (_profileUser != null && mounted) {
            if (kDebugMode) {
              print('他のユーザーのプロフィール: 投稿を再読み込み開始 - ${_profileUser!.id}');
            }
            // 期限切れ投稿を自動更新してから投稿を取得
            await postProvider.updateExpiredPosts();
            await postProvider.getUserPosts(_profileUser!.id,
                currentUserId: userProvider.currentUser?.id);
          }
        }
      }

      if (kDebugMode) {
        print('プロフィールデータの再読み込み完了');
      }
    } catch (e) {
      if (kDebugMode) {
        print('プロフィールデータの再読み込みエラー: $e');
      }
    }
  }

  // 期間フィルタ機能
  Map<String, List<PostModel>> _groupPostsByPeriod(List<PostModel> posts) {
    if (_selectedPeriod == TimePeriod.all) {
      // ソート方法に応じて投稿をソート
      List<PostModel> sortedPosts = List.from(posts);
      sortedPosts.sort((a, b) {
        DateTime dateA, dateB;

        if (_sortType == PostSortType.endDate) {
          // END投稿の日付でソート（actualEndTimeがない場合はcreatedAtを使用）
          dateA = a.actualEndTime ?? a.createdAt;
          dateB = b.actualEndTime ?? b.createdAt;
        } else {
          // START投稿の日付でソート
          dateA = a.createdAt;
          dateB = b.createdAt;
        }

        return dateB.compareTo(dateA); // 新しい順
      });

      return {'すべて': sortedPosts};
    }

    final Map<String, List<PostModel>> groupedPosts = {};

    for (final post in posts) {
      DateTime postDate;

      // ソート方法に応じて基準となる日付を決定
      if (_sortType == PostSortType.endDate) {
        // END投稿の日付を使用（actualEndTimeがない場合はcreatedAtを使用）
        postDate = post.actualEndTime ?? post.createdAt;
      } else {
        // START投稿の日付を使用
        postDate = post.createdAt;
      }

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

    // 各グループ内でもソート方法に応じてソート
    for (final key in groupedPosts.keys) {
      groupedPosts[key]!.sort((a, b) {
        DateTime dateA, dateB;

        if (_sortType == PostSortType.endDate) {
          dateA = a.actualEndTime ?? a.createdAt;
          dateB = b.actualEndTime ?? b.createdAt;
        } else {
          dateA = a.createdAt;
          dateB = b.createdAt;
        }

        return dateB.compareTo(dateA); // 新しい順
      });
    }

    // 期間順にソート（日付を基準にソート）
    final sortedKeys = groupedPosts.keys.toList()
      ..sort((a, b) {
        if (a == 'すべて' || b == 'すべて') {
          return a == 'すべて' ? -1 : 1;
        }

        // 各期間の最新投稿の日付を取得してソート
        final postsA = groupedPosts[a]!;
        final postsB = groupedPosts[b]!;

        if (postsA.isEmpty || postsB.isEmpty) {
          return postsA.isEmpty ? 1 : -1;
        }

        // 各グループの最新投稿の日付を取得
        DateTime dateA, dateB;

        if (_sortType == PostSortType.endDate) {
          dateA = postsA.first.actualEndTime ?? postsA.first.createdAt;
          dateB = postsB.first.actualEndTime ?? postsB.first.createdAt;
        } else {
          dateA = postsA.first.createdAt;
          dateB = postsB.first.createdAt;
        }

        return dateB.compareTo(dateA); // 新しい順
      });
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

  // 期間別の実際にかかった時間を表示するWidget
  Widget _buildPeriodTimeDisplay(List<PostModel> posts) {
    // 完了した投稿のみを対象とする
    final completedPosts = posts
        .where((post) =>
            post.status == PostStatus.completed && post.actualEndTime != null)
        .toList();

    if (completedPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    // 進行期間（予定時間）を合計
    Duration totalScheduledDuration = Duration.zero;
    // 実際にかかった時間を合計
    Duration totalActualDuration = Duration.zero;

    for (final post in completedPosts) {
      // 実際にかかった時間
      final actualDuration = post.actualEndTime!.difference(post.createdAt);
      totalActualDuration += actualDuration;

      // 進行期間（予定時間）
      if (post.scheduledEndTime != null) {
        final scheduledDuration =
            post.scheduledEndTime!.difference(post.createdAt);
        totalScheduledDuration += scheduledDuration;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 進行期間（予定時間）を表示
        if (totalScheduledDuration > Duration.zero) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '進行期間: ${_formatDuration(totalScheduledDuration)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 実際にかかった時間を表示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.completed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.completed.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer,
                size: 16,
                color: AppColors.completed,
              ),
              const SizedBox(width: 6),
              Text(
                '実際にかかった時間: ${_formatDuration(totalActualDuration)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.completed,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 時間を表示形式に変換するヘルパーメソッド
  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '${days}日${hours}時間${minutes}分';
    } else if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
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
                  // 前の画面に戻る
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    // 戻る先がない場合は投稿画面に戻る
                    context.go('/home');
                  }
                },
              )
            : null,
        title: Text(widget.isOwnProfile
            ? '軌跡'
            : (_profileUser?.displayName ?? 'プロフィール')),
        backgroundColor: AppColors.background, // 背景色を統一
        elevation: 0, // 影を削除
        scrolledUnderElevation: 0, // スクロール時の影も削除
        actions: widget.isOwnProfile
            ? [
                // 投稿のソート選択
                PopupMenuButton<PostSortType>(
                  icon: const Icon(Icons.sort),
                  tooltip: '並び順',
                  onSelected: (sortType) {
                    setState(() {
                      _sortType = sortType;
                    });
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<PostSortType>(
                      value: PostSortType.startDate,
                      child: Row(
                        children: [
                          Icon(
                            _sortType == PostSortType.startDate
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('START投稿の日付'),
                        ],
                      ),
                    ),
                    PopupMenuItem<PostSortType>(
                      value: PostSortType.endDate,
                      child: Row(
                        children: [
                          Icon(
                            _sortType == PostSortType.endDate
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('END投稿の日付'),
                        ],
                      ),
                    ),
                  ],
                ),
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
                    } else if (value == 'privacy') {
                      _showPrivacySettings();
                    } else if (value == 'notifications') {
                      _showNotificationSettings();
                    } else if (value == 'community_posts') {
                      _toggleCommunityPosts();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    if (widget.isOwnProfile) ...[
                      PopupMenuItem<String>(
                        value: 'community_posts',
                        child: Row(
                          children: [
                            Icon(_showCommunityPosts
                                ? Icons.visibility_off
                                : Icons.visibility),
                            const SizedBox(width: 8),
                            Text(_showCommunityPosts
                                ? 'コミュニティ投稿を非表示'
                                : 'コミュニティ投稿を表示'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'privacy',
                        child: Row(
                          children: [
                            Icon(Icons.privacy_tip),
                            SizedBox(width: 8),
                            Text('プライバシー設定'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'notifications',
                        child: Row(
                          children: [
                            Icon(Icons.notifications),
                            SizedBox(width: 8),
                            Text('通知設定'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                    ],
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
                // 投稿のソート選択
                PopupMenuButton<PostSortType>(
                  icon: const Icon(Icons.sort),
                  tooltip: '並び順',
                  onSelected: (sortType) {
                    setState(() {
                      _sortType = sortType;
                    });
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<PostSortType>(
                      value: PostSortType.startDate,
                      child: Row(
                        children: [
                          Icon(
                            _sortType == PostSortType.startDate
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('START投稿の日付'),
                        ],
                      ),
                    ),
                    PopupMenuItem<PostSortType>(
                      value: PostSortType.endDate,
                      child: Row(
                        children: [
                          Icon(
                            _sortType == PostSortType.endDate
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('END投稿の日付'),
                        ],
                      ),
                    ),
                  ],
                ),
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

          // 他のユーザーのプロフィール表示（タブ付き）
          if (!widget.isOwnProfile) {
            return Column(
              children: [
                // プロフィール情報
                Container(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  color: AppColors.background, // 背景色を統一
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

                      // 統計情報（1行に配置）
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
                              context.push('/follow-list/${user.id}/followers');
                            },
                          ),
                          _buildStatItem(
                            context,
                            'フォロー中',
                            user.followingCount.toString(),
                            onTap: () {
                              context.push('/follow-list/${user.id}/following');
                            },
                          ),
                          _buildStatItem(
                            context,
                            'コミュニティ',
                            user.communitiesCount.toString(),
                            onTap: () {
                              context.push('/community-list/${user.id}');
                            },
                          ),
                        ],
                      ),

                      // フォローボタン（他のユーザーのプロフィールの場合）
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
                  ),
                ),

                // タブバー（集中・進行中、過去の2つ）
                Container(
                  color: AppColors.background, // 背景色を統一
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: '集中・進行中'),
                      Tab(text: '過去'),
                    ],
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
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
          }

          // 自分のプロフィール表示（軌跡画面）
          return Column(
            children: [
              // プロフィール情報
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                color: AppColors.background, // 背景色を統一
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
                            context.push('/follow-list/${user.id}/followers');
                          },
                        ),
                        _buildStatItem(
                          context,
                          'フォロー中',
                          user.followingCount.toString(),
                          onTap: () {
                            context.push('/follow-list/${user.id}/following');
                          },
                        ),
                        _buildStatItem(
                          context,
                          'コミュニティ',
                          user.communitiesCount.toString(),
                          onTap: () {
                            context.push('/community-list/${user.id}');
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
                            print('プロフィール編集ボタンがタップされました');
                            try {
                              // GoRouterの代わりにNavigator.pushを使用
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ProfileSettingsScreen(),
                                ),
                              );
                              print('プロフィール設定画面への遷移を実行しました');
                            } catch (e) {
                              print('プロフィール設定画面への遷移でエラー: $e');
                            }
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
                color: AppColors.background, // 背景色を統一
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '集中・進行中'),
                    Tab(text: '過去'),
                  ],
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
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
              backgroundColor: AppColors.background, // 背景色を統一
              elevation: 0, // 影を削除
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

              // 他のユーザーのコミュニティ投稿表示設定を確認
              if (_profileUser != null &&
                  !_profileUser!.showCommunityPostsToOthers &&
                  post.communityIds.isNotEmpty) {
                return false;
              }
            }

            // 自分の軌跡画面でのコミュニティ投稿の表示設定を確認
            if (widget.isOwnProfile &&
                !_showCommunityPosts &&
                post.communityIds.isNotEmpty) {
              return false;
            }

            final status = post.status;
            final now = DateTime.now();

            // 集中投稿は常に表示
            if (status == PostStatus.concentration) {
              return true;
            }

            // 進行中投稿は、実際の終了時刻がない場合のみ表示
            // （24時間経過した投稿は自動的に完了状態に変更されるため）
            if (status == PostStatus.inProgress) {
              return post.actualEndTime == null;
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

            // 同じステータス内での並び順はソート方法に応じて決定
            DateTime dateA, dateB;

            if (_sortType == PostSortType.endDate) {
              // END投稿の日付でソート（actualEndTimeがない場合はcreatedAtを使用）
              dateA = a.actualEndTime ?? a.createdAt;
              dateB = b.actualEndTime ?? b.createdAt;
            } else {
              // START投稿の日付でソート
              dateA = a.createdAt;
              dateB = b.createdAt;
            }

            return dateB.compareTo(dateA); // 新しい順
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

            // コミュニティ投稿の表示設定を確認
            if (widget.isOwnProfile &&
                !_showCommunityPosts &&
                post.communityIds.isNotEmpty) {
              return false;
            }

            return post.status == PostStatus.completed ||
                post.actualEndTime != null;
          }).toList();
        }

        if (posts.isEmpty) {
          // プライベートアカウントの場合の表示
          if (!widget.isOwnProfile &&
              _profileUser != null &&
              _profileUser!.isPrivate) {
            final currentUser = userProvider.currentUser;
            final isFollowing = currentUser != null &&
                _profileUser!.followerIds.contains(currentUser.id);

            if (!isFollowing) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'プライベートアカウント',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'このアカウントの投稿を見るには\nフォローする必要があります',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
          }

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

          return RefreshIndicator(
            onRefresh: _refreshProfileData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        } else {
          // 過去の投稿を期間別に表示
          return RefreshIndicator(
            onRefresh: _refreshProfileData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in groupedPosts.entries) ...[
                    // 期間ラベルと実際にかかった時間
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          _buildPeriodTimeDisplay(entry.value),
                        ],
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
            ),
          );
        }
      },
    );
  }

  // 期間に応じた列数を取得
  int _getColumnCount() {
    switch (_selectedPeriod) {
      case TimePeriod.week:
        return 5;
      case TimePeriod.month:
        return 7;
      case TimePeriod.year:
        return 9;
      case TimePeriod.all:
        return 11;
      case TimePeriod.day:
        return 3;
      default:
        return 3;
    }
  }

  // グリッド表示用のWidget（START/END画像を2つ並べて表示）
  Widget _buildPostGrid(List<PostModel> posts) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getColumnCount(),
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () => context.push('/post/${post.id}', extra: {
            'post': post,
          }),
          onDoubleTap: () => _toggleLike(post),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.surface,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPostGridItem(post),
            ),
          ),
        );
      },
    );
  }

  // 投稿のグリッドアイテム（START/END画像を表示）
  Widget _buildPostGridItem(PostModel post) {
    return Row(
      children: [
        // 左側：START投稿画像
        Expanded(
          child: Container(
            width: double.infinity,
            height: double.infinity,
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
        ),
        // 右側：END投稿画像 or プレースホルダー
        Expanded(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: post.isCompleted
                ? (post.endImageUrl != null
                    ? Image.network(
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
                      )
                    : Container(
                        color: AppColors.surface,
                        child: const Center(
                          child: Icon(Icons.flag,
                              color: AppColors.completed, size: 32),
                        ),
                      ))
                : Container(
                    color: AppColors.surface.withOpacity(0.8),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              color: AppColors.textSecondary, size: 24),
                          SizedBox(height: 4),
                          Text('END',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
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
            onTap: () => context.push('/post/${post.id}', extra: {
              'post': post,
              'fromPage': 'profile', // 軌跡画面から来たことを識別
            }),
            showActions: true, // アクションボタンを表示してリアクション可能に
            fromPage: 'profile', // 軌跡画面から来たことを識別
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

  // プライバシー設定画面を表示
  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プライバシー設定'),
        content: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final currentUser = userProvider.currentUser;
            if (currentUser == null) return const SizedBox.shrink();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('プライベートアカウント'),
                  subtitle: const Text('フォロワーのみが投稿を見ることができます'),
                  value: currentUser.isPrivate,
                  onChanged: (value) async {
                    final updatedUser = currentUser.copyWith(isPrivate: value);
                    await userProvider.updateUser(updatedUser);
                  },
                ),
                SwitchListTile(
                  title: const Text('フォロー申請の承認制'),
                  subtitle: const Text('フォロー申請を手動で承認する必要があります'),
                  value: currentUser.requiresApproval,
                  onChanged: (value) async {
                    final updatedUser =
                        currentUser.copyWith(requiresApproval: value);
                    await userProvider.updateUser(updatedUser);
                  },
                ),
                SwitchListTile(
                  title: const Text('コミュニティ投稿を他のユーザーに表示'),
                  subtitle: const Text('他のユーザーに自分のコミュニティ内での投稿を表示するかどうか'),
                  value: currentUser.showCommunityPostsToOthers,
                  onChanged: (value) async {
                    final updatedUser =
                        currentUser.copyWith(showCommunityPostsToOthers: value);
                    await userProvider.updateUser(updatedUser);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // 通知設定画面を表示
  void _showNotificationSettings() {
    context.push('/settings/notifications');
  }

  // コミュニティ投稿の表示切り替え
  void _toggleCommunityPosts() {
    setState(() {
      _showCommunityPosts = !_showCommunityPosts;
    });
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
