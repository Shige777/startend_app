import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

      // フォローする側のfollowingIdsに追加
      final followerUserRef = _firestore.collection('users').doc(followerId);
      batch.update(followerUserRef, {
        'followingIds': FieldValue.arrayUnion([followingId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // フォローされる側のfollowerIdsに追加
      final followingUserRef = _firestore.collection('users').doc(followingId);
      batch.update(followingUserRef, {
        'followerIds': FieldValue.arrayUnion([followerId]),
        'updatedAt': FieldValue.serverTimestamp(),
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
      if (kDebugMode) {
        print('フォローエラー: $e');
      }
      return false;
    }
  }

  /// ユーザーのフォローを解除する
  static Future<bool> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      if (kDebugMode) {
        print('フォロー解除開始: $followerId -> $followingId');
      }

      final batch = _firestore.batch();

      // フォローする側のfollowingIdsから削除
      final followerUserRef = _firestore.collection('users').doc(followerId);
      final followerUpdateData = {
        'followingIds': FieldValue.arrayRemove([followingId]),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (kDebugMode) {
        print('フォロワー更新データ: $followerUpdateData');
      }

      batch.update(followerUserRef, followerUpdateData);

      // フォローされる側のfollowerIdsから削除
      final followingUserRef = _firestore.collection('users').doc(followingId);
      final followingUpdateData = {
        'followerIds': FieldValue.arrayRemove([followerId]),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (kDebugMode) {
        print('フォロー先更新データ: $followingUpdateData');
      }

      batch.update(followingUserRef, followingUpdateData);

      await batch.commit();

      if (kDebugMode) {
        print('フォロー解除成功');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('フォロー解除エラー: $e');
        print('Firestore権限エラーの可能性 - ルールを確認してください');
      }
      return false;
    }
  }

  /// フォロー状態を確認する
  static Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final doc = await _firestore.collection('users').doc(followerId).get();

      if (!doc.exists) return false;

      final userData = doc.data() as Map<String, dynamic>;
      final followingIds = List<String>.from(userData['followingIds'] ?? []);

      return followingIds.contains(followingId);
    } catch (e) {
      if (kDebugMode) {
        print('フォロー状態確認エラー: $e');
      }
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
      if (kDebugMode) {
        print('相互フォロー確認エラー: $e');
      }
      return false;
    }
  }

  /// フォロワー一覧を取得する
  static Stream<List<UserModel>> getFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<UserModel> followers = [];

      if (!snapshot.exists) {
        return followers;
      }

      final userData = snapshot.data() as Map<String, dynamic>;
      final followerIds = List<String>.from(userData['followerIds'] ?? []);

      // フォロワーIDが空の場合は空のリストを返す
      if (followerIds.isEmpty) {
        return followers;
      }

      // 10個ずつバッチで処理（Firestoreの制限）
      for (int i = 0; i < followerIds.length; i += 10) {
        final batch = followerIds.skip(i).take(10).toList();

        final querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final batchUsers = querySnapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();

        followers.addAll(batchUsers);
      }

      return followers;
    });
  }

  /// フォロー中のユーザー一覧を取得する
  static Stream<List<UserModel>> getFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<UserModel> following = [];

      if (!snapshot.exists) {
        return following;
      }

      final userData = snapshot.data() as Map<String, dynamic>;
      final followingIds = List<String>.from(userData['followingIds'] ?? []);

      // フォロー中IDが空の場合は空のリストを返す
      if (followingIds.isEmpty) {
        return following;
      }

      // 10個ずつバッチで処理（Firestoreの制限）
      for (int i = 0; i < followingIds.length; i += 10) {
        final batch = followingIds.skip(i).take(10).toList();

        final querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final batchUsers = querySnapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();

        following.addAll(batchUsers);
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
      // インデックスエラーを回避するため、orderByを削除してクライアント側でソート
      final usersSnapshot = await _firestore
          .collection('users')
          .where('id',
              whereNotIn:
                  followingIds.take(10).toList()) // Firestoreの制限により最大10個
          .limit(limit)
          .get();

      final users = usersSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // インデックスエラーを回避するため、ソートを削除

      return users;
    } catch (e) {
      if (kDebugMode) {
        print('おすすめユーザー取得エラー: $e');
      }
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
      if (kDebugMode) {
        print('フォロー申請エラー: $e');
      }
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
      if (kDebugMode) {
        print('フォロー申請承認エラー: $e');
      }
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
      if (kDebugMode) {
        print('フォロー申請拒否エラー: $e');
      }
      return false;
    }
  }

  /// フォロー申請一覧を取得する
  static Stream<List<Map<String, dynamic>>> getFollowRequests(String userId) {
    return _firestore
        .collection('follow_requests')
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      // クライアント側でソート
      requests.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return requests;
    });
  }

  /// フォローリクエストが既に送信済みかチェックする
  static Future<bool> hasFollowRequestSent({
    required String requesterId,
    required String targetUserId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('follow_requests')
          .where('requesterId', isEqualTo: requesterId)
          .where('targetUserId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('フォローリクエスト状態確認エラー: $e');
      }
      return false;
    }
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
      if (kDebugMode) {
        print('ユーザー検索エラー: $e');
      }
      return [];
    }
  }
}
