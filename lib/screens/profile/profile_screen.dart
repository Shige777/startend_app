import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/user_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';

import '../../widgets/post_card_widget.dart';
import '../../widgets/leaf_loading_widget.dart';
import '../../widgets/profile_follow_button.dart';
import '../../services/notification_service.dart';
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
  bool _isLoadingProfile = false; // プロフィール読み込み中フラグを追加
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
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('プロフィール画像読み込みエラー: $error');
                }
                return const Icon(Icons.person, size: 40);
              },
            ),
          ),
        );
      } else {
        // モバイル環境ではCachedNetworkImageProviderを使用
        return CircleAvatar(
          radius: 40,
          backgroundImage: CachedNetworkImageProvider(imageUrl),
          onBackgroundImageError: (error, stackTrace) {
            if (kDebugMode) {
              print('プロフィール画像読み込みエラー: $error');
            }
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

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 不要な再読み込みを防ぐため、didUpdateWidgetでのリフレッシュを削除
    // 必要に応じて手動でリフレッシュを呼び出す
  }

  Future<void> _loadProfileData() async {
    if (_hasLoadedPosts || _isLoadingProfile) {
      if (kDebugMode) {
        print('プロフィール読み込みスキップ - 既に読み込み済みまたは読み込み中');
      }
      return;
    }

    setState(() {
      _isLoadingProfile = true;
    });

    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();

    try {
      if (widget.isOwnProfile) {
        // 自分のプロフィールの場合 - ユーザー情報を再取得
        await userProvider.refreshCurrentUser();
        _profileUser = userProvider.currentUser;
        if (_profileUser != null) {
          // UIを即座に更新
          if (mounted) {
            setState(() {});
          }

          // 投稿の読み込み
          await postProvider.getUserPosts(_profileUser!.id,
              currentUserId: userProvider.currentUser?.id);
        }
      } else {
        // 他のユーザーのプロフィールの場合
        if (widget.userId != null) {
          _profileUser = await userProvider.getUser(widget.userId!);
          if (_profileUser != null) {
            // UIを即座に更新
            if (mounted) {
              setState(() {});
            }

            // 投稿の読み込み
            await postProvider.getUserPosts(_profileUser!.id,
                currentUserId: userProvider.currentUser?.id);
          }
        }
      }

      if (mounted) {
        setState(() {
          _hasLoadedPosts = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('プロフィールデータの読み込みエラー: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _refreshProfileData() async {
    // 既に読み込み中の場合はスキップ
    if (_isLoadingProfile) return;

    setState(() {
      _isLoadingProfile = true;
    });

    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();

    try {
      if (widget.isOwnProfile) {
        // 自分のプロフィールの場合
        await userProvider.refreshCurrentUser();
        _profileUser = userProvider.currentUser;
        if (_profileUser != null) {
          // 投稿を取得（期限切れチェックは削除済み）
          await postProvider.getUserPosts(_profileUser!.id,
              currentUserId: userProvider.currentUser?.id);

          // UIを更新
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        // 他のユーザーのプロフィールの場合
        if (widget.userId != null) {
          // _profileUserをnullにしないで、直接更新
          final updatedUser = await userProvider.getUser(widget.userId!);
          if (updatedUser != null && mounted) {
            setState(() {
              _profileUser = updatedUser;
            });

            // 投稿を取得（期限切れチェックは削除済み）
            await postProvider.getUserPosts(_profileUser!.id,
                currentUserId: userProvider.currentUser?.id);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('プロフィールデータの再読み込みエラー: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
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

  // 期間別の進行期間と集中時間を表示するWidget
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
    // 集中時間（実際にかかった時間）を合計
    Duration totalActualDuration = Duration.zero;

    for (final post in completedPosts) {
      // 集中時間（実際にかかった時間）
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
                  color: Colors.black,
                ),
                const SizedBox(width: 6),
                Text(
                  '進行期間: ${_formatScheduledDuration(totalScheduledDuration)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 集中時間（実際にかかった時間）を表示
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer,
              size: 16,
              color: Colors.black,
            ),
            const SizedBox(width: 6),
            Text(
              '集中時間: ${_formatActualDuration(totalActualDuration)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
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

  // 進行期間を日単位で表示するヘルパーメソッド
  String _formatScheduledDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;

    if (days > 0) {
      return '${days}日';
    } else if (hours > 0) {
      return '${hours}時間';
    } else {
      return '1日未満';
    }
  }

  // 集中時間を時間分単位で表示するヘルパーメソッド
  String _formatActualDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
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
      backgroundColor: Colors.white,
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
        title: Text(
            widget.isOwnProfile ? '' : (_profileUser?.displayName ?? 'プロフィール')),
        backgroundColor: Colors.white, // 背景色を統一
        elevation: 0, // 影を削除
        scrolledUnderElevation: 0, // スクロール時の影も削除
        actions: widget.isOwnProfile
            ? [
                // 通知アイコン
                Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    final currentUser = userProvider.currentUser;
                    if (currentUser == null) return const SizedBox.shrink();

                    return StreamBuilder<int>(
                      stream: NotificationService()
                          .getUnreadNotificationCount(currentUser.id),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;

                        return IconButton(
                          icon: Stack(
                            children: [
                              const Icon(Icons.notifications),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      unreadCount > 99
                                          ? '99+'
                                          : unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: () async {
                            // 通知アイコンをタップした時に全て既読にする
                            await NotificationService()
                                .markAllAsRead(currentUser.id);

                            // 通知画面に遷移
                            if (context.mounted) {
                              context.push('/notifications');
                            }
                          },
                        );
                      },
                    );
                  },
                ),
                // 投稿のソート選択
                PopupMenuButton<PostSortType>(
                  icon: const Icon(Icons.sort, color: Colors.black),
                  color: Colors.white,
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
                            color: Colors.black,
                          ),
                          const SizedBox(width: 8),
                          const Text('START投稿の日付',
                              style: TextStyle(color: Colors.black)),
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
                            color: Colors.black,
                          ),
                          const SizedBox(width: 8),
                          const Text('END投稿の日付',
                              style: TextStyle(color: Colors.black)),
                        ],
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<TimePeriod>(
                  icon: const Icon(Icons.date_range, color: Colors.black),
                  color: Colors.white,
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
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getPeriodText(period),
                                  style: const TextStyle(color: Colors.black),
                                ),
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
                  color: Colors.white,
                  onSelected: (value) {
                    if (value == 'logout') {
                      _showLogoutDialog();
                    } else if (value == 'privacy') {
                      _showPrivacySettings();
                    } else if (value == 'notifications') {
                      _showNotificationSettings();
                    } else if (value == 'community_posts') {
                      _toggleCommunityPosts();
                    } else if (value == 'account_management') {
                      _showAccountManagement();
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
                      const PopupMenuItem<String>(
                        value: 'account_management',
                        child: Row(
                          children: [
                            Icon(Icons.account_circle, color: Colors.black),
                            SizedBox(width: 8),
                            Text('アカウント管理',
                                style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                    ],
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.black),
                          SizedBox(width: 8),
                          Text('ログアウト', style: TextStyle(color: Colors.black)),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [
                // 投稿のソート選択
                PopupMenuButton<PostSortType>(
                  icon: const Icon(Icons.sort, color: Colors.black),
                  color: Colors.white,
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
                            color: Colors.black,
                          ),
                          const SizedBox(width: 8),
                          const Text('START投稿の日付',
                              style: TextStyle(color: Colors.black)),
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
                            color: Colors.black,
                          ),
                          const SizedBox(width: 8),
                          const Text('END投稿の日付',
                              style: TextStyle(color: Colors.black)),
                        ],
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<TimePeriod>(
                  icon: const Icon(Icons.date_range, color: Colors.black),
                  color: Colors.white,
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
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getPeriodText(period),
                                  style: const TextStyle(color: Colors.black),
                                ),
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
          // 自分のプロフィールの場合は現在のユーザーを使用
          final user =
              widget.isOwnProfile ? userProvider.currentUser : _profileUser;

          // 自分のプロフィールの場合は即座に表示、他のユーザーの場合はローディング表示
          if (widget.isOwnProfile) {
            if (user == null) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LeafLoadingWidget(
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
          } else {
            // 他のユーザーのプロフィールの場合
            if (_profileUser == null || _isLoadingProfile) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LeafLoadingWidget(
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
          }

          // ユーザーがnullの場合はローディング表示
          if (user == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LeafLoadingWidget(
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
                      const SizedBox(height: 8), // 16から8に削減

                      // フォローボタン（他のユーザーのプロフィールの場合）
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
                      if (!widget.isOwnProfile) ...[
                        const SizedBox(height: 12),
                        _buildFollowButton(context, user),
                      ],

                      // プロフィール編集ボタン（自分のプロフィールの場合）
                      if (widget.isOwnProfile) ...[
                        const SizedBox(height: 12), // 16から12に削減
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              if (kDebugMode) {
                                print('プロフィール編集ボタンがタップされました');
                              }
                              try {
                                // GoRouterの代わりにNavigator.pushを使用
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfileSettingsScreen(),
                                  ),
                                );
                                if (kDebugMode) {
                                  print('プロフィール設定画面への遷移を実行しました');
                                }
                              } catch (e) {
                                if (kDebugMode) {
                                  print('プロフィール設定画面への遷移でエラー: $e');
                                }
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
                    if (!widget.isOwnProfile) ...[
                      const SizedBox(height: 12),
                      _buildFollowButton(context, user),
                    ],

                    // プロフィール編集ボタン（自分のプロフィールの場合）
                    if (widget.isOwnProfile) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            if (kDebugMode) {
                              print('プロフィール編集ボタンがタップされました');
                            }
                            try {
                              // GoRouterの代わりにNavigator.pushを使用
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ProfileSettingsScreen(),
                                ),
                              );
                              if (kDebugMode) {
                                print('プロフィール設定画面への遷移を実行しました');
                              }
                            } catch (e) {
                              if (kDebugMode) {
                                print('プロフィール設定画面への遷移でエラー: $e');
                              }
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
      // ナビゲーションバーを表示（ホーム画面から来た場合は表示しない）
      bottomNavigationBar: widget.fromPage == 'home'
          ? null
          : BottomNavigationBar(
              backgroundColor: AppColors.background, // 背景色を統一
              elevation: 0, // 影を削除
              currentIndex:
                  widget.isOwnProfile ? 1 : 0, // 自分のプロフィールの場合は軌跡タブを選択状態にする
              onTap: (index) {
                if (index == 0) {
                  context.go('/home');
                } else if (index == 1) {
                  // 軌跡タブをタップした場合は自分のプロフィールに遷移
                  context.go('/profile');
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
            ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value,
      {VoidCallback? onTap}) {
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 2), // 4から2に削減
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11, // フォントサイズを小さく
              ),
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

  Widget _buildFollowButton(BuildContext context, UserModel user) {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return ProfileFollowButton(
      user: user,
      currentUser: currentUser,
    );
  }

  Widget _buildPostSection(BuildContext context, String category) {
    return Consumer2<PostProvider, UserProvider>(
      builder: (context, postProvider, userProvider, child) {
        // 不要な_loadProfileData()呼び出しを削除
        // if (!_hasLoadedPosts && _profileUser != null) {
        //   SchedulerBinding.instance.addPostFrameCallback((_) {
        //     _loadProfileData();
        //   });
        // }

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
                  !(_profileUser!.showCommunityPostsToOthers) &&
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

              // 他のユーザーのコミュニティ投稿表示設定を確認
              if (_profileUser != null &&
                  !(_profileUser!.showCommunityPostsToOthers) &&
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
            color: Colors.black,
            backgroundColor: Colors.transparent,
            strokeWidth: 1.0,
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
            color: Colors.black,
            backgroundColor: Colors.transparent,
            strokeWidth: 1.0,
            displacement: 0,
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
          backgroundColor: Colors.white,
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
                foregroundColor: Colors.black,
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
            backgroundColor: Colors.black,
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
        backgroundColor: Colors.white,
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
                  activeColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
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
                  activeColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
                SwitchListTile(
                  title: const Text('他のユーザーにコミュニティ内での投稿を表示しない'),
                  subtitle: const Text('ONにすると、他のユーザーからコミュニティ投稿が見えなくなります'),
                  value: !currentUser.showCommunityPostsToOthers, // 値を反転
                  onChanged: (value) async {
                    final updatedUser =
                        currentUser.copyWith(showCommunityPostsToOthers: !value); // 値を反転して保存
                    await userProvider.updateUser(updatedUser);
                  },
                  activeColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
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

  // アカウント管理画面を表示
  void _showAccountManagement() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('アカウント管理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'アカウントの管理と削除',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'アカウント削除',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'アカウントを削除すると、すべてのデータが完全に削除され、復元することはできません。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showAccountDeletionDialog();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('アカウント削除'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openAccountDeletionPage();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('詳細を確認'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

  // アカウント削除確認ダイアログ
  void _showAccountDeletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('アカウント削除の確認'),
          content: const Text(
            '本当にアカウントを削除しますか？\n\n'
            'この操作は取り消すことができません。\n'
            'すべてのデータが完全に削除されます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );
  }

  // アカウント削除詳細ページを開く
  void _openAccountDeletionPage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('アカウント削除について'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('アカウント削除の詳細については、以下のWebページをご確認ください：'),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final url =
                        'https://startend-sns-app.web.app/account-deletion.html';
                    final uri = Uri.parse(url);

                    try {
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } else {
                        // URLが開けない場合はスナックバーで表示
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('URLを開けませんでした: $url'),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e) {
                      // エラーが発生した場合
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('エラーが発生しました: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'https://startend-sns-app.web.app/account-deletion.html',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('または、startendofficial.app@gmail.com までお問い合わせください。'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  // アカウント削除処理
  Future<void> _deleteAccount() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();

      // ユーザーデータの削除
      await userProvider.deleteUserData();

      // Firebase認証からアカウントを削除
      await authProvider.deleteAccount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('アカウントを削除しました'),
            backgroundColor: Colors.green,
          ),
        );

        // ログイン画面に遷移
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アカウント削除に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                  const Icon(Icons.eco, color: AppColors.flame),
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
