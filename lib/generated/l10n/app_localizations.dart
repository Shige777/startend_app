import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// アプリのタイトル
  ///
  /// In ja, this message translates to:
  /// **'StartEnd'**
  String get appTitle;

  /// ホームタブ
  ///
  /// In ja, this message translates to:
  /// **'ホーム'**
  String get homeTab;

  /// 検索タブ
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get searchTab;

  /// コミュニティタブ
  ///
  /// In ja, this message translates to:
  /// **'コミュニティ'**
  String get communityTab;

  /// プロフィールタブ
  ///
  /// In ja, this message translates to:
  /// **'プロフィール'**
  String get profileTab;

  /// 投稿が見つからない場合のメッセージ
  ///
  /// In ja, this message translates to:
  /// **'投稿が見つかりません'**
  String get postNotFound;

  /// 投稿読み込み失敗メッセージ
  ///
  /// In ja, this message translates to:
  /// **'投稿の読み込みに失敗しました'**
  String get loadPostFailed;

  /// ログインが必要な場合のメッセージ
  ///
  /// In ja, this message translates to:
  /// **'ログインが必要です'**
  String get loginRequired;

  /// リアクション追加失敗メッセージ
  ///
  /// In ja, this message translates to:
  /// **'リアクションの追加に失敗しました'**
  String get addReactionFailed;

  /// リアクション更新失敗メッセージ
  ///
  /// In ja, this message translates to:
  /// **'リアクションの更新に失敗しました'**
  String get updateReactionFailed;

  /// 一般的なエラーメッセージ
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました'**
  String get errorOccurred;

  /// 投稿削除ダイアログのタイトル
  ///
  /// In ja, this message translates to:
  /// **'投稿削除'**
  String get deletePost;

  /// 投稿削除確認メッセージ
  ///
  /// In ja, this message translates to:
  /// **'この投稿を削除しますか？\nこの操作は取り消せません。'**
  String get deletePostConfirm;

  /// キャンセルボタン
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get cancel;

  /// 削除ボタン
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get delete;

  /// 投稿削除完了メッセージ
  ///
  /// In ja, this message translates to:
  /// **'投稿を削除しました'**
  String get postDeleted;

  /// 投稿削除失敗メッセージ
  ///
  /// In ja, this message translates to:
  /// **'投稿の削除に失敗しました'**
  String get deletePostFailed;

  /// 投稿詳細画面のタイトル
  ///
  /// In ja, this message translates to:
  /// **'投稿詳細'**
  String get postDetail;

  /// 最近使った絵文字がない場合のメッセージ
  ///
  /// In ja, this message translates to:
  /// **'最近使った絵文字なし'**
  String get recentEmojis;

  /// よく使う絵文字セクションタイトル
  ///
  /// In ja, this message translates to:
  /// **'よく使う絵文字'**
  String get frequentEmojis;

  /// すべての絵文字ピッカーのタイトル
  ///
  /// In ja, this message translates to:
  /// **'すべての絵文字'**
  String get allEmojis;

  /// Googleサインインキャンセル時のメッセージ
  ///
  /// In ja, this message translates to:
  /// **'Googleサインインがキャンセルされました'**
  String get googleSignInCancelled;

  /// 日数表示
  ///
  /// In ja, this message translates to:
  /// **'{count}日'**
  String days(int count);

  /// 時間表示
  ///
  /// In ja, this message translates to:
  /// **'{count}時間'**
  String hours(int count);

  /// 分表示
  ///
  /// In ja, this message translates to:
  /// **'{count}分'**
  String minutes(int count);

  /// 経過時間の表示
  ///
  /// In ja, this message translates to:
  /// **'{days}日{hours}時間{minutes}分'**
  String elapsedTime(int days, int hours, int minutes);

  /// 時間・分のみの経過時間表示
  ///
  /// In ja, this message translates to:
  /// **'{hours}時間{minutes}分'**
  String elapsedTimeHours(int hours, int minutes);

  /// 分のみの経過時間表示
  ///
  /// In ja, this message translates to:
  /// **'{minutes}分'**
  String elapsedTimeMinutes(int minutes);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
