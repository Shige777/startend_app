import 'package:cloud_firestore/cloud_firestore.dart';

// 活動統計用のモデル
class ActivityStats {
  final String userId;
  final String communityId;
  final int totalPosts;
  final int weeklyPosts;
  final int monthlyPosts;
  final DateTime joinedAt;
  final DateTime lastActivityAt;
  final Map<String, int> dailyPosts; // 日付別投稿数
  final Map<String, int> weeklyPostsHistory; // 週別投稿数履歴
  final Map<String, int> monthlyPostsHistory; // 月別投稿数履歴

  ActivityStats({
    required this.userId,
    required this.communityId,
    required this.totalPosts,
    required this.weeklyPosts,
    required this.monthlyPosts,
    required this.joinedAt,
    required this.lastActivityAt,
    this.dailyPosts = const {},
    this.weeklyPostsHistory = const {},
    this.monthlyPostsHistory = const {},
  });

  factory ActivityStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityStats(
      userId: data['userId'] ?? '',
      communityId: data['communityId'] ?? '',
      totalPosts: data['totalPosts'] ?? 0,
      weeklyPosts: data['weeklyPosts'] ?? 0,
      monthlyPosts: data['monthlyPosts'] ?? 0,
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      lastActivityAt: (data['lastActivityAt'] as Timestamp).toDate(),
      dailyPosts: Map<String, int>.from(data['dailyPosts'] ?? {}),
      weeklyPostsHistory:
          Map<String, int>.from(data['weeklyPostsHistory'] ?? {}),
      monthlyPostsHistory:
          Map<String, int>.from(data['monthlyPostsHistory'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'communityId': communityId,
      'totalPosts': totalPosts,
      'weeklyPosts': weeklyPosts,
      'monthlyPosts': monthlyPosts,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      'dailyPosts': dailyPosts,
      'weeklyPostsHistory': weeklyPostsHistory,
      'monthlyPostsHistory': monthlyPostsHistory,
    };
  }

  ActivityStats copyWith({
    String? userId,
    String? communityId,
    int? totalPosts,
    int? weeklyPosts,
    int? monthlyPosts,
    DateTime? joinedAt,
    DateTime? lastActivityAt,
    Map<String, int>? dailyPosts,
    Map<String, int>? weeklyPostsHistory,
    Map<String, int>? monthlyPostsHistory,
  }) {
    return ActivityStats(
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      totalPosts: totalPosts ?? this.totalPosts,
      weeklyPosts: weeklyPosts ?? this.weeklyPosts,
      monthlyPosts: monthlyPosts ?? this.monthlyPosts,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      dailyPosts: dailyPosts ?? this.dailyPosts,
      weeklyPostsHistory: weeklyPostsHistory ?? this.weeklyPostsHistory,
      monthlyPostsHistory: monthlyPostsHistory ?? this.monthlyPostsHistory,
    );
  }
}

// ランキング用のモデル
class ActivityRanking {
  final String userId;
  final String userName;
  final String? userImageUrl;
  final int postCount;
  final int rank;
  final DateTime lastActivityAt;

  ActivityRanking({
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.postCount,
    required this.rank,
    required this.lastActivityAt,
  });
}

// 活動サマリー用のモデル
class ActivitySummary {
  final String communityId;
  final String period; // 'weekly', 'monthly'
  final DateTime startDate;
  final DateTime endDate;
  final int totalPosts;
  final int totalMembers;
  final int activeMemberCount;
  final List<ActivityRanking> rankings;
  final Map<String, int> dailyBreakdown;
  final DateTime createdAt;

  ActivitySummary({
    required this.communityId,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalPosts,
    required this.totalMembers,
    required this.activeMemberCount,
    required this.rankings,
    this.dailyBreakdown = const {},
    required this.createdAt,
  });

  factory ActivitySummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivitySummary(
      communityId: data['communityId'] ?? '',
      period: data['period'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      totalPosts: data['totalPosts'] ?? 0,
      totalMembers: data['totalMembers'] ?? 0,
      activeMemberCount: data['activeMemberCount'] ?? 0,
      rankings: (data['rankings'] as List<dynamic>? ?? [])
          .map((r) => ActivityRanking(
                userId: r['userId'] ?? '',
                userName: r['userName'] ?? '',
                userImageUrl: r['userImageUrl'],
                postCount: r['postCount'] ?? 0,
                rank: r['rank'] ?? 0,
                lastActivityAt: (r['lastActivityAt'] as Timestamp).toDate(),
              ))
          .toList(),
      dailyBreakdown: Map<String, int>.from(data['dailyBreakdown'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'communityId': communityId,
      'period': period,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalPosts': totalPosts,
      'totalMembers': totalMembers,
      'activeMemberCount': activeMemberCount,
      'rankings': rankings
          .map((r) => {
                'userId': r.userId,
                'userName': r.userName,
                'userImageUrl': r.userImageUrl,
                'postCount': r.postCount,
                'rank': r.rank,
                'lastActivityAt': Timestamp.fromDate(r.lastActivityAt),
              })
          .toList(),
      'dailyBreakdown': dailyBreakdown,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
