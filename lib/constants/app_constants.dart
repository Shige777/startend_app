class AppConstants {
  // アプリ情報
  static const String appName = 'startend';
  static const String appVersion = '1.0.0';

  // 投稿関連
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB（圧縮後）
  static const int maxTitleLength = 100;
  static const int maxCommentLength = 500;
  static const Duration concentrationPeriod = Duration(hours: 24);
  static const Duration displayPeriod = Duration(hours: 24);

  // コミュニティ関連
  static const int maxCommunityNameLength = 50;
  static const int maxCommunityDescriptionLength = 200;
  static const int maxMembersPerCommunity = 1000;

  // UI関連
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;

  // コミュニティジャンル
  static const List<String> communityGenres = [
    '勉強・学習',
    '仕事・キャリア',
    '健康・フィットネス',
    '趣味・娯楽',
    '創作活動',
    'プログラミング',
    '読書',
    '料理',
    '旅行',
    'その他',
  ];

  // 投稿公開範囲
  static const List<String> privacyOptions = [
    '全体公開',
    '相互フォローのみ',
    'コミュニティのみ',
    '相互フォロー + コミュニティのみ',
  ];
}
