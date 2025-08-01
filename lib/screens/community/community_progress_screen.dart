import 'package:flutter/material.dart';
import '../../models/community_model.dart';
import '../../constants/app_colors.dart';
import '../../widgets/leaf_loading_widget.dart';
import '../../widgets/user_avatar.dart';
import '../../utils/date_time_utils.dart';

class CommunityProgressScreen extends StatefulWidget {
  final String communityId;
  final CommunityModel community;

  const CommunityProgressScreen({
    super.key,
    required this.communityId,
    required this.community,
  });

  @override
  State<CommunityProgressScreen> createState() =>
      _CommunityProgressScreenState();
}

class _CommunityProgressScreenState extends State<CommunityProgressScreen> {
  bool _isLoading = true;
  Map<String, int> _memberPostCounts = {};

  @override
  void initState() {
    super.initState();
    _loadMemberPostCounts();
  }

  Future<void> _loadMemberPostCounts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // コミュニティメンバーの投稿数を取得
      final postCounts = await _getMemberPostCounts();

      setState(() {
        _memberPostCounts = postCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  Future<Map<String, int>> _getMemberPostCounts() async {
    // ここでFirestoreからコミュニティメンバーの投稿数を取得
    // 実際の実装は後で追加
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.community.name} - 投稿数'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: LeafLoadingWidget(
                size: 50,
                color: AppColors.primary,
              ),
            )
          : _buildMemberPostCounts(),
    );
  }

  Widget _buildMemberPostCounts() {
    if (_memberPostCounts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'まだコミュニティ内で投稿がありません',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _memberPostCounts.length,
      itemBuilder: (context, index) {
        final memberId = _memberPostCounts.keys.elementAt(index);
        final postCount = _memberPostCounts[memberId]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Icon(
                Icons.person,
                color: AppColors.primary,
              ),
            ),
            title: Text('メンバー ${index + 1}'),
            subtitle: Text('$postCount件の投稿'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$postCount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
