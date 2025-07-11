import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/progress_model.dart';
import '../models/post_model.dart';

class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 活動統計の取得
  Future<List<ActivityStats>> getCommunityActivityStats(
      String communityId) async {
    try {
      final querySnapshot = await _firestore
          .collection('activity_stats')
          .where('communityId', isEqualTo: communityId)
          .orderBy('totalPosts', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ActivityStats.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting community activity stats: $e');
      return [];
    }
  }

  // メンバー活動ランキングの取得
  Future<List<ActivityRanking>> getCommunityRanking(
    String communityId, {
    String period = 'all', // 'week', 'month', 'all'
  }) async {
    try {
      DateTime? startDate;
      DateTime? endDate;

      final now = DateTime.now();
      switch (period) {
        case 'week':
          startDate = _getWeekStart(now);
          endDate = _getWeekEnd(now);
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'all':
          // 全期間の場合は制限なし
          break;
      }

      // コミュニティメンバーの取得
      final communityDoc =
          await _firestore.collection('communities').doc(communityId).get();
      if (!communityDoc.exists) return [];

      final communityData = communityDoc.data() as Map<String, dynamic>;
      final memberIds = List<String>.from(communityData['memberIds'] ?? []);

      // 各メンバーの投稿数を集計
      final rankings = <ActivityRanking>[];

      for (final memberId in memberIds) {
        Query postsQuery = _firestore
            .collection('posts')
            .where('userId', isEqualTo: memberId)
            .where('communityIds', arrayContains: communityId);

        if (startDate != null && endDate != null) {
          postsQuery = postsQuery
              .where('createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .where('createdAt',
                  isLessThanOrEqualTo: Timestamp.fromDate(endDate));
        }

        final postsSnapshot = await postsQuery.get();
        final postCount = postsSnapshot.docs.length;

        // ユーザー情報を取得
        final userDoc =
            await _firestore.collection('users').doc(memberId).get();
        if (!userDoc.exists) continue;

        final userData = userDoc.data() as Map<String, dynamic>;

        // 最後の活動日時を取得
        DateTime lastActivityAt = DateTime.fromMillisecondsSinceEpoch(0);
        if (postsSnapshot.docs.isNotEmpty) {
          final latestPost = postsSnapshot.docs.first;
          final postData = latestPost.data() as Map<String, dynamic>?;
          if (postData != null && postData['createdAt'] != null) {
            lastActivityAt = (postData['createdAt'] as Timestamp).toDate();
          }
        }

        rankings.add(ActivityRanking(
          userId: memberId,
          userName: userData['displayName'] ?? 'ユーザー',
          userImageUrl: userData['profileImageUrl'],
          postCount: postCount,
          rank: 0, // 後で設定
          lastActivityAt: lastActivityAt,
        ));
      }

      // 投稿数でソートしてランクを設定
      rankings.sort((a, b) => b.postCount.compareTo(a.postCount));

      for (int i = 0; i < rankings.length; i++) {
        rankings[i] = ActivityRanking(
          userId: rankings[i].userId,
          userName: rankings[i].userName,
          userImageUrl: rankings[i].userImageUrl,
          postCount: rankings[i].postCount,
          rank: i + 1,
          lastActivityAt: rankings[i].lastActivityAt,
        );
      }

      return rankings;
    } catch (e) {
      print('Error getting community ranking: $e');
      return [];
    }
  }

  // 活動サマリーの生成
  Future<ActivitySummary?> generateActivitySummary(
    String communityId,
    String period, // 'weekly', 'monthly'
  ) async {
    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      switch (period) {
        case 'weekly':
          startDate = _getWeekStart(now);
          endDate = _getWeekEnd(now);
          break;
        case 'monthly':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        default:
          return null;
      }

      // コミュニティ情報の取得
      final communityDoc =
          await _firestore.collection('communities').doc(communityId).get();
      if (!communityDoc.exists) return null;

      final communityData = communityDoc.data() as Map<String, dynamic>;
      final memberIds = List<String>.from(communityData['memberIds'] ?? []);

      // 期間内の投稿を取得
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('communityIds', arrayContains: communityId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final totalPosts = postsSnapshot.docs.length;

      // 日別投稿数の集計
      final dailyBreakdown = <String, int>{};
      final activeMemberIds = <String>{};

      for (final doc in postsSnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        final dateKey =
            '${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}';
        dailyBreakdown[dateKey] = (dailyBreakdown[dateKey] ?? 0) + 1;
        activeMemberIds.add(post.userId);
      }

      // ランキングの取得
      final rankings = await getCommunityRanking(communityId, period: period);

      final summary = ActivitySummary(
        communityId: communityId,
        period: period,
        startDate: startDate,
        endDate: endDate,
        totalPosts: totalPosts,
        totalMembers: memberIds.length,
        activeMemberCount: activeMemberIds.length,
        rankings: rankings,
        dailyBreakdown: dailyBreakdown,
        createdAt: DateTime.now(),
      );

      // サマリーをFirestoreに保存
      await _firestore
          .collection('activity_summaries')
          .add(summary.toFirestore());

      return summary;
    } catch (e) {
      print('Error generating activity summary: $e');
      return null;
    }
  }

  // 活動統計の更新（投稿作成時に呼び出す）
  Future<void> updateActivityStats(String userId, String communityId) async {
    try {
      final now = DateTime.now();
      final weekStart = _getWeekStart(now);
      final monthStart = DateTime(now.year, now.month, 1);

      // 既存の統計を取得
      final statsQuery = await _firestore
          .collection('activity_stats')
          .where('userId', isEqualTo: userId)
          .where('communityId', isEqualTo: communityId)
          .limit(1)
          .get();

      ActivityStats? existingStats;
      String? docId;

      if (statsQuery.docs.isNotEmpty) {
        existingStats = ActivityStats.fromFirestore(statsQuery.docs.first);
        docId = statsQuery.docs.first.id;
      }

      // 投稿数を集計
      final totalPostsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('communityIds', arrayContains: communityId)
          .get();

      final weeklyPostsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('communityIds', arrayContains: communityId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();

      final monthlyPostsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('communityIds', arrayContains: communityId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .get();

      // コミュニティ参加日時を取得
      DateTime joinedAt = now;
      if (existingStats != null) {
        joinedAt = existingStats.joinedAt;
      } else {
        // 初回の場合、コミュニティ参加日時を取得
        final communityDoc =
            await _firestore.collection('communities').doc(communityId).get();
        if (communityDoc.exists) {
          final communityData = communityDoc.data() as Map<String, dynamic>;
          final memberDetails =
              communityData['memberDetails'] as Map<String, dynamic>?;
          if (memberDetails != null && memberDetails.containsKey(userId)) {
            joinedAt =
                (memberDetails[userId]['joinedAt'] as Timestamp).toDate();
          }
        }
      }

      final newStats = ActivityStats(
        userId: userId,
        communityId: communityId,
        totalPosts: totalPostsSnapshot.docs.length,
        weeklyPosts: weeklyPostsSnapshot.docs.length,
        monthlyPosts: monthlyPostsSnapshot.docs.length,
        joinedAt: joinedAt,
        lastActivityAt: now,
        dailyPosts: existingStats?.dailyPosts ?? {},
        weeklyPostsHistory: existingStats?.weeklyPostsHistory ?? {},
        monthlyPostsHistory: existingStats?.monthlyPostsHistory ?? {},
      );

      if (docId != null) {
        await _firestore
            .collection('activity_stats')
            .doc(docId)
            .update(newStats.toFirestore());
      } else {
        await _firestore
            .collection('activity_stats')
            .add(newStats.toFirestore());
      }
    } catch (e) {
      print('Error updating activity stats: $e');
    }
  }

  // 過去の活動サマリーを取得
  Future<List<ActivitySummary>> getActivitySummaries(
    String communityId, {
    String period = 'weekly',
    int limit = 10,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('activity_summaries')
          .where('communityId', isEqualTo: communityId)
          .where('period', isEqualTo: period)
          .orderBy('startDate', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ActivitySummary.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting activity summaries: $e');
      return [];
    }
  }

  // ヘルパーメソッド
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - weekday + 1);
  }

  DateTime _getWeekEnd(DateTime date) {
    final weekStart = _getWeekStart(date);
    return weekStart
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays + 1;
    return ((dayOfYear - 1) ~/ 7) + 1;
  }
}
