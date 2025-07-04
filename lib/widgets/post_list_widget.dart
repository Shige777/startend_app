import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../providers/post_provider.dart';
import '../constants/app_colors.dart';
import 'post_card_widget.dart';

enum PostListType { following, community, user }

class PostListWidget extends StatefulWidget {
  final PostListType type;
  final List<PostModel>? posts;
  final String? searchQuery;

  const PostListWidget({
    super.key,
    required this.type,
    this.posts,
    this.searchQuery,
  });

  @override
  State<PostListWidget> createState() => _PostListWidgetState();
}

class _PostListWidgetState extends State<PostListWidget> {
  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  void _loadPosts() {
    final postProvider = context.read<PostProvider>();

    switch (widget.type) {
      case PostListType.following:
        // TODO: フォロー中の投稿を取得
        break;
      case PostListType.community:
        // TODO: コミュニティの投稿を取得
        break;
      case PostListType.user:
        // TODO: ユーザーの投稿を取得
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostProvider>(
      builder: (context, postProvider, child) {
        List<PostModel> posts;

        if (widget.posts != null) {
          posts = widget.posts!;
        } else {
          switch (widget.type) {
            case PostListType.following:
              posts = postProvider.followingPosts;
              break;
            case PostListType.community:
              posts = postProvider.communityPosts;
              break;
            case PostListType.user:
              posts = postProvider.userPosts;
              break;
          }
        }

        // 検索フィルタリング
        if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
          posts = posts.where((post) {
            final query = widget.searchQuery!.toLowerCase();
            return post.title.toLowerCase().contains(query) ||
                (post.comment?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        if (postProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getEmptyIcon(), size: 64, color: AppColors.textHint),
                const SizedBox(height: 16),
                Text(
                  _getEmptyMessage(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return PostCardWidget(post: posts[index]);
            },
          ),
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    _loadPosts();
  }

  IconData _getEmptyIcon() {
    switch (widget.type) {
      case PostListType.following:
        return Icons.people_outline;
      case PostListType.community:
        return Icons.group_outlined;
      case PostListType.user:
        return Icons.person_outline;
    }
  }

  String _getEmptyMessage() {
    switch (widget.type) {
      case PostListType.following:
        return 'フォロー中の投稿はありません';
      case PostListType.community:
        return 'コミュニティの投稿はありません';
      case PostListType.user:
        return '投稿はありません';
    }
  }
}
