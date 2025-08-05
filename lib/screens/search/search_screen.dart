import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';

import '../../widgets/post_list_widget.dart';
import '../../widgets/user_list_item.dart';
import '../../widgets/leaf_loading_widget.dart';
import '../../widgets/post_card_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 検索状態を保持するstatic変数
  static String _lastSearchQuery = '';
  static List<PostModel> _lastSearchResults = [];
  static List<UserModel> _lastUserSearchResults = [];

  List<PostModel> _searchResults = [];
  List<UserModel> _userSearchResults = [];
  List<UserModel> _followingUsers = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
          // 前回の検索状態を復元
    if (_lastSearchQuery.isNotEmpty) {
      _searchController.text = _lastSearchQuery;
      _searchQuery = _lastSearchQuery;
      _searchResults = List.from(_lastSearchResults);
      _userSearchResults = List.from(_lastUserSearchResults);
    }

    _loadFollowingUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _loadFollowingUsers() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser != null && currentUser.followingIds.isNotEmpty) {
      // フォロー中のユーザーを取得
      final followingUsers = await userProvider.getFollowing(currentUser.id);
      setState(() {
        _followingUsers = followingUsers;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _userSearchResults = [];
        _isSearching = false;
        _searchQuery = '';
      });

      // static変数もクリア
      _lastSearchQuery = '';
      _lastSearchResults = [];
      _lastUserSearchResults = [];
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      // 投稿検索
      final postProvider = context.read<PostProvider>();
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;
      print('検索開始: $query, 現在のユーザーID: ${currentUser?.id}'); // デバッグログ追加

      final posts =
          await postProvider.searchPosts(query, currentUserId: currentUser?.id);
      print('検索結果 - 投稿数: ${posts.length}'); // デバッグログ追加

      // 検索結果の詳細をログ出力
      for (final post in posts.take(5)) {
        print(
            '検索結果詳細: ID=${post.id}, タイトル=${post.title}, 作成日=${post.createdAt}, タイプ=${post.type}');
      }

      // ユーザー検索
      final users = await userProvider.searchUsers(query);
      print('検索結果 - ユーザー数: ${users.length}'); // デバッグログ追加

      setState(() {
        _searchResults = posts;
        _userSearchResults = users;
        _isSearching = false;
      });

      // 検索結果をstatic変数に保存
      _lastSearchQuery = query;
      _lastSearchResults = posts;
      _lastUserSearchResults = users;

      // デバッグログを追加
      print('検索結果の状態更新:');
      print('- 検索クエリ: $query');
      print('- 投稿検索結果数: ${posts.length}');
      print('- ユーザー検索結果数: ${users.length}');
      print('- _searchResults.length: ${_searchResults.length}');
      print('- _userSearchResults.length: ${_userSearchResults.length}');

      // setState後の状態も確認
      print('setState後の状態確認:');
      print('- _searchResults.length (setState後): ${_searchResults.length}');
      print(
          '- _userSearchResults.length (setState後): ${_userSearchResults.length}');
      print('- _searchQuery: $_searchQuery');
      print('- _isSearching: $_isSearching');

      // 投稿の詳細情報も出力
      if (posts.isNotEmpty) {
        print('投稿検索結果の詳細:');
        for (final post in posts.take(3)) {
          print(
              '  - ID: ${post.id}, タイトル: "${post.title}", コメント: "${post.comment}", ENDコメント: "${post.endComment}"');
        }
      }

      // 強制的に再描画をトリガー
      if (mounted) {
        print('強制再描画を実行');
        setState(() {
          // 状態を再設定して確実に更新
          _searchResults = posts;
          _userSearchResults = users;
          _searchQuery = query;
          print('強制再描画後の状態:');
          print('- _searchResults.length: ${_searchResults.length}');
          print('- _userSearchResults.length: ${_userSearchResults.length}');
          print('- _searchQuery: $_searchQuery');
        });
      }

      // 最終確認
      print('最終確認:');
      print('- _searchResults.length: ${_searchResults.length}');
      print('- _userSearchResults.length: ${_userSearchResults.length}');
      print('- _searchQuery: $_searchQuery');
      print('- _isSearching: $_isSearching');

      // 強制的にUIを更新
      if (mounted) {
        print('UI更新を強制実行');
        setState(() {});
      }

      // さらに強制的にUIを更新
      if (mounted) {
        print('さらに強制UI更新を実行');
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              print('遅延UI更新を実行');
            });
          }
        });
      }

      // さらに強制的にUIを更新
      if (mounted) {
        print('さらに強制UI更新を実行2');
        Future.delayed(Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              print('遅延UI更新を実行2');
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検索に失敗しました: $e')),
        );
      }
    }
  }

  // 画像URLがネットワークURLかローカルファイルパスかを判別
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // プロフィール画像を表示するWidgetを構築
  Widget _buildProfileImage(String? imageUrl, {double radius = 20}) {
    if (imageUrl == null) {
      return CircleAvatar(
        radius: radius,
        child: Icon(Icons.person, size: radius),
      );
    }

    if (_isNetworkUrl(imageUrl)) {
      // ネットワーク画像
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl),
      );
    } else {
      // ローカルファイル
      if (kIsWeb) {
        // Webの場合はエラー表示
        return CircleAvatar(
          radius: radius,
          child: Icon(Icons.error, size: radius),
        );
      } else {
        // モバイルの場合はFileImageを使用
        try {
          return CircleAvatar(
            radius: radius,
            backgroundImage: FileImage(File(imageUrl)),
          );
        } catch (e) {
          return CircleAvatar(
            radius: radius,
            child: Icon(Icons.error, size: radius),
          );
        }
      }
    }
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('検索'),
        backgroundColor: Colors.white, // 背景色を統一
        elevation: 0, // 影を削除
        scrolledUnderElevation: 0, // スクロール時の影も削除
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // 検索バー
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                color: Colors.white, // 背景色を白に変更
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: '投稿やユーザーを検索...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none, // 枠線を削除
                    focusedBorder: InputBorder.none, // フォーカス時の枠線も削除
                    enabledBorder: InputBorder.none, // 通常時の枠線も削除
                    filled: true,
                    fillColor: Colors.white, // 背景色を白に変更
                  ),
                  onChanged: (value) {
                    if (value.length > 2 || value.isEmpty) {
                      _performSearch(value);
                    }
                  },
                  onSubmitted: _performSearch,
                ),
              ),
              // タブバーを削除
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // フォロー中のユーザー（タブの下）
          if (_followingUsers.isNotEmpty && _searchQuery.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              color: Colors.white, // 背景色を白に変更
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'フォロー中',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _followingUsers.length,
                      itemBuilder: (context, index) {
                        final user = _followingUsers[index];
                        return Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          child: Column(
                            children: [
                              _buildProfileImage(user.profileImageUrl,
                                  radius: 20),
                              const SizedBox(height: 4),
                              Text(
                                user.displayName,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Dividerを削除してシームレスに
          ],

          // 検索結果
          Expanded(
            child: _isSearching
                ? const Center(
                    child: LeafLoadingWidget(
                      size: 60,
                      color: AppColors.primary,
                    ),
                  )
                : _searchQuery.isEmpty
                    ? const Center(
                        child: Text(
                          '投稿やユーザーを検索してみましょう',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : _searchResults.isEmpty && _userSearchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '検索しましたが見つけることができませんでした',
                                  style:
                                      TextStyle(color: AppColors.textSecondary),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '検索クエリ: $_searchQuery',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'デバッグ: 投稿数=${_searchResults.length}, ユーザー数=${_userSearchResults.length}',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(8),
                            children: [
                              // デバッグ情報を表示
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.withOpacity(0.2),
                                  border: Border.all(color: Colors.orange),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('🐛 デバッグ情報:'),
                                    Text('検索クエリ: "$_searchQuery"'),
                                    Text('投稿結果数: ${_searchResults.length}'),
                                    Text('ユーザー結果数: ${_userSearchResults.length}'),
                                    Text('検索中: $_isSearching'),
                                    if (_userSearchResults.isNotEmpty) ...[
                                      Text('ユーザー詳細:'),
                                      ..._userSearchResults.take(3).map((user) => 
                                        Text('  - ${user.displayName} (${user.email})')
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              // 投稿検索結果
                              if (_searchResults.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    '投稿: ${_searchResults.length}件',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                ..._searchResults.map((post) {
                                  print(
                                      '投稿を表示: ID=${post.id}, タイトル=${post.title}');
                                  return PostCardWidget(
                                    post: post,
                                    onTap: () {
                                      context.push('/post/${post.id}');
                                    },
                                  );
                                }).toList(),
                                SizedBox(height: 16),
                              ],

                              // ユーザー検索結果
                              if (_userSearchResults.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'ユーザー: ${_userSearchResults.length}件',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                ..._userSearchResults.map((user) {
                                  print(
                                      'ユーザーを表示: ID=${user.id}, 名前=${user.displayName}');
                                  return UserListItem(
                                    user: user,
                                    onTap: () {
                                      setState(() {}); // フォロー状態を即時反映
                                      context.go('/profile/${user.id}', extra: {
                                        'fromPage': 'search',
                                        'searchQuery': _searchQuery,
                                      });
                                    },
                                  );
                                }).toList(),
                              ],
                              
                              // 検索結果がない場合のメッセージ
                              if (_searchResults.isEmpty && _userSearchResults.isEmpty && _searchQuery.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      '「$_searchQuery」の検索結果がありません',
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
