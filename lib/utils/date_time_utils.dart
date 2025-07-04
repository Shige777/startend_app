import 'package:intl/intl.dart';

class DateTimeUtils {
  // 日時をフォーマットする（例: 2024年1月1日 12:00）
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy年M月d日 HH:mm').format(dateTime);
  }

  // 日付をフォーマットする（例: 2024年1月1日）
  static String formatDate(DateTime dateTime) {
    return DateFormat('yyyy年M月d日').format(dateTime);
  }

  // 時刻をフォーマットする（例: 12:00）
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  // 相対時間を取得する（例: 2時間前、1日前）
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }

  // 残り時間を取得する（例: あと2時間、あと1日）
  static String getRemainingTime(DateTime targetDateTime) {
    final now = DateTime.now();
    final difference = targetDateTime.difference(now);

    if (difference.isNegative) {
      return '期限切れ';
    }

    if (difference.inDays > 0) {
      return 'あと${difference.inDays}日';
    } else if (difference.inHours > 0) {
      return 'あと${difference.inHours}時間';
    } else if (difference.inMinutes > 0) {
      return 'あと${difference.inMinutes}分';
    } else {
      return 'まもなく';
    }
  }

  // 24時間以内かどうかを判定
  static bool isWithin24Hours(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime).abs();
    return difference.inHours <= 24;
  }

  // 今日かどうかを判定
  static bool isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  // 昨日かどうかを判定
  static bool isYesterday(DateTime dateTime) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }

  // 期間をフォーマットする（例: 2時間30分）
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else {
      return '${minutes}分';
    }
  }

  // 集中投稿かどうかを判定（24時間以内に完了予定）
  static bool isConcentrationPost(
    DateTime createdAt,
    DateTime? scheduledEndTime,
  ) {
    if (scheduledEndTime == null) return false;

    final timeDiff = scheduledEndTime.difference(createdAt);
    return timeDiff.inHours <= 24;
  }
}
