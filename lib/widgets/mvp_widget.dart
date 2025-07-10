import 'package:flutter/material.dart';
import '../models/progress_model.dart';
import '../constants/app_colors.dart';
import '../widgets/user_avatar.dart';
import '../utils/date_time_utils.dart';

class MVPWidget extends StatelessWidget {
  final WeeklyMVP mvp;
  final bool isCurrentWeek;
  final VoidCallback? onTap;

  const MVPWidget({
    super.key,
    required this.mvp,
    this.isCurrentWeek = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isCurrentWeek
              ? LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isCurrentWeek ? null : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrentWeek
                          ? Colors.white.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCurrentWeek
                          ? Icons.emoji_events
                          : Icons.emoji_events_outlined,
                      color: isCurrentWeek ? Colors.white : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCurrentWeek ? '今週のMVP' : 'MVP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isCurrentWeek
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${mvp.weekYear}年 第${mvp.weekNumber}週',
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
                  if (isCurrentWeek)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // ユーザー情報
              Row(
                children: [
                  UserAvatar(
                    imageUrl: mvp.userImageUrl,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mvp.userName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isCurrentWeek
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: isCurrentWeek
                                  ? Colors.white70
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '活動スコア: ${mvp.activityScore.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isCurrentWeek
                                    ? Colors.white70
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 統計情報
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrentWeek
                      ? Colors.white.withOpacity(0.1)
                      : AppColors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.article,
                      '投稿',
                      mvp.postCount.toString(),
                      isCurrentWeek,
                    ),
                    _buildStatItem(
                      Icons.flag,
                      '完了',
                      mvp.completedGoals.toString(),
                      isCurrentWeek,
                    ),
                    _buildStatItem(
                      Icons.favorite,
                      'いいね',
                      mvp.totalLikes.toString(),
                      isCurrentWeek,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 期間
              Text(
                '${DateTimeUtils.formatDate(mvp.weekStart)} - ${DateTimeUtils.formatDate(mvp.weekEnd)}',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isCurrentWeek ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String label, String value, bool isCurrentWeek) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: isCurrentWeek ? Colors.white70 : AppColors.textSecondary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isCurrentWeek ? Colors.white : AppColors.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isCurrentWeek ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class CompactMVPWidget extends StatelessWidget {
  final WeeklyMVP mvp;
  final VoidCallback? onTap;

  const CompactMVPWidget({
    super.key,
    required this.mvp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.emoji_events,
                color: AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            UserAvatar(
              imageUrl: mvp.userImageUrl,
              size: 32,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mvp.userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '第${mvp.weekNumber}週 MVP',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${mvp.activityScore.toStringAsFixed(1)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MVPBadgeWidget extends StatelessWidget {
  final WeeklyMVP mvp;
  final bool showDetails;

  const MVPBadgeWidget({
    super.key,
    required this.mvp,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            showDetails ? '第${mvp.weekNumber}週 MVP' : 'MVP',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
