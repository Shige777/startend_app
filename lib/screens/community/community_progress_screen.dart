import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/community_model.dart';
import '../../models/progress_model.dart';
import '../../providers/user_provider.dart';
import '../../services/progress_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
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

  List<Goal> _goals = [];
  List<ProgressRecord> _records = [];
  List<WeeklyMVP> _mvps = [];
  WeeklyMVP? _currentMVP;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final futures = await Future.wait([
        _progressService.getCommunityGoals(widget.communityId),
        _progressService.getCommunityProgressRecords(widget.communityId),
        _progressService.getCommunityMVPs(widget.communityId),
        _progressService.getCurrentWeekMVP(widget.communityId),
      ]);

      setState(() {
        _goals = futures[0] as List<Goal>;
        _records = futures[1] as List<ProgressRecord>;
        _mvps = futures[2] as List<WeeklyMVP>;
        _currentMVP = futures[3] as WeeklyMVP?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込みに失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.community.name} - 進捗'),
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '目標'),
            Tab(text: '記録'),
            Tab(text: 'MVP'),
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
                _buildGoalsTab(),
                _buildRecordsTab(),
                _buildMVPTab(),
              ],
            ),
    );
  }

  Widget _buildGoalsTab() {
    if (_goals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'まだ目標が設定されていません',
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
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        itemCount: _goals.length,
        itemBuilder: (context, index) {
          final goal = _goals[index];
          return _buildGoalCard(goal);
        },
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getGoalStatusColor(goal.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    goal.statusDisplayName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              goal.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // 進捗バー
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: goal.progressPercentage,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getGoalStatusColor(goal.status),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${goal.currentCount}/${goal.targetCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  goal.isOverdue ? '期限切れ' : '残り${goal.remainingDays}日',
                  style: TextStyle(
                    fontSize: 12,
                    color: goal.isOverdue
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  goal.typeDisplayName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            // マイルストーン
            if (goal.milestones.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'マイルストーン',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: goal.milestones.map((milestone) {
                  final isCompleted =
                      goal.completedMilestones.contains(milestone);
                  return Chip(
                    label: Text(
                      milestone,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isCompleted ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: isCompleted
                        ? AppColors.success
                        : AppColors.surfaceVariant,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsTab() {
    if (_records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'まだ進捗記録がありません',
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
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          return _buildRecordCard(record);
        },
      ),
    );
  }

  Widget _buildRecordCard(ProgressRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  DateTimeUtils.formatDateTime(record.recordDate),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (record.description != null) ...[
              const SizedBox(height: 8),
              Text(
                record.description!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (record.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  record.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: AppColors.surfaceVariant,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                ),
              ),
            ],
            if (record.metrics.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: record.metrics.entries.map((entry) {
                  return Chip(
                    label: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: AppColors.surfaceVariant,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],
            if (record.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: record.tags.map((tag) {
                  return Chip(
                    label: Text(
                      '#$tag',
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMVPTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 今週のMVP
            if (_currentMVP != null) ...[
              const Text(
                '今週のMVP',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMVPCard(_currentMVP!, isCurrentWeek: true),
              const SizedBox(height: 24),
            ],

            // 過去のMVP
            if (_mvps.isNotEmpty) ...[
              const Text(
                '過去のMVP',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _mvps.length,
                itemBuilder: (context, index) {
                  final mvp = _mvps[index];
                  return _buildMVPCard(mvp);
                },
              ),
            ] else ...[
              const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'まだMVPが選出されていません',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMVPCard(WeeklyMVP mvp, {bool isCurrentWeek = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isCurrentWeek
              ? LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isCurrentWeek)
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 24,
                    )
                  else
                    const Icon(
                      Icons.emoji_events_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${mvp.weekYear}年 第${mvp.weekNumber}週',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCurrentWeek
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${DateTimeUtils.formatDate(mvp.weekStart)} - ${DateTimeUtils.formatDate(mvp.weekEnd)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCurrentWeek
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  UserAvatar(
                    imageUrl: mvp.userImageUrl,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mvp.userName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCurrentWeek
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '活動スコア: ${mvp.activityScore.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrentWeek
                                ? Colors.white70
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    '投稿数',
                    mvp.postCount.toString(),
                    isCurrentWeek,
                  ),
                  _buildStatItem(
                    '完了目標',
                    mvp.completedGoals.toString(),
                    isCurrentWeek,
                  ),
                  _buildStatItem(
                    'いいね',
                    mvp.totalLikes.toString(),
                    isCurrentWeek,
                  ),
                ],
              ),
            ],
          ),
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

  Color _getGoalStatusColor(GoalStatus status) {
    switch (status) {
      case GoalStatus.active:
        return AppColors.primary;
      case GoalStatus.completed:
        return AppColors.success;
      case GoalStatus.paused:
        return AppColors.warning;
      case GoalStatus.cancelled:
        return AppColors.error;
    }
  }
}
