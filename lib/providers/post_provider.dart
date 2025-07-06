import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

class PostProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  Future<bool> createPost(PostModel post) async {
    try {
      _setLoading(true);
      _setError(null);

      // ドキュメントIDを生成してから投稿を保存
      final docRef = _firestore.collection('posts').doc();
      final postWithId = post.copyWith(id: docRef.id);

      await docRef.set(postWithId.toFirestore());

      // ローカルの投稿リストに追加
      _userPosts.insert(0, postWithId);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('投稿作成に失敗しました: ${e.toString()}');
      if (kDebugMode) {
        print('投稿作成エラー: $e');
      }
      return false;
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

      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: followingIds)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _followingPosts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .where(_shouldShowInFollowing)
          .toList();

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

      final querySnapshot = await _firestore
          .collection('posts')
          .where('communityIds', arrayContains: communityId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      return posts;
    } catch (e) {
      _setError('コミュニティ投稿取得に失敗しました');
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

      final querySnapshot = await _firestore
          .collection('posts')
          .where('communityIds', arrayContainsAny: communityIds)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _communityPosts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

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
      _setLoading(true);
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
    } finally {
      _setLoading(false);
    }
  }

  // いいね取り消し
  Future<bool> unlikePost(String postId, String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection('posts').doc(postId).update({
        'likedByUserIds': FieldValue.arrayRemove([userId]),
        'likeCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _setError('いいね取り消しに失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 投稿削除
  Future<bool> deletePost(String postId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection('posts').doc(postId).delete();

      // ローカルの投稿リストからも削除
      _userPosts.removeWhere((post) => post.id == postId);
      _posts.removeWhere((post) => post.id == postId);
      _followingPosts.removeWhere((post) => post.id == postId);
      _communityPosts.removeWhere((post) => post.id == postId);

      notifyListeners();

      return true;
    } catch (e) {
      _setError('投稿削除に失敗しました: ${e.toString()}');
      if (kDebugMode) {
        print('投稿削除エラー: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // フォロー中タブでの表示判定
  bool _shouldShowInFollowing(PostModel post) {
    final now = DateTime.now();

    // 完了している場合、24時間以内なら表示
    if (post.isCompleted) {
      return now.difference(post.updatedAt).inHours <= 24;
    }

    // 完了予定時刻から24時間経過したら非表示
    if (post.scheduledEndTime != null) {
      return now.difference(post.scheduledEndTime!).inHours <= 24;
    }

    return true;
  }

  // 投稿の分類取得
  Map<String, List<PostModel>> categorizeUserPosts(List<PostModel> posts) {
    final now = DateTime.now();
    final Map<String, List<PostModel>> categorized = {
      'concentration': [],
      'inProgress': [],
      'completed': [],
    };

    for (final post in posts) {
      switch (post.status) {
        case PostStatus.concentration:
          categorized['concentration']!.add(post);
          break;
        case PostStatus.inProgress:
          categorized['inProgress']!.add(post);
          break;
        case PostStatus.completed:
          categorized['completed']!.add(post);
          break;
        case PostStatus.overdue:
          // 期限切れは進行中に含める
          categorized['inProgress']!.add(post);
          break;
      }
    }

    return categorized;
  }
}
