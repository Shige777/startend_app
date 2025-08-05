import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;

  /// 通知サービスの初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    // タイムゾーンの初期化
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // 通知権限の要求
    await _requestPermissions();

    _isInitialized = true;

    // FCMトークンの取得と保存
    await _getFCMToken();

    // フォアグラウンド通知の設定
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // バックグラウンド通知の設定
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // アプリ終了時の通知処理
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// 通知権限の要求
  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  /// FCMトークンの取得と保存
  Future<void> _getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveFCMToken(token);
      }
    } catch (e) {
      // エラーハンドリング
    }
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    } catch (e) {
      // エラーハンドリング
    }
  }

  /// フォアグラウンド通知の処理
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('フォアグラウンド通知を受信: ${message.notification?.title}');

    // ローカル通知として表示
    await _showLocalNotification(message);
  }

  /// バックグラウンド通知の処理
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('バックグラウンド通知を受信: ${message.notification?.title}');

    // 通知タップ時の処理
    _navigateToScreen(message.data);
  }

  /// ローカル通知の表示
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidNotificationDetails = AndroidNotificationDetails(
      'startend_channel',
      'StartEnd通知',
      channelDescription: 'StartEndアプリからの通知',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const iosNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'StartEnd',
      message.notification?.body ?? '',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// 通知タップ時の処理
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      // TODO: 通知データに基づいて適切な画面に遷移
      print('通知がタップされました: ${response.payload}');
    }
  }

  /// 画面遷移の処理
  void _navigateToScreen(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'post':
        // 投稿詳細画面に遷移
        break;
      case 'follow':
        // プロフィール画面に遷移
        break;
      case 'community':
        // コミュニティ画面に遷移
        break;
      default:
        // ホーム画面に遷移
        break;
    }
  }

  /// 通知設定を取得
  Future<Map<String, bool>> _getNotificationSettings(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'push_notifications': prefs.getBool('push_notifications') ?? true,
        'like_notifications': prefs.getBool('like_notifications') ?? true,
        'follow_notifications': prefs.getBool('follow_notifications') ?? true,
        'community_notifications':
            prefs.getBool('community_notifications') ?? true,
        'deadline_notifications':
            prefs.getBool('deadline_notifications') ?? true,
      };
    } catch (e) {
      print('通知設定取得エラー: $e');
      return {
        'push_notifications': true,
        'like_notifications': true,
        'follow_notifications': true,
        'community_notifications': true,
        'deadline_notifications': true,
      };
    }
  }

  /// 特定のユーザーに通知を送信（設定をチェック）
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? notificationType,
  }) async {
    try {
      // 通知設定を確認
      final settings = await _getNotificationSettings(userId);

      // プッシュ通知がOFFの場合は、すべての通知を無効にする
      final pushNotificationsEnabled = settings['push_notifications'] ?? true;
      if (!pushNotificationsEnabled) {
        print('プッシュ通知がOFFのため、すべての通知を送信しません');
        return;
      }

      // 通知タイプに応じて設定をチェック
      bool shouldSend = true;
      if (notificationType != null) {
        switch (notificationType) {
          case 'like':
            shouldSend = settings['like_notifications'] ?? true;
            break;
          case 'follow':
            shouldSend = settings['follow_notifications'] ?? true;
            break;
          case 'community':
            shouldSend = settings['community_notifications'] ?? true;
            break;
          case 'deadline':
            shouldSend = settings['deadline_notifications'] ?? true;
            break;
          default:
            shouldSend = true; // プッシュ通知がONの場合はデフォルトで送信
        }
      }

      // 設定がOFFの場合は通知を送信しない
      if (!shouldSend) {
        print('通知設定がOFFのため、通知を送信しません: $notificationType');
        return;
      }

      // TODO: Cloud Functionsを使用してプッシュ通知を送信
      // または、FCMトークンを使用して直接送信
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('通知送信エラー: $e');
    }
  }

  /// フォロー通知の送信
  Future<void> sendFollowNotification({
    required String targetUserId,
    required String followerName,
    required String followerId,
  }) async {
    await sendNotificationToUser(
      userId: targetUserId,
      title: '新しいフォロワー',
      body: '${followerName}さんがあなたをフォローしました',
      data: {
        'type': 'follow',
        'id': followerId,
      },
      notificationType: 'follow',
    );
  }

  /// いいね通知の送信
  Future<void> sendLikeNotification({
    required String postOwnerId,
    required String likerName,
    required String postId,
    required String postTitle,
  }) async {
    await sendNotificationToUser(
      userId: postOwnerId,
      title: 'いいねが付きました',
      body: '${likerName}さんがいいねしました',
      data: {
        'type': 'post',
        'id': postId,
      },
      notificationType: 'like',
    );
  }

  /// コミュニティ投稿通知の送信
  Future<void> sendCommunityPostNotification({
    required String communityId,
    required String communityName,
    required String postTitle,
    required String posterName,
    required List<String> memberIds,
    required String postId,
  }) async {
    try {
      // 投稿者以外のメンバーに通知を送信
      for (final memberId in memberIds) {
        if (memberId != postId) {
          // 投稿者自身には通知しない
          await sendNotificationToUser(
            userId: memberId,
            title: '$communityNameで新しい投稿',
            body: '${posterName}さんが投稿しました',
            data: {
              'type': 'community_post',
              'communityId': communityId,
              'postId': postId,
            },
            notificationType: 'community',
          );
        }
      }
    } catch (e) {
      print('コミュニティ投稿通知送信エラー: $e');
    }
  }

  /// 予定時刻リマインダー通知の設定
  Future<void> scheduleReminderNotification({
    required String postId,
    required String title,
    required DateTime scheduledTime,
    required String userId,
  }) async {
    // 通知設定を確認
    final settings = await _getNotificationSettings(userId);
    final deadlineNotificationsEnabled =
        settings['deadline_notifications'] ?? true;

    // 設定がOFFの場合は通知をスケジュールしない
    if (!deadlineNotificationsEnabled) {
      print('終了予定時刻通知がOFFのため、通知をスケジュールしません');
      return;
    }

    // 予定時刻の5分前に通知を設定
    final reminderTime = scheduledTime.subtract(const Duration(minutes: 5));

    if (reminderTime.isAfter(DateTime.now())) {
      // TODO: ローカル通知のスケジュール設定
      // または、Cloud Functionsでスケジュール通知を設定
      await _firestore.collection('scheduled_notifications').add({
        'postId': postId,
        'userId': userId,
        'title': '終了予定時刻リマインダー',
        'body': '「$title」の終了予定時刻まで5分です',
        'scheduledTime': Timestamp.fromDate(reminderTime),
        'type': 'deadline',
        'processed': false,
      });

      print('終了予定時刻通知をスケジュールしました: $reminderTime');
    } else {
      print('終了予定時刻が過去のため、通知をスケジュールしません');
    }
  }

  /// 終了予定時刻通知のスケジュール
  Future<void> scheduleDeadlineNotification({
    required String postId,
    required String title,
    required DateTime scheduledTime,
    required String userId,
  }) async {
    // 通知設定を確認
    final settings = await _getNotificationSettings(userId);

    // プッシュ通知がOFFの場合は、すべての通知を無効にする
    final pushNotificationsEnabled = settings['push_notifications'] ?? true;
    if (!pushNotificationsEnabled) {
      print('プッシュ通知がOFFのため、終了予定時刻通知をスケジュールしません');
      return;
    }

    final deadlineNotificationsEnabled =
        settings['deadline_notifications'] ?? true;

    // 設定がOFFの場合は通知をスケジュールしない
    if (!deadlineNotificationsEnabled) {
      print('終了予定時刻通知がOFFのため、通知をスケジュールしません');
      return;
    }

    // 予定時刻の5分前に通知を設定
    final reminderTime = scheduledTime.subtract(const Duration(minutes: 5));

    if (reminderTime.isAfter(DateTime.now())) {
      // TODO: ローカル通知のスケジュール設定
      // または、Cloud Functionsでスケジュール通知を設定
      await _firestore.collection('scheduled_notifications').add({
        'postId': postId,
        'userId': userId,
        'title': '終了予定時刻リマインダー',
        'body': '「$title」の終了予定時刻まで5分です',
        'scheduledTime': Timestamp.fromDate(reminderTime),
        'type': 'deadline',
        'processed': false,
      });

      print('終了予定時刻通知をスケジュールしました: $reminderTime');
    } else {
      print('終了予定時刻が過去のため、通知をスケジュールしません');
    }
  }

  /// 通知履歴の取得
  Stream<List<Map<String, dynamic>>> getNotificationHistory(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      // クライアント側でソート
      notifications.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return notifications;
    });
  }

  /// 通知を既読にする
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('通知既読エラー: $e');
    }
  }

  /// 全ての通知を既読にする
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();

      // 未読の通知を取得
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      // バッチで全て既読に更新
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('全通知既読エラー: $e');
    }
  }

  /// 未読通知数の取得
  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // 集中投稿の5分前通知をスケジュール
  Future<void> scheduleConcentrationNotification(PostModel post) async {
    if (!_isInitialized) await initialize();

    if (post.scheduledEndTime == null) return;

    final notificationTime =
        post.scheduledEndTime!.subtract(const Duration(minutes: 5));

    // 過去の時刻の場合は通知しない
    if (notificationTime.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'concentration_channel',
      '集中通知',
      channelDescription: '集中投稿の終了5分前通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final notificationId = _generateNotificationId(post.id, 'concentration');

    await _localNotifications.zonedSchedule(
      notificationId,
      '集中時間終了！',
      '「${post.title}」の集中時間が終了しました。',
      tz.TZDateTime.from(notificationTime, tz.local),
      platformChannelSpecifics,
      payload: 'concentration_${post.id}',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('集中通知をスケジュール: ${post.title} - ${notificationTime}');
  }

  // 進行中投稿の24時間前通知をスケジュール
  Future<void> scheduleProgressNotification(PostModel post) async {
    if (!_isInitialized) await initialize();

    if (post.scheduledEndTime == null) return;

    final notificationTime =
        post.scheduledEndTime!.subtract(const Duration(hours: 24));

    // 過去の時刻の場合は通知しない
    if (notificationTime.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'progress_channel',
      '進行中通知',
      channelDescription: '進行中投稿の24時間前通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final notificationId = _generateNotificationId(post.id, 'progress');

    await _localNotifications.zonedSchedule(
      notificationId,
      '終了予定まであと24時間！',
      '「${post.title}」の終了予定まであと24時間です。進捗はいかがですか？',
      tz.TZDateTime.from(notificationTime, tz.local),
      platformChannelSpecifics,
      payload: 'progress_${post.id}',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('進行中通知をスケジュール: ${post.title} - ${notificationTime}');
  }

  // 投稿の通知をキャンセル
  Future<void> cancelPostNotifications(String postId) async {
    if (!_isInitialized) await initialize();

    final concentrationId = _generateNotificationId(postId, 'concentration');
    final progressId = _generateNotificationId(postId, 'progress');

    await _localNotifications.cancel(concentrationId);
    await _localNotifications.cancel(progressId);

    debugPrint('投稿の通知をキャンセル: $postId');
  }

  // 投稿作成時の通知スケジュール
  Future<void> schedulePostNotifications(PostModel post) async {
    if (post.type == PostType.start && !post.isCompleted) {
      // 集中投稿の場合は5分前通知
      if (post.status == PostStatus.concentration) {
        await scheduleConcentrationNotification(post);
      } else if (post.status == PostStatus.inProgress) {
        // 進行中投稿の場合は24時間前通知
        await scheduleProgressNotification(post);
      }
    }
  }

  // 通知IDの生成（投稿IDとタイプから一意のIDを生成）
  int _generateNotificationId(String postId, String type) {
    return '${postId}_$type'.hashCode;
  }

  // 全ての通知をキャンセル
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) await initialize();
    await _localNotifications.cancelAll();
  }

  // 予定された通知の一覧を取得
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) await initialize();
    return await _localNotifications.pendingNotificationRequests();
  }
}

/// バックグラウンド通知ハンドラー
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('バックグラウンド通知を受信: ${message.notification?.title}');
}
