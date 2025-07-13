import 'package:flutter/material.dart';
import '../../models/community_model.dart';
import '../../models/progress_model.dart';
import '../../services/progress_service.dart';
import '../../constants/app_colors.dart';
import '../../widgets/wave_loading_widget.dart';
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

class _CommunityProgressScreenState extends State<CommunityProgressScreen>
    with SingleTickerProviderStateMixin {
  final ProgressService _progressService = ProgressService();
  late TabController _tabController;

  List<ActivityRanking> _weeklyRanking = [];
  List<ActivityRanking> _monthlyRanking = [];
  List<ActivityRanking> _allTimeRanking = [];
  List<ActivitySummary> _weeklySummaries = [];
  List<ActivitySummary> _monthlySummaries = [];
  bool _isLoading = true;
  String _selectedPeriod = 'week'; // 'week', 'month', 'all'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final futures = await Future.wait([
        _progressService.getCommunityRanking(widget.communityId,
            period: 'week'),
        _progressService.getCommunityRanking(widget.communityId,
            period: 'month'),
        _progressService.getCommunityRanking(widget.communityId, period: 'all'),
        _progressService.getActivitySummaries(widget.communityId,
            period: 'weekly'),
        _progressService.getActivitySummaries(widget.communityId,
            period: 'monthly'),
      ]);

      setState(() {
        _weeklyRanking = futures[0] as List<ActivityRanking>;
        _monthlyRanking = futures[1] as List<ActivityRanking>;
        _allTimeRanking = futures[2] as List<ActivityRanking>;
        _weeklySummaries = futures[3] as List<ActivitySummary>;
        _monthlySummaries = futures[4] as List<ActivitySummary>;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.community.name} - 活動統計'),
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ランキング'),
            Tab(text: 'ダッシュボード'),
          ],
        ),
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: WaveLoadingWidget(
                size: 80,
                color: AppColors.primary,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRankingTab(),
                _buildDashboardTab(),
              ],
            ),
    );
  }

  Widget _buildRankingTab() {
    return Column(
      children: [
        // 期間選択
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '期間:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'week',
                      label: Text('週間'),
                    ),
                    ButtonSegment(
                      value: 'month',
                      label: Text('月間'),
                    ),
                    ButtonSegment(
                      value: 'all',
                      label: Text('全期間'),
                    ),
                  ],
                  selected: {_selectedPeriod},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedPeriod = newSelection.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // ランキング表示
        Expanded(
          child: _buildRankingList(),
        ),
      ],
    );
  }

  Widget _buildRankingList() {
    List<ActivityRanking> rankings;
    switch (_selectedPeriod) {
      case 'week':
        rankings = _weeklyRanking;
        break;
      case 'month':
        rankings = _monthlyRanking;
        break;
      case 'all':
        rankings = _allTimeRanking;
        break;
      default:
        rankings = _weeklyRanking;
    }

    if (rankings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'まだ投稿がありません',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          final ranking = rankings[index];
          return _buildRankingCard(ranking);
        },
      ),
    );
  }

  Widget _buildRankingCard(ActivityRanking ranking) {
    Color rankColor;
    IconData rankIcon;

    switch (ranking.rank) {
      case 1:
        rankColor = Colors.amber;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey[400]!;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = Colors.brown[400]!;
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = AppColors.textSecondary;
        rankIcon = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: rankColor, width: 2),
              ),
              child: Center(
                child: ranking.rank <= 3
                    ? Icon(rankIcon, color: rankColor, size: 20)
                    : Text(
                        '${ranking.rank}',
                        style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            UserAvatar(
              imageUrl: ranking.userImageUrl,
              size: 40,
            ),
          ],
        ),
        title: Text(
          ranking.userName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '最終活動: ${DateTimeUtils.formatDateTime(ranking.lastActivityAt)}',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${ranking.postCount}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Text(
              '投稿',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 週間統計
            _buildSummarySection('週間統計', _weeklySummaries),
            const SizedBox(height: 24),
            // 月間統計
            _buildSummarySection('月間統計', _monthlySummaries),
            const SizedBox(height: 24),
            // 投稿数チャート
            _buildPostCountChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(String title, List<ActivitySummary> summaries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (summaries.isNotEmpty) ...[
          _buildSummaryCard(summaries.first),
          const SizedBox(height: 12),
          // 過去の統計をリスト表示
          if (summaries.length > 1) ...[
            const Text(
              '過去の統計',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summaries.length - 1,
              itemBuilder: (context, index) {
                return _buildSummaryCard(summaries[index + 1], isCompact: true);
              },
            ),
          ],
        ] else ...[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'まだ統計データがありません',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(ActivitySummary summary, {bool isCompact = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateTimeUtils.formatDate(summary.startDate)} - ${DateTimeUtils.formatDate(summary.endDate)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!isCompact)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      summary.period == 'weekly' ? '週間' : '月間',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('総投稿数', summary.totalPosts.toString()),
                _buildStatColumn('総メンバー', summary.totalMembers.toString()),
                _buildStatColumn(
                    '活動メンバー', summary.activeMemberCount.toString()),
              ],
            ),
            if (!isCompact && summary.rankings.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'トップ3',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: summary.rankings.take(3).map((ranking) {
                  return Column(
                    children: [
                      UserAvatar(
                        imageUrl: ranking.userImageUrl,
                        size: 30,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ranking.userName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${ranking.postCount}投稿',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPostCountChart() {
    if (_weeklyRanking.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '投稿数ランキング（週間）',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // シンプルなバー表示
            ..._weeklyRanking.take(5).map((ranking) {
              final maxCount = _weeklyRanking.isNotEmpty
                  ? _weeklyRanking.first.postCount
                  : 1;
              final percentage =
                  maxCount > 0 ? ranking.postCount / maxCount : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            ranking.userName.length > 8
                                ? '${ranking.userName.substring(0, 8)}...'
                                : ranking.userName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 20,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: percentage.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: ranking.rank <= 3
                                      ? [
                                          Colors.amber,
                                          Colors.grey[400]!,
                                          Colors.brown[400]!
                                        ][ranking.rank - 1]
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${ranking.postCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isCurrentWeek) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isCurrentWeek ? Colors.white : AppColors.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isCurrentWeek ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
