import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// データ削除スクリプト
/// メールでの削除リクエストを効率化するためのツール
class DataDeletionScript {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// ユーザーの全データを削除
  Future<void> deleteUserData(
    String userEmail, {
    bool deleteAnalytics = true,
    bool deleteLogs = true,
    bool deleteBackups = true,
  }) async {
    try {
      print('データ削除開始: $userEmail');

      // 1. Firestoreデータの削除
      await _deleteFirestoreData(userEmail);

      // 2. Storageデータの削除
      await _deleteStorageData(userEmail);

      // 3. 認証データの削除
      await _deleteAuthData(userEmail);

      // 4. Analyticsデータの削除（手動）
      if (deleteAnalytics) {
        print('Analyticsデータの削除はFirebase Consoleで手動実行が必要です');
      }

      // 5. ログデータの削除（手動）
      if (deleteLogs) {
        print('ログデータの削除はFirebase Consoleで手動実行が必要です');
      }

      // 6. バックアップデータの削除
      if (deleteBackups) {
        await _deleteBackupData(userEmail);
      }

      print('データ削除完了: $userEmail');
    } catch (e) {
      print('データ削除エラー: $e');
      rethrow;
    }
  }

  /// Firestoreデータの削除
  Future<void> _deleteFirestoreData(String userEmail) async {
    print('Firestoreデータ削除中...');

    // ユーザーIDを取得
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isEmpty) {
      print('ユーザーが見つかりません: $userEmail');
      return;
    }

    final userId = userQuery.docs.first.id;

    // 削除対象のコレクション
    final collections = [
      'users',
      'posts',
      'communities',
      'follows',
      'notifications',
      'activity_logs',
    ];

    for (final collection in collections) {
      try {
        // ユーザー関連のデータを削除
        final query = await _firestore
            .collection(collection)
            .where('userId', isEqualTo: userId)
            .get();

        for (final doc in query.docs) {
          await doc.reference.delete();
          print('削除: $collection/${doc.id}');
        }
      } catch (e) {
        print('$collection の削除でエラー: $e');
      }
    }
  }

  /// Storageデータの削除
  Future<void> _deleteStorageData(String userEmail) async {
    print('Storageデータ削除中...');

    try {
      // ユーザーIDを取得
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .get();

      if (userQuery.docs.isEmpty) {
        print('ユーザーが見つかりません: $userEmail');
        return;
      }

      final userId = userQuery.docs.first.id;

      // プロフィール画像の削除
      final profileRef = _storage.ref('profile_images/$userId.jpg');
      try {
        await profileRef.delete();
        print('プロフィール画像削除: $userId');
      } catch (e) {
        print('プロフィール画像削除エラー: $e');
      }

      // 投稿画像の削除
      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();

      for (final post in postsQuery.docs) {
        final postData = post.data();
        if (postData['imageUrl'] != null) {
          try {
            final imageRef = _storage.refFromURL(postData['imageUrl']);
            await imageRef.delete();
            print('投稿画像削除: ${post.id}');
          } catch (e) {
            print('投稿画像削除エラー: $e');
          }
        }
      }
    } catch (e) {
      print('Storage削除エラー: $e');
    }
  }

  /// 認証データの削除
  Future<void> _deleteAuthData(String userEmail) async {
    print('認証データ削除中...');

    try {
      // 管理者権限が必要なため、手動での削除を推奨
      print('認証データの削除はFirebase Consoleで手動実行が必要です');
      print('Firebase Console → Authentication → Users → 該当ユーザーを削除');
    } catch (e) {
      print('認証データ削除エラー: $e');
    }
  }

  /// バックアップデータの削除
  Future<void> _deleteBackupData(String userEmail) async {
    print('バックアップデータ削除中...');

    try {
      // ユーザーIDを取得
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .get();

      if (userQuery.docs.isEmpty) {
        print('ユーザーが見つかりません: $userEmail');
        return;
      }

      final userId = userQuery.docs.first.id;

      // バックアップコレクションの削除
      final backupQuery = await _firestore
          .collection('backups')
          .where('userId', isEqualTo: userId)
          .get();

      for (final backup in backupQuery.docs) {
        await backup.reference.delete();
        print('バックアップ削除: ${backup.id}');
      }

      // Storageバックアップの削除
      final backupRef = _storage.ref('backups/$userId');
      try {
        await backupRef.delete();
        print('Storageバックアップ削除: $userId');
      } catch (e) {
        print('Storageバックアップ削除エラー: $e');
      }
    } catch (e) {
      print('バックアップ削除エラー: $e');
    }
  }

  /// 部分的なデータ削除
  Future<void> deletePartialData(
      String userEmail, List<String> dataTypes) async {
    print('部分データ削除開始: $userEmail');
    print('削除対象: ${dataTypes.join(', ')}');

    for (final dataType in dataTypes) {
      switch (dataType) {
        case 'posts':
          await _deletePosts(userEmail);
          break;
        case 'profile':
          await _deleteProfileData(userEmail);
          break;
        case 'notifications':
          await _deleteNotifications(userEmail);
          break;
        case 'search_history':
          await _deleteSearchHistory(userEmail);
          break;
        case 'activity_logs':
          await _deleteActivityLogs(userEmail);
          break;
        default:
          print('不明なデータタイプ: $dataType');
      }
    }
  }

  /// 投稿データの削除
  Future<void> _deletePosts(String userEmail) async {
    print('投稿データ削除中...');

    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isEmpty) return;

    final userId = userQuery.docs.first.id;

    final postsQuery = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .get();

    for (final post in postsQuery.docs) {
      await post.reference.delete();
      print('投稿削除: ${post.id}');
    }
  }

  /// プロフィールデータの削除
  Future<void> _deleteProfileData(String userEmail) async {
    print('プロフィールデータ削除中...');

    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isEmpty) return;

    final userDoc = userQuery.docs.first;
    await userDoc.reference.update({
      'displayName': '削除済みユーザー',
      'profileImageUrl': null,
      'bio': null,
    });

    print('プロフィールデータ更新完了');
  }

  /// 通知データの削除
  Future<void> _deleteNotifications(String userEmail) async {
    print('通知データ削除中...');

    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isEmpty) return;

    final userId = userQuery.docs.first.id;

    final notificationsQuery = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();

    for (final notification in notificationsQuery.docs) {
      await notification.reference.delete();
      print('通知削除: ${notification.id}');
    }
  }

  /// 検索履歴の削除
  Future<void> _deleteSearchHistory(String userEmail) async {
    print('検索履歴削除中...');

    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isEmpty) return;

    final userId = userQuery.docs.first.id;

    final searchHistoryQuery = await _firestore
        .collection('search_history')
        .where('userId', isEqualTo: userId)
        .get();

    for (final history in searchHistoryQuery.docs) {
      await history.reference.delete();
      print('検索履歴削除: ${history.id}');
    }
  }

  /// アクティビティログの削除
  Future<void> _deleteActivityLogs(String userEmail) async {
    print('アクティビティログ削除中...');

    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isEmpty) return;

    final userId = userQuery.docs.first.id;

    final activityLogsQuery = await _firestore
        .collection('activity_logs')
        .where('userId', isEqualTo: userId)
        .get();

    for (final log in activityLogsQuery.docs) {
      await log.reference.delete();
      print('アクティビティログ削除: ${log.id}');
    }
  }
}

/// メイン関数（テスト用）
void main() async {
  // Firebase初期化
  await Firebase.initializeApp();

  final script = DataDeletionScript();

  // 使用例
  // await script.deleteUserData('user@example.com');
  // await script.deletePartialData('user@example.com', ['posts', 'notifications']);

  print('データ削除スクリプト準備完了');
}
