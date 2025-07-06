import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 通知サービスの初期化
  static Future<void> initialize() async {
    // 通知権限の要求
    await _requestPermission();

    // ローカル通知の初期化
    await _initializeLocalNotifications();

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
  static Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('通知権限が許可されました');
    } else {
      print('通知権限が拒否されました');
    }
  }

  /// ローカル通知の初期化
  static Future<void> _initializeLocalNotifications() async {
    const androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// FCMトークンの取得と保存
  static Future<void> _getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCMトークン: $token');
        // TODO: ユーザーのFCMトークンをFirestoreに保存
        await _saveFCMToken(token);
      }
    } catch (e) {
      print('FCMトークン取得エラー: $e');
    }
  }

  /// FCMトークンをFirestoreに保存
  static Future<void> _saveFCMToken(String token) async {
    try {
      // TODO: 現在のユーザーIDを取得してトークンを保存
      // await _firestore.collection('users').doc(userId).update({
      //   'fcmToken': token,
      //   'lastTokenUpdate': FieldValue.serverTimestamp(),
      // });
    } catch (e) {
      print('FCMトークン保存エラー: $e');
    }
  }

  /// フォアグラウンド通知の処理
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('フォアグラウンド通知を受信: ${message.notification?.title}');

    // ローカル通知として表示
    await _showLocalNotification(message);
  }

  /// バックグラウンド通知の処理
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('バックグラウンド通知を受信: ${message.notification?.title}');

    // 通知タップ時の処理
    _navigateToScreen(message.data);
  }

  /// ローカル通知の表示
  static Future<void> _showLocalNotification(RemoteMessage message) async {
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
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      // TODO: 通知データに基づいて適切な画面に遷移
      print('通知がタップされました: ${response.payload}');
    }
  }

  /// 画面遷移の処理
  static void _navigateToScreen(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;

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

  /// 特定のユーザーに通知を送信
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
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
  static Future<void> sendFollowNotification({
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
    );
  }

  /// いいね通知の送信
  static Future<void> sendLikeNotification({
    required String postOwnerId,
    required String likerName,
    required String postId,
    required String postTitle,
  }) async {
    await sendNotificationToUser(
      userId: postOwnerId,
      title: 'いいねが付きました',
      body: '${likerName}さんが「$postTitle」にいいねしました',
      data: {
        'type': 'post',
        'id': postId,
      },
    );
  }

  /// コメント通知の送信
  static Future<void> sendCommentNotification({
    required String postOwnerId,
    required String commenterName,
    required String postId,
    required String postTitle,
  }) async {
    await sendNotificationToUser(
      userId: postOwnerId,
      title: 'コメントが付きました',
      body: '${commenterName}さんが「$postTitle」にコメントしました',
      data: {
        'type': 'post',
        'id': postId,
      },
    );
  }

  /// 予定時刻リマインダー通知の設定
  static Future<void> scheduleReminderNotification({
    required String postId,
    required String title,
    required DateTime scheduledTime,
  }) async {
    // 予定時刻の30分前に通知を設定
    final reminderTime = scheduledTime.subtract(const Duration(minutes: 30));

    if (reminderTime.isAfter(DateTime.now())) {
      // TODO: ローカル通知のスケジュール設定
      // または、Cloud Functionsでスケジュール通知を設定
      await _firestore.collection('scheduled_notifications').add({
        'postId': postId,
        'title': 'リマインダー',
        'body': '「$title」の予定時刻まで30分です',
        'scheduledTime': Timestamp.fromDate(reminderTime),
        'type': 'reminder',
        'processed': false,
      });
    }
  }

  /// 通知履歴の取得
  static Stream<List<Map<String, dynamic>>> getNotificationHistory(
      String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  /// 通知を既読にする
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('通知既読エラー: $e');
    }
  }

  /// 未読通知数の取得
  static Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

/// バックグラウンド通知ハンドラー
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('バックグラウンド通知を受信: ${message.notification?.title}');
}
