import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/community_provider.dart';
import '../../constants/app_colors.dart';
import '../../widgets/post_list_widget.dart';
import '../../widgets/custom_tab_bar.dart';
import '../../widgets/community_list_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('startend'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('ログアウト')),
            ],
          ),
        ],
        bottom: CustomTabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'フォロー中'),
            Tab(text: 'コミュニティ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PostListWidget(
            type: PostListType.following,
            searchQuery: _searchQuery,
          ),
          const CommunityListWidget(),
        ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/create-post');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.textOnPrimary),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿を検索'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'タイトルやコメントで検索...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (value) {
            _performSearch(value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              _performSearch('');
              Navigator.pop(context);
            },
            child: const Text('クリア'),
          ),
          TextButton(
            onPressed: () {
              _performSearch(_searchController.text);
              Navigator.pop(context);
            },
            child: const Text('検索'),
          ),
        ],
      ),
    );
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
    });

    if (_tabController.index == 0) {
      // フォロー中タブでの検索
      context.read<PostProvider>().searchPosts(_searchQuery);
    }
  }

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        // 投稿画面 (現在の画面)
        break;
      case 1:
        // 軌跡画面
        context.go('/profile');
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
              context.go('/login');
            },
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }
}
