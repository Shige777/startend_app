// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'StartEnd';

  @override
  String get homeTab => 'ホーム';

  @override
  String get searchTab => '検索';

  @override
  String get communityTab => 'コミュニティ';

  @override
  String get profileTab => 'プロフィール';

  @override
  String get postNotFound => '投稿が見つかりません';

  @override
  String get loadPostFailed => '投稿の読み込みに失敗しました';

  @override
  String get loginRequired => 'ログインが必要です';

  @override
  String get addReactionFailed => 'リアクションの追加に失敗しました';

  @override
  String get updateReactionFailed => 'リアクションの更新に失敗しました';

  @override
  String get errorOccurred => 'エラーが発生しました';

  @override
  String get deletePost => '投稿削除';

  @override
  String get deletePostConfirm => 'この投稿を削除しますか？\nこの操作は取り消せません。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get postDeleted => '投稿を削除しました';

  @override
  String get deletePostFailed => '投稿の削除に失敗しました';

  @override
  String get postDetail => '投稿詳細';

  @override
  String get recentEmojis => '最近使った絵文字なし';

  @override
  String get frequentEmojis => 'よく使う絵文字';

  @override
  String get allEmojis => 'すべての絵文字';

  @override
  String get googleSignInCancelled => 'Googleサインインがキャンセルされました';

  @override
  String days(int count) {
    return '$count日';
  }

  @override
  String hours(int count) {
    return '$count時間';
  }

  @override
  String minutes(int count) {
    return '$count分';
  }

  @override
  String elapsedTime(int days, int hours, int minutes) {
    return '$days日$hours時間$minutes分';
  }

  @override
  String elapsedTimeHours(int hours, int minutes) {
    return '$hours時間$minutes分';
  }

  @override
  String elapsedTimeMinutes(int minutes) {
    return '$minutes分';
  }
}
