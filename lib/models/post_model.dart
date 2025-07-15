import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { start, end } // endは廃止予定（互換性のため残す）

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
  final String? startPostId; // 廃止予定（互換性のため残す）
  final String? endPostId; // 廃止予定（互換性のため残す）
  final PostType type; // START投稿のみ使用
  final String title;
  final String? comment; // START投稿時のコメント
  final String? imageUrl; // START投稿の画像
  final String? endComment; // END投稿時のコメント
  final String? endImageUrl; // END投稿の画像
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
    this.endComment,
    this.endImageUrl,
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
      endComment: data['endComment'],
      endImageUrl: data['endImageUrl'],
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
      'endComment': endComment,
      'endImageUrl': endImageUrl,
      'scheduledEndTime': scheduledEndTime != null
          ? Timestamp.fromDate(scheduledEndTime!)
          : null,
      'actualEndTime':
          actualEndTime != null ? Timestamp.fromDate(actualEndTime!) : null,
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
    String? endComment,
    String? endImageUrl,
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
      endComment: endComment ?? this.endComment,
      endImageUrl: endImageUrl ?? this.endImageUrl,
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

    // 投稿が完了している場合
    if (isCompleted) {
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

  bool get isCompleted => actualEndTime != null;
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

  // 使用時間を計算（進行時間 + 実際にかかった時間）
  Duration? get totalUsageTime {
    if (!isCompleted) return null;

    // 実際にかかった時間
    final actualTime = actualEndTime!.difference(createdAt);

    // 予定時間（進行時間）
    final scheduledTime = scheduledEndTime != null
        ? scheduledEndTime!.difference(createdAt)
        : Duration.zero;

    // 実際の時間と予定時間の合計
    return actualTime + scheduledTime;
  }

  // 進行時間のみを取得
  Duration? get scheduledTime {
    if (scheduledEndTime == null) return null;
    return scheduledEndTime!.difference(createdAt);
  }

  // 実際にかかった時間のみを取得
  Duration? get actualTime {
    if (actualEndTime == null) return null;
    return actualEndTime!.difference(createdAt);
  }

  // 使用時間を文字列で取得
  String get totalUsageTimeString {
    final totalTime = totalUsageTime;
    if (totalTime == null) return '未完了';

    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;

    if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
  }

  // 進行時間を文字列で取得
  String get scheduledTimeString {
    final scheduledTime = this.scheduledTime;
    if (scheduledTime == null) return '予定なし';

    final hours = scheduledTime.inHours;
    final minutes = scheduledTime.inMinutes % 60;

    if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
  }

  // 実際の時間を文字列で取得
  String get actualTimeString {
    final actualTime = this.actualTime;
    if (actualTime == null) return '未完了';

    final hours = actualTime.inHours;
    final minutes = actualTime.inMinutes % 60;

    if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
  }
}
