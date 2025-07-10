import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalType { daily, weekly, monthly, custom }

enum GoalStatus { active, completed, paused, cancelled }

class Goal {
  final String id;
  final String userId;
  final String? communityId;
  final String title;
  final String description;
  final GoalType type;
  final GoalStatus status;
  final DateTime startDate;
  final DateTime targetDate;
  final DateTime? completedDate;
  final int targetCount;
  final int currentCount;
  final List<String> milestones;
  final List<String> completedMilestones;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.userId,
    this.communityId,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.startDate,
    required this.targetDate,
    this.completedDate,
    required this.targetCount,
    this.currentCount = 0,
    this.milestones = const [],
    this.completedMilestones = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Goal(
      id: doc.id,
      userId: data['userId'] ?? '',
      communityId: data['communityId'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: GoalType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => GoalType.custom,
      ),
      status: GoalStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => GoalStatus.active,
      ),
      startDate: (data['startDate'] as Timestamp).toDate(),
      targetDate: (data['targetDate'] as Timestamp).toDate(),
      completedDate: data['completedDate'] != null
          ? (data['completedDate'] as Timestamp).toDate()
          : null,
      targetCount: data['targetCount'] ?? 1,
      currentCount: data['currentCount'] ?? 0,
      milestones: List<String>.from(data['milestones'] ?? []),
      completedMilestones: List<String>.from(data['completedMilestones'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'communityId': communityId,
      'title': title,
      'description': description,
      'type': type.toString(),
      'status': status.toString(),
      'startDate': Timestamp.fromDate(startDate),
      'targetDate': Timestamp.fromDate(targetDate),
      'completedDate':
          completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'milestones': milestones,
      'completedMilestones': completedMilestones,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Goal copyWith({
    String? id,
    String? userId,
    String? communityId,
    String? title,
    String? description,
    GoalType? type,
    GoalStatus? status,
    DateTime? startDate,
    DateTime? targetDate,
    DateTime? completedDate,
    int? targetCount,
    int? currentCount,
    List<String>? milestones,
    List<String>? completedMilestones,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      completedDate: completedDate ?? this.completedDate,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      milestones: milestones ?? this.milestones,
      completedMilestones: completedMilestones ?? this.completedMilestones,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ヘルパーメソッド
  double get progressPercentage {
    if (targetCount == 0) return 0.0;
    return (currentCount / targetCount).clamp(0.0, 1.0);
  }

  bool get isCompleted => status == GoalStatus.completed;
  bool get isActive => status == GoalStatus.active;
  bool get isOverdue => DateTime.now().isAfter(targetDate) && !isCompleted;

  int get remainingDays {
    final now = DateTime.now();
    if (now.isAfter(targetDate)) return 0;
    return targetDate.difference(now).inDays;
  }

  String get typeDisplayName {
    switch (type) {
      case GoalType.daily:
        return '日次目標';
      case GoalType.weekly:
        return '週次目標';
      case GoalType.monthly:
        return '月次目標';
      case GoalType.custom:
        return 'カスタム目標';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case GoalStatus.active:
        return '進行中';
      case GoalStatus.completed:
        return '完了';
      case GoalStatus.paused:
        return '一時停止';
      case GoalStatus.cancelled:
        return 'キャンセル';
    }
  }
}

class ProgressRecord {
  final String id;
  final String userId;
  final String? goalId;
  final String? communityId;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime recordDate;
  final Map<String, dynamic> metrics; // 各種指標（回数、時間など）
  final List<String> tags;
  final DateTime createdAt;

  ProgressRecord({
    required this.id,
    required this.userId,
    this.goalId,
    this.communityId,
    required this.title,
    this.description,
    this.imageUrl,
    required this.recordDate,
    this.metrics = const {},
    this.tags = const [],
    required this.createdAt,
  });

  factory ProgressRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProgressRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      goalId: data['goalId'],
      communityId: data['communityId'],
      title: data['title'] ?? '',
      description: data['description'],
      imageUrl: data['imageUrl'],
      recordDate: (data['recordDate'] as Timestamp).toDate(),
      metrics: Map<String, dynamic>.from(data['metrics'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'goalId': goalId,
      'communityId': communityId,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'recordDate': Timestamp.fromDate(recordDate),
      'metrics': metrics,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ProgressRecord copyWith({
    String? id,
    String? userId,
    String? goalId,
    String? communityId,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? recordDate,
    Map<String, dynamic>? metrics,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return ProgressRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      goalId: goalId ?? this.goalId,
      communityId: communityId ?? this.communityId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      recordDate: recordDate ?? this.recordDate,
      metrics: metrics ?? this.metrics,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WeeklyMVP {
  final String id;
  final String communityId;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final int weekYear;
  final int weekNumber;
  final int postCount;
  final int completedGoals;
  final int totalLikes;
  final double activityScore;
  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime createdAt;

  WeeklyMVP({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.weekYear,
    required this.weekNumber,
    required this.postCount,
    required this.completedGoals,
    required this.totalLikes,
    required this.activityScore,
    required this.weekStart,
    required this.weekEnd,
    required this.createdAt,
  });

  factory WeeklyMVP.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeeklyMVP(
      id: doc.id,
      communityId: data['communityId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userImageUrl: data['userImageUrl'],
      weekYear: data['weekYear'] ?? 0,
      weekNumber: data['weekNumber'] ?? 0,
      postCount: data['postCount'] ?? 0,
      completedGoals: data['completedGoals'] ?? 0,
      totalLikes: data['totalLikes'] ?? 0,
      activityScore: (data['activityScore'] ?? 0.0).toDouble(),
      weekStart: (data['weekStart'] as Timestamp).toDate(),
      weekEnd: (data['weekEnd'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'communityId': communityId,
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'weekYear': weekYear,
      'weekNumber': weekNumber,
      'postCount': postCount,
      'completedGoals': completedGoals,
      'totalLikes': totalLikes,
      'activityScore': activityScore,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
