import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_model.dart';
import '../services/notification_service.dart';

class PostProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final NotificationService _notificationService = NotificationService();

  List<PostModel> _posts = [];
  List<PostModel> _followingPosts = [];
  List<PostModel> _communityPosts = [];
  List<PostModel> _userPosts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId; // 現在読み込み中のユーザーID

  List<PostModel> get posts => _posts;
  List<PostModel> get followingPosts => _followingPosts;
  List<PostModel> get communityPosts => _communityPosts;
  List<PostModel> get userPosts => _userPosts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // 投稿作成
  Future<String?> createPost(PostModel post) async {
    try {
      _setLoading(true);
      _setError(null);

      final docRef =
          await _firestore.collection('posts').add(post.toFirestore());

      // 作成された投稿に通知をスケジュール
      final createdPost = post.copyWith(id: docRef.id);
      await _notificationService.schedulePostNotifications(createdPost);

      // ローカルの投稿リストに追加
      _userPosts.insert(0, createdPost);

      // コミュニティ投稿の場合は、コミュニティ投稿リストにも追加
      if (createdPost.communityIds.isNotEmpty) {
        _communityPosts.insert(0, createdPost);
        if (kDebugMode) {
          print('コミュニティ投稿リストに追加: ${createdPost.title}');
        }
      }

      notifyListeners();

      return docRef.id;
    } catch (e) {
      _setError('投稿の作成に失敗しました');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // END投稿作成（START投稿を更新）
  Future<bool> createEndPost(
      String startPostId, String endComment, String? endImageUrl) async {
    try {
      _setLoading(true);
      _setError(null);

      // START投稿にEND投稿の情報を追加
      await _firestore.collection('posts').doc(startPostId).update({
        'endComment': endComment,
        'endImageUrl': endImageUrl,
        'actualEndTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ローカルの投稿リストも更新
      final index = _userPosts.indexWhere((post) => post.id == startPostId);
      if (index != -1) {
        _userPosts[index] = _userPosts[index].copyWith(
          endComment: endComment,
          endImageUrl: endImageUrl,
          actualEndTime: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('END投稿作成に失敗しました: ${e.toString()}');
      if (kDebugMode) {
        print('END投稿作成エラー: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 投稿更新
  Future<bool> updatePost(PostModel post) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore
          .collection('posts')
          .doc(post.id)
          .update(post.toFirestore());

      // ローカルの投稿リストも更新
      updatePostInLists(post);

      return true;
    } catch (e) {
      _setError('投稿更新に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // フォロー中の投稿取得
  Future<List<PostModel>> getFollowingPosts(List<String> followingIds) async {
    try {
      _setLoading(true);
      _setError(null);

      if (followingIds.isEmpty) {
        _followingPosts = [];
        return _followingPosts;
      }

      // インデックスエラーを回避するため、orderByを削除してクライアント側でソート
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: followingIds)
          .limit(50)
          .get();

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .where(_shouldShowInFollowing)
          .toList();

      // クライアント側でソート
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _followingPosts = posts;
      return _followingPosts;
    } catch (e) {
      _setError('フォロー中の投稿取得に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティ投稿取得（単一コミュニティ）
  Future<List<PostModel>> getCommunityPosts(String communityId) async {
    try {
      _setLoading(true);
      _setError(null);

      if (kDebugMode) {
        print('コミュニティ投稿取得開始: $communityId');
      }

      // インデックスが作成されるまでの一時的な回避策：orderByを削除
      QuerySnapshot querySnapshot;
      try {
        // まずorderByありで試行（チャット形式のため昇順）
        if (kDebugMode) {
          print('orderByありでクエリ試行中...');
        }
        querySnapshot = await _firestore
            .collection('posts')
            .where('communityIds', arrayContains: communityId)
            .orderBy('createdAt', descending: false)
            .limit(50)
            .get();

        if (kDebugMode) {
          print('orderByありでクエリ成功');
        }
      } catch (indexError) {
        if (kDebugMode) {
          print('インデックス不足のため、orderByなしで再試行: $indexError');
        }
        // インデックスエラーの場合、orderByなしで取得してクライアント側でソート
        querySnapshot = await _firestore
            .collection('posts')
            .where('communityIds', arrayContains: communityId)
            .limit(50)
            .get();

        if (kDebugMode) {
          print('orderByなしでクエリ完了');
        }
      }

      if (kDebugMode) {
        print('Firestore取得完了: ${querySnapshot.docs.length}件のドキュメント');
        for (final doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          print(
              '- ドキュメント ${doc.id}: ${data['title']} (userId: ${data['userId']}, communityIds: ${data['communityIds']})');
        }
      }

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // クライアント側でソート（チャット形式のため昇順）
      posts.sort((a, b) {
        // END投稿がある場合は、actualEndTimeを使用
        final aTime = a.actualEndTime ?? a.createdAt;
        final bTime = b.actualEndTime ?? b.createdAt;
        return aTime.compareTo(bTime);
      });

      if (kDebugMode) {
        print('コミュニティ投稿取得完了: ${posts.length}件');
        for (final post in posts) {
          print(
              '- ${post.title} (communityIds: ${post.communityIds}, userId: ${post.userId})');
        }
      }

      // コミュニティ投稿リストを更新
      _communityPosts = posts;

      return posts;
    } catch (e) {
      _setError('コミュニティ投稿取得に失敗しました');
      if (kDebugMode) {
        print('コミュニティ投稿取得エラー: $e');
      }
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティ投稿取得（複数コミュニティ）
  Future<List<PostModel>> getMultipleCommunityPosts(
      List<String> communityIds) async {
    try {
      _setLoading(true);
      _setError(null);

      if (communityIds.isEmpty) {
        _communityPosts = [];
        return _communityPosts;
      }

      // インデックスエラーを回避するため、orderByを削除してクライアント側でソート
      final querySnapshot = await _firestore
          .collection('posts')
          .where('communityIds', arrayContainsAny: communityIds)
          .limit(50)
          .get();

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // クライアント側でソート
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _communityPosts = posts;
      return _communityPosts;
    } catch (e) {
      _setError('コミュニティ投稿取得に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ユーザーの投稿取得（コミュニティ投稿も含む）
  Future<List<PostModel>> getUserPosts(String userId) async {
    // 同じユーザーIDで既に読み込み中の場合は重複実行を防ぐ
    if (_currentUserId == userId && _isLoading) {
      if (kDebugMode) {
        print('ユーザー投稿取得スキップ（既に読み込み中）: $userId');
      }
      return _userPosts;
    }

    try {
      _setLoading(true);
      _setError(null);
      _currentUserId = userId;

      if (kDebugMode) {
        print('ユーザー投稿取得開始: $userId');
      }

      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _userPosts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      if (kDebugMode) {
        print('ユーザー投稿取得完了: ${_userPosts.length}件');
        for (final post in _userPosts) {
          print('- ${post.title} (${post.status})');
        }
      }

      return _userPosts;
    } catch (e) {
      _setError('ユーザー投稿取得に失敗しました: ${e.toString()}');
      if (kDebugMode) {
        print('ユーザー投稿取得エラー: $e');
      }
      return [];
    } finally {
      _setLoading(false);
      _currentUserId = null;
    }
  }

  // 投稿検索
  Future<List<PostModel>> searchPosts(String query) async {
    try {
      _setLoading(true);
      _setError(null);

      final querySnapshot = await _firestore
          .collection('posts')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + '\uf8ff')
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      _setError('投稿検索に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // いいね
  Future<bool> likePost(String postId, String userId) async {
    try {
      // いいね機能ではローディング状態を設定しない（他の機能に影響しないため）
      _setError(null);

      await _firestore.collection('posts').doc(postId).update({
        'likedByUserIds': FieldValue.arrayUnion([userId]),
        'likeCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _setError('いいねに失敗しました');
      return false;
    }
  }

  // いいね取り消し
  Future<bool> unlikePost(String postId, String userId) async {
    try {
      // いいね機能ではローディング状態を設定しない（他の機能に影響しないため）
      _setError(null);

      // トランザクションを使用してlikeCountがマイナスにならないように制御
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection('posts').doc(postId);
        final postSnapshot = await transaction.get(postRef);

        if (!postSnapshot.exists) {
          throw Exception('投稿が見つかりません');
        }

        final currentLikeCount = postSnapshot.data()?['likeCount'] ?? 0;
        final newLikeCount = currentLikeCount > 0 ? currentLikeCount - 1 : 0;

        transaction.update(postRef, {
          'likedByUserIds': FieldValue.arrayRemove([userId]),
          'likeCount': newLikeCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      _setError('いいね取り消しに失敗しました');
      return false;
    }
  }

  // 投稿削除
  Future<bool> deletePost(String postId) async {
    try {
      _setLoading(true);
      _setError(null);

      // 投稿に関連する通知をキャンセル
      await _notificationService.cancelPostNotifications(postId);

      await _firestore.collection('posts').doc(postId).delete();

      // ローカルの投稿リストからも削除
      _userPosts.removeWhere((post) => post.id == postId);
      _followingPosts.removeWhere((post) => post.id == postId);
      _communityPosts.removeWhere((post) => post.id == postId);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('投稿削除に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // フォロー中タブでの表示判定
  bool _shouldShowInFollowing(PostModel post) {
    final now = DateTime.now();

    // 完了している場合、END投稿（actualEndTime）から24時間以内なら表示
    if (post.isCompleted && post.actualEndTime != null) {
      return now.difference(post.actualEndTime!).inHours <= 24;
    }

    // 完了予定時刻から24時間経過したら非表示
    if (post.scheduledEndTime != null) {
      return now.difference(post.scheduledEndTime!).inHours <= 24;
    }

    return true;
  }

  // 投稿の分類取得
  PostStatus getPostCategory(PostModel post) {
    final now = DateTime.now();

    if (post.isCompleted) {
      return PostStatus.completed;
    } else if (post.scheduledEndTime != null &&
        now.isAfter(post.scheduledEndTime!)) {
      return PostStatus.overdue;
    } else if (post.type == PostType.start) {
      return PostStatus.inProgress;
    } else {
      return PostStatus.concentration;
    }
  }

  // ローカルの投稿リストを更新
  void updatePostInLists(PostModel updatedPost) {
    // 各リストで該当する投稿を更新
    _updatePostInList(_posts, updatedPost);
    _updatePostInList(_userPosts, updatedPost);
    _updatePostInList(_followingPosts, updatedPost);
    _updatePostInList(_communityPosts, updatedPost);

    notifyListeners();
  }

  // リスト内の投稿を更新するヘルパーメソッド
  void _updatePostInList(List<PostModel> list, PostModel updatedPost) {
    final index = list.indexWhere((post) => post.id == updatedPost.id);
    if (index != -1) {
      list[index] = updatedPost;
    }
  }
}
