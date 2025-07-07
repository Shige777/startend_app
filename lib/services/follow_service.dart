import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class FollowService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ユーザーをフォローする
  static Future<bool> followUser({
    required String followerId,
    required String followingId,
    required String followerName,
  }) async {
    if (followerId == followingId) {
      return false; // 自分自身をフォローできない
    }

    try {
      final batch = _firestore.batch();

      // フォロー関係を作成
      final followRef =
          _firestore.collection('follows').doc('${followerId}_$followingId');
      batch.set(followRef, {
        'followerId': followerId,
        'followingId': followingId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // フォロワー数を更新
      final followerUserRef = _firestore.collection('users').doc(followerId);
      batch.update(followerUserRef, {
        'followingCount': FieldValue.increment(1),
      });

      // フォロー数を更新
      final followingUserRef = _firestore.collection('users').doc(followingId);
      batch.update(followingUserRef, {
        'followerCount': FieldValue.increment(1),
      });

      await batch.commit();

      // フォロー通知を送信
      await NotificationService().sendFollowNotification(
        targetUserId: followingId,
        followerId: followerId,
        followerName: followerName,
      );

      return true;
    } catch (e) {
      print('フォローエラー: $e');
      return false;
    }
  }

  /// ユーザーのフォローを解除する
  static Future<bool> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final batch = _firestore.batch();

      // フォロー関係を削除
      final followRef =
          _firestore.collection('follows').doc('${followerId}_$followingId');
      batch.delete(followRef);

      // フォロワー数を更新
      final followerUserRef = _firestore.collection('users').doc(followerId);
      batch.update(followerUserRef, {
        'followingCount': FieldValue.increment(-1),
      });

      // フォロー数を更新
      final followingUserRef = _firestore.collection('users').doc(followingId);
      batch.update(followingUserRef, {
        'followerCount': FieldValue.increment(-1),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('フォロー解除エラー: $e');
      return false;
    }
  }

  /// フォロー状態を確認する
  static Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final doc = await _firestore
          .collection('follows')
          .doc('${followerId}_$followingId')
          .get();
      return doc.exists;
    } catch (e) {
      print('フォロー状態確認エラー: $e');
      return false;
    }
  }

  /// 相互フォロー状態を確認する
  static Future<bool> isMutualFollow({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final futures = await Future.wait([
        isFollowing(followerId: userId1, followingId: userId2),
        isFollowing(followerId: userId2, followingId: userId1),
      ]);
      return futures[0] && futures[1];
    } catch (e) {
      print('相互フォロー確認エラー: $e');
      return false;
    }
  }

  /// フォロワー一覧を取得する
  static Stream<List<UserModel>> getFollowers(String userId) {
    return _firestore
        .collection('follows')
        .where('followingId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<UserModel> followers = [];

      for (final doc in snapshot.docs) {
        final followerId = doc.data()['followerId'] as String;

        // 自分自身を除外
        if (followerId == userId) {
          continue;
        }

        final userDoc =
            await _firestore.collection('users').doc(followerId).get();

        if (userDoc.exists) {
          followers.add(UserModel.fromFirestore(userDoc));
        }
      }

      return followers;
    });
  }

  /// フォロー中のユーザー一覧を取得する
  static Stream<List<UserModel>> getFollowing(String userId) {
    return _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<UserModel> following = [];

      for (final doc in snapshot.docs) {
        final followingId = doc.data()['followingId'] as String;

        // 自分自身を除外
        if (followingId == userId) {
          continue;
        }

        final userDoc =
            await _firestore.collection('users').doc(followingId).get();

        if (userDoc.exists) {
          following.add(UserModel.fromFirestore(userDoc));
        }
      }

      return following;
    });
  }

  /// 相互フォローのユーザー一覧を取得する
  static Stream<List<UserModel>> getMutualFollows(String userId) {
    return _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<UserModel> mutualFollows = [];

      for (final doc in snapshot.docs) {
        final followingId = doc.data()['followingId'] as String;

        // 相互フォローかチェック
        final isMutual =
            await isMutualFollow(userId1: userId, userId2: followingId);

        if (isMutual) {
          final userDoc =
              await _firestore.collection('users').doc(followingId).get();
          if (userDoc.exists) {
            mutualFollows.add(UserModel.fromFirestore(userDoc));
          }
        }
      }

      return mutualFollows;
    });
  }

  /// おすすめユーザーを取得する
  static Future<List<UserModel>> getRecommendedUsers({
    required String currentUserId,
    int limit = 10,
  }) async {
    try {
      // 現在フォローしているユーザーのIDを取得
      final followingSnapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUserId)
          .get();

      final followingIds = followingSnapshot.docs
          .map((doc) => doc.data()['followingId'] as String)
          .toList();

      // 自分のIDも除外リストに追加
      followingIds.add(currentUserId);

      // フォロワー数が多いユーザーを取得（フォローしていないユーザーのみ）
      final usersSnapshot = await _firestore
          .collection('users')
          .where('id',
              whereNotIn:
                  followingIds.take(10).toList()) // Firestoreの制限により最大10個
          .orderBy('followerCount', descending: true)
          .limit(limit)
          .get();

      return usersSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('おすすめユーザー取得エラー: $e');
      return [];
    }
  }

  /// フォロー申請を送信する（プライベートアカウント用）
  static Future<bool> sendFollowRequest({
    required String requesterId,
    required String targetUserId,
    required String requesterName,
  }) async {
    try {
      await _firestore.collection('follow_requests').add({
        'requesterId': requesterId,
        'targetUserId': targetUserId,
        'requesterName': requesterName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // フォロー申請通知を送信
      await NotificationService().sendNotificationToUser(
        userId: targetUserId,
        title: 'フォロー申請',
        body: '${requesterName}さんからフォロー申請が届きました',
        data: {
          'type': 'follow_request',
          'id': requesterId,
        },
      );

      return true;
    } catch (e) {
      print('フォロー申請エラー: $e');
      return false;
    }
  }

  /// フォロー申請を承認する
  static Future<bool> approveFollowRequest({
    required String requestId,
    required String requesterId,
    required String targetUserId,
    required String requesterName,
  }) async {
    try {
      final batch = _firestore.batch();

      // フォロー申請のステータスを更新
      final requestRef =
          _firestore.collection('follow_requests').doc(requestId);
      batch.update(requestRef, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // フォロー関係を作成
      final followRef =
          _firestore.collection('follows').doc('${requesterId}_$targetUserId');
      batch.set(followRef, {
        'followerId': requesterId,
        'followingId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // フォロー数を更新
      final requesterRef = _firestore.collection('users').doc(requesterId);
      batch.update(requesterRef, {
        'followingCount': FieldValue.increment(1),
      });

      final targetRef = _firestore.collection('users').doc(targetUserId);
      batch.update(targetRef, {
        'followerCount': FieldValue.increment(1),
      });

      await batch.commit();

      // 承認通知を送信
      await NotificationService().sendNotificationToUser(
        userId: requesterId,
        title: 'フォロー申請が承認されました',
        body: 'フォロー申請が承認されました',
        data: {
          'type': 'follow_approved',
          'id': targetUserId,
        },
      );

      return true;
    } catch (e) {
      print('フォロー申請承認エラー: $e');
      return false;
    }
  }

  /// フォロー申請を拒否する
  static Future<bool> rejectFollowRequest(String requestId) async {
    try {
      await _firestore.collection('follow_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('フォロー申請拒否エラー: $e');
      return false;
    }
  }

  /// フォロー申請一覧を取得する
  static Stream<List<Map<String, dynamic>>> getFollowRequests(String userId) {
    return _firestore
        .collection('follow_requests')
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  /// ユーザー検索
  static Future<List<UserModel>> searchUsers({
    required String query,
    required String currentUserId,
    int limit = 20,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      // 表示名での検索
      final nameQuery = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: query + 'z')
          .limit(limit)
          .get();

      // ユーザー名での検索
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: query + 'z')
          .limit(limit)
          .get();

      final Set<String> userIds = {};
      final List<UserModel> users = [];

      // 重複を除去しながら結果をマージ
      for (final doc in [...nameQuery.docs, ...usernameQuery.docs]) {
        final user = UserModel.fromFirestore(doc);
        if (!userIds.contains(user.id) && user.id != currentUserId) {
          userIds.add(user.id);
          users.add(user);
        }
      }

      return users.take(limit).toList();
    } catch (e) {
      print('ユーザー検索エラー: $e');
      return [];
    }
  }
}
