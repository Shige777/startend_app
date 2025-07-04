import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { start, end }

enum PostStatus {
  concentration, // 集中 (24時間以内)
  inProgress, // 進行中
  completed, // 完了
  overdue, // 期限切れ
}

enum PrivacyLevel {
  public, // 全体公開
  mutualFollowersOnly, // 相互フォローのみ
  communityOnly, // コミュニティのみ
  mutualFollowersAndCommunity, // 相互フォロー + コミュニティのみ
}

class PostModel {
  final String id;
  final String userId;
  final String? startPostId; // END投稿の場合、対応するSTART投稿のID
  final String? endPostId; // START投稿の場合、対応するEND投稿のID
  final PostType type;
  final String title;
  final String? comment;
  final String? imageUrl;
  final DateTime? scheduledEndTime;
  final DateTime? actualEndTime;
  final PrivacyLevel privacyLevel;
  final List<String> communityIds;
  final List<String> likedByUserIds;
  final int likeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  PostModel({
    required this.id,
    required this.userId,
    this.startPostId,
    this.endPostId,
    required this.type,
    required this.title,
    this.comment,
    this.imageUrl,
    this.scheduledEndTime,
    this.actualEndTime,
    required this.privacyLevel,
    required this.communityIds,
    required this.likedByUserIds,
    required this.likeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      startPostId: data['startPostId'],
      endPostId: data['endPostId'],
      type: PostType.values.firstWhere(
        (e) => e.toString() == 'PostType.${data['type']}',
        orElse: () => PostType.start,
      ),
      title: data['title'] ?? '',
      comment: data['comment'],
      imageUrl: data['imageUrl'],
      scheduledEndTime: data['scheduledEndTime'] != null
          ? (data['scheduledEndTime'] as Timestamp).toDate()
          : null,
      actualEndTime: data['actualEndTime'] != null
          ? (data['actualEndTime'] as Timestamp).toDate()
          : null,
      privacyLevel: PrivacyLevel.values.firstWhere(
        (e) => e.toString() == 'PrivacyLevel.${data['privacyLevel']}',
        orElse: () => PrivacyLevel.public,
      ),
      communityIds: List<String>.from(data['communityIds'] ?? []),
      likedByUserIds: List<String>.from(data['likedByUserIds'] ?? []),
      likeCount: data['likeCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startPostId': startPostId,
      'endPostId': endPostId,
      'type': type.toString().split('.').last,
      'title': title,
      'comment': comment,
      'imageUrl': imageUrl,
      'scheduledEndTime': scheduledEndTime != null
          ? Timestamp.fromDate(scheduledEndTime!)
          : null,
      'actualEndTime': actualEndTime != null
          ? Timestamp.fromDate(actualEndTime!)
          : null,
      'privacyLevel': privacyLevel.toString().split('.').last,
      'communityIds': communityIds,
      'likedByUserIds': likedByUserIds,
      'likeCount': likeCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PostModel copyWith({
    String? id,
    String? userId,
    String? startPostId,
    String? endPostId,
    PostType? type,
    String? title,
    String? comment,
    String? imageUrl,
    DateTime? scheduledEndTime,
    DateTime? actualEndTime,
    PrivacyLevel? privacyLevel,
    List<String>? communityIds,
    List<String>? likedByUserIds,
    int? likeCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startPostId: startPostId ?? this.startPostId,
      endPostId: endPostId ?? this.endPostId,
      type: type ?? this.type,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      imageUrl: imageUrl ?? this.imageUrl,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      communityIds: communityIds ?? this.communityIds,
      likedByUserIds: likedByUserIds ?? this.likedByUserIds,
      likeCount: likeCount ?? this.likeCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ヘルパーメソッド
  PostStatus get status {
    final now = DateTime.now();

    if (type == PostType.end) {
      return PostStatus.completed;
    }

    if (scheduledEndTime == null) {
      return PostStatus.inProgress;
    }

    final timeDiff = scheduledEndTime!.difference(createdAt);

    // 24時間以内の投稿は集中
    if (timeDiff <= const Duration(hours: 24)) {
      if (now.isAfter(scheduledEndTime!)) {
        return PostStatus.overdue;
      }
      return PostStatus.concentration;
    }

    // 24時間以上の投稿は進行中
    if (now.isAfter(scheduledEndTime!)) {
      return PostStatus.overdue;
    }

    return PostStatus.inProgress;
  }

  bool get isCompleted => type == PostType.end || actualEndTime != null;
  bool get isOverdue =>
      scheduledEndTime != null &&
      DateTime.now().isAfter(scheduledEndTime!) &&
      !isCompleted;

  bool isLikedBy(String userId) {
    return likedByUserIds.contains(userId);
  }

  Duration? get remainingTime {
    if (scheduledEndTime == null || isCompleted) return null;
    final remaining = scheduledEndTime!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  Duration? get elapsedTime {
    if (actualEndTime != null) {
      return actualEndTime!.difference(createdAt);
    }
    return DateTime.now().difference(createdAt);
  }
}
