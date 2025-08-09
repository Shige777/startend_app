// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'StartEnd';

  @override
  String get homeTab => 'Home';

  @override
  String get searchTab => 'Search';

  @override
  String get communityTab => 'Community';

  @override
  String get profileTab => 'Profile';

  @override
  String get postNotFound => 'Post not found';

  @override
  String get loadPostFailed => 'Failed to load post';

  @override
  String get loginRequired => 'Login required';

  @override
  String get addReactionFailed => 'Failed to add reaction';

  @override
  String get updateReactionFailed => 'Failed to update reaction';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get deletePost => 'Delete Post';

  @override
  String get deletePostConfirm =>
      'Are you sure you want to delete this post?\nThis action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get postDeleted => 'Post deleted';

  @override
  String get deletePostFailed => 'Failed to delete post';

  @override
  String get postDetail => 'Post Details';

  @override
  String get recentEmojis => 'No recent emojis';

  @override
  String get frequentEmojis => 'Frequently used emojis';

  @override
  String get allEmojis => 'All Emojis';

  @override
  String get googleSignInCancelled => 'Google sign-in was cancelled';

  @override
  String days(int count) {
    return '$count day(s)';
  }

  @override
  String hours(int count) {
    return '$count hour(s)';
  }

  @override
  String minutes(int count) {
    return '$count minute(s)';
  }

  @override
  String elapsedTime(int days, int hours, int minutes) {
    return '$days day(s) $hours hour(s) $minutes minute(s)';
  }

  @override
  String elapsedTimeHours(int hours, int minutes) {
    return '$hours hour(s) $minutes minute(s)';
  }

  @override
  String elapsedTimeMinutes(int minutes) {
    return '$minutes minute(s)';
  }
}
