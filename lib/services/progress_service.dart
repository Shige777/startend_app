import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/progress_model.dart';
import '../models/post_model.dart';

class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 目標管理
  Future<String?> createGoal({
    required String title,
    required String description,
    required GoalType type,
    required DateTime targetDate,
    required int targetCount,
    String? communityId,
    List<String> milestones = const [],
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final goal = Goal(
        id: '',
        userId: currentUser.uid,
        communityId: communityId,
        title: title,
        description: description,
        type: type,
        status: GoalStatus.active,
        startDate: DateTime.now(),
        targetDate: targetDate,
        targetCount: targetCount,
        milestones: milestones,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef =
          await _firestore.collection('goals').add(goal.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error creating goal: $e');
      return null;
    }
  }

  Future<bool> updateGoalProgress(String goalId, int increment) async {
    try {
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      if (!goalDoc.exists) return false;

      final goal = Goal.fromFirestore(goalDoc);
      final newCount = goal.currentCount + increment;

      Map<String, dynamic> updateData = {
        'currentCount': newCount,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      // 目標達成チェック
      if (newCount >= goal.targetCount && goal.status == GoalStatus.active) {
        updateData['status'] = GoalStatus.completed.toString();
        updateData['completedDate'] = Timestamp.fromDate(DateTime.now());
      }

      await _firestore.collection('goals').doc(goalId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating goal progress: $e');
      return false;
    }
  }

  Future<bool> completeMilestone(String goalId, String milestone) async {
    try {
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      if (!goalDoc.exists) return false;

      final goal = Goal.fromFirestore(goalDoc);
      if (!goal.milestones.contains(milestone)) return false;

      final newCompletedMilestones = [...goal.completedMilestones];
      if (!newCompletedMilestones.contains(milestone)) {
        newCompletedMilestones.add(milestone);
      }

      await _firestore.collection('goals').doc(goalId).update({
        'completedMilestones': newCompletedMilestones,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return true;
    } catch (e) {
      print('Error completing milestone: $e');
      return false;
    }
  }

  Future<List<Goal>> getUserGoals(String userId, {String? communityId}) async {
    try {
      Query query =
          _firestore.collection('goals').where('userId', isEqualTo: userId);

      if (communityId != null) {
        query = query.where('communityId', isEqualTo: communityId);
      }

      final querySnapshot =
          await query.orderBy('createdAt', descending: true).get();
      return querySnapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting user goals: $e');
      return [];
    }
  }

  Future<List<Goal>> getCommunityGoals(String communityId) async {
    try {
      final querySnapshot = await _firestore
          .collection('goals')
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting community goals: $e');
      return [];
    }
  }

  // 進捗記録
  Future<String?> createProgressRecord({
    required String title,
    String? description,
    String? imageUrl,
    String? goalId,
    String? communityId,
    Map<String, dynamic> metrics = const {},
    List<String> tags = const [],
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final record = ProgressRecord(
        id: '',
        userId: currentUser.uid,
        goalId: goalId,
        communityId: communityId,
        title: title,
        description: description,
        imageUrl: imageUrl,
        recordDate: DateTime.now(),
        metrics: metrics,
        tags: tags,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('progress_records')
          .add(record.toFirestore());

      // 関連する目標の進捗を更新
      if (goalId != null) {
        await updateGoalProgress(goalId, 1);
      }

      return docRef.id;
    } catch (e) {
      print('Error creating progress record: $e');
      return null;
    }
  }

  Future<List<ProgressRecord>> getUserProgressRecords(String userId,
      {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('progress_records')
          .where('userId', isEqualTo: userId)
          .orderBy('recordDate', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ProgressRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting user progress records: $e');
      return [];
    }
  }

  Future<List<ProgressRecord>> getCommunityProgressRecords(String communityId,
      {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('progress_records')
          .where('communityId', isEqualTo: communityId)
          .orderBy('recordDate', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ProgressRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting community progress records: $e');
      return [];
    }
  }

  // MVP制度
  Future<void> calculateWeeklyMVP(String communityId) async {
    try {
      final now = DateTime.now();
      final weekStart = _getWeekStart(now);
      final weekEnd = _getWeekEnd(now);

      // 週の投稿データを取得
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('communityId', isEqualTo: communityId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      // ユーザー別の活動データを集計
      Map<String, Map<String, dynamic>> userStats = {};

      for (var doc in postsSnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        final userId = post.userId;

        if (!userStats.containsKey(userId)) {
          userStats[userId] = {
            'postCount': 0,
            'totalLikes': 0,
            'completedGoals': 0,
          };
        }

        userStats[userId]!['postCount']++;
        userStats[userId]!['totalLikes'] += post.likeCount;

        if (post.isCompleted) {
          userStats[userId]!['completedGoals']++;
        }
      }

      // MVP を計算
      String? mvpUserId;
      double maxScore = 0;

      for (var entry in userStats.entries) {
        final stats = entry.value;
        final score = _calculateActivityScore(
          stats['postCount'],
          stats['completedGoals'],
          stats['totalLikes'],
        );

        if (score > maxScore) {
          maxScore = score;
          mvpUserId = entry.key;
        }
      }

      // MVP データを保存
      if (mvpUserId != null && maxScore > 0) {
        await _saveMVPRecord(
          communityId,
          mvpUserId,
          userStats[mvpUserId]!,
          maxScore,
          weekStart,
          weekEnd,
        );
      }
    } catch (e) {
      print('Error calculating weekly MVP: $e');
    }
  }

  Future<void> _saveMVPRecord(
    String communityId,
    String userId,
    Map<String, dynamic> stats,
    double score,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    try {
      // ユーザー情報を取得
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      final mvp = WeeklyMVP(
        id: '',
        communityId: communityId,
        userId: userId,
        userName: userData?['displayName'] ?? 'ユーザー',
        userImageUrl: userData?['profileImageUrl'],
        weekYear: weekStart.year,
        weekNumber: _getWeekNumber(weekStart),
        postCount: stats['postCount'],
        completedGoals: stats['completedGoals'],
        totalLikes: stats['totalLikes'],
        activityScore: score,
        weekStart: weekStart,
        weekEnd: weekEnd,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('weekly_mvps').add(mvp.toFirestore());
    } catch (e) {
      print('Error saving MVP record: $e');
    }
  }

  Future<List<WeeklyMVP>> getCommunityMVPs(String communityId,
      {int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection('weekly_mvps')
          .where('communityId', isEqualTo: communityId)
          .orderBy('weekStart', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => WeeklyMVP.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting community MVPs: $e');
      return [];
    }
  }

  Future<WeeklyMVP?> getCurrentWeekMVP(String communityId) async {
    try {
      final now = DateTime.now();
      final weekStart = _getWeekStart(now);

      final querySnapshot = await _firestore
          .collection('weekly_mvps')
          .where('communityId', isEqualTo: communityId)
          .where('weekStart', isEqualTo: Timestamp.fromDate(weekStart))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return WeeklyMVP.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting current week MVP: $e');
      return null;
    }
  }

  // ヘルパーメソッド
  double _calculateActivityScore(
      int postCount, int completedGoals, int totalLikes) {
    // 投稿数 * 2 + 完了目標 * 5 + いいね数 * 0.5
    return (postCount * 2) + (completedGoals * 5) + (totalLikes * 0.5);
  }

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
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  // 統計データ
  Future<Map<String, dynamic>> getUserStats(String userId,
      {String? communityId}) async {
    try {
      // 目標統計
      Query goalsQuery =
          _firestore.collection('goals').where('userId', isEqualTo: userId);
      if (communityId != null) {
        goalsQuery = goalsQuery.where('communityId', isEqualTo: communityId);
      }

      final goalsSnapshot = await goalsQuery.get();
      final goals =
          goalsSnapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();

      final completedGoals = goals.where((g) => g.isCompleted).length;
      final activeGoals = goals.where((g) => g.isActive).length;

      // 進捗記録統計
      Query recordsQuery = _firestore
          .collection('progress_records')
          .where('userId', isEqualTo: userId);
      if (communityId != null) {
        recordsQuery =
            recordsQuery.where('communityId', isEqualTo: communityId);
      }

      final recordsSnapshot = await recordsQuery.get();
      final totalRecords = recordsSnapshot.docs.length;

      // 今月の記録数
      final thisMonth = DateTime.now();
      final monthStart = DateTime(thisMonth.year, thisMonth.month, 1);
      final monthRecordsSnapshot = await recordsQuery
          .where('recordDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .get();
      final monthlyRecords = monthRecordsSnapshot.docs.length;

      return {
        'totalGoals': goals.length,
        'completedGoals': completedGoals,
        'activeGoals': activeGoals,
        'totalRecords': totalRecords,
        'monthlyRecords': monthlyRecords,
        'completionRate':
            goals.isNotEmpty ? completedGoals / goals.length : 0.0,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {};
    }
  }
}
