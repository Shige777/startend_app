import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  final Map<String, List<String>> reactions; // リアクション emoji -> [userId1, userId2, ...]
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
    this.reactions = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // タイムスタンプ処理を安全にする
    DateTime? parseTimestamp(dynamic timestamp) {
      if (timestamp == null) return null;
      try {
        if (timestamp is Timestamp) {
          return timestamp.toDate();
        } else if (timestamp is Map<String, dynamic>) {
          // iOSの場合、TimestampがMapとして保存されることがある
          final seconds = timestamp['_seconds'] as int?;
          final nanoseconds = timestamp['_nanoseconds'] as int?;
          if (seconds != null) {
            return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          }
        }
        return null;
      } catch (e) {
        if (kDebugMode) {
          print('タイムスタンプ解析エラー: $e');
        }
        return null;
      }
    }

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
      scheduledEndTime: parseTimestamp(data['scheduledEndTime']),
      actualEndTime: parseTimestamp(data['actualEndTime']),
      privacyLevel: PrivacyLevel.values.firstWhere(
        (e) => e.toString() == 'PrivacyLevel.${data['privacyLevel']}',
        orElse: () => PrivacyLevel.public,
      ),
      communityIds: List<String>.from(data['communityIds'] ?? []),
      likedByUserIds: List<String>.from(data['likedByUserIds'] ?? []),
      likeCount: data['likeCount'] ?? 0,
      reactions: _parseReactions(data['reactions']),
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, List<String>> _parseReactions(dynamic reactionsData) {
    if (reactionsData == null) return {};
    
    try {
      final Map<String, dynamic> reactionsMap = Map<String, dynamic>.from(reactionsData);
      return reactionsMap.map((emoji, userIds) {
        return MapEntry(emoji, List<String>.from(userIds ?? []));
      });
    } catch (e) {
      if (kDebugMode) {
        print('リアクションデータ解析エラー: $e');
      }
      return {};
    }
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
      'reactions': reactions,
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
    Map<String, List<String>>? reactions,
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
      reactions: reactions ?? this.reactions,
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

  // リアクション関連のヘルパーメソッド
  bool hasReaction(String emoji, String userId) {
    return reactions[emoji]?.contains(userId) ?? false;
  }

  int getReactionCount(String emoji) {
    return reactions[emoji]?.length ?? 0;
  }

  int getTotalReactionCount() {
    return reactions.values.fold(0, (sum, userIds) => sum + userIds.length);
  }

  List<String> getPopularReactions({int limit = 5}) {
    final sortedReactions = reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return sortedReactions.take(limit).map((e) => e.key).toList();
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

    // 未完了の場合は、終了予定時刻を超えないように制限
    if (scheduledEndTime != null) {
      final now = DateTime.now();
      final scheduledEnd = scheduledEndTime!;

      // 現在時刻が終了予定時刻を超えている場合は、終了予定時刻までの時間を返す
      if (now.isAfter(scheduledEnd)) {
        return scheduledEnd.difference(createdAt);
      }
    }

    return DateTime.now().difference(createdAt);
  }

  // 使用時間を計算（実際にかかった時間のみ）
  Duration? get totalUsageTime {
    if (!isCompleted) return null;

    // 実際にかかった時間のみを返す
    return actualEndTime!.difference(createdAt);
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

  // 経過時間を文字列で取得
  String get elapsedTimeString {
    final elapsedTime = this.elapsedTime;
    if (elapsedTime == null) return '計算中';

    final hours = elapsedTime.inHours;
    final minutes = elapsedTime.inMinutes % 60;

    if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
  }
}
