import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_model.dart';
import '../services/notification_service.dart';
import '../providers/user_provider.dart';

class PostProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final NotificationService _notificationService = NotificationService();

  List<PostModel> _posts = [];
  List<PostModel> _followingPosts = [];
  List<PostModel> _communityPosts = [];
  List<PostModel> _userPosts = [];
  List<PostModel> _searchResults = []; // 検索結果を保存
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId; // 現在読み込み中のユーザーID

  // ユーザー投稿のキャッシュ
  Map<String, List<PostModel>> _userPostsCache = {};
  Map<String, DateTime> _userPostsCacheTime = {};
  static const Duration _cacheExpiry = Duration(minutes: 5); // 5分間キャッシュ

  List<PostModel> get posts => _posts;
  List<PostModel> get followingPosts => _followingPosts;
  List<PostModel> get communityPosts => _communityPosts;
  List<PostModel> get userPosts => _userPosts;
  List<PostModel> get searchResults => _searchResults; // 検索結果のgetter
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

  // 読み込み状態をリセット（タブ切り替え時の不要な読み込みを防ぐため）
  void resetLoadingState() {
    _isLoading = false;
    notifyListeners();
  }

  // 投稿作成
  Future<String?> createPost(PostModel post) async {
    try {
      _setLoading(true);
      _setError(null);

      // 1日10投稿制限をチェック（クライアント側でフィルタリング）
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // 既存のインデックスを使用（createdAt降順）
      final todayPostsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: post.userId)
          .orderBy('createdAt', descending: true)
          .get();

      final todayPosts = todayPostsSnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .where((post) =>
              post.createdAt.isAfter(startOfDay) &&
              post.createdAt.isBefore(endOfDay))
          .toList();

      if (todayPosts.length >= 10) {
        _setError('1日の投稿制限（10件）に達しました。明日また投稿してください。');
        return null;
      }

      final docRef =
          await _firestore.collection('posts').add(post.toFirestore());

      // ユーザーの投稿数を更新
      await _firestore.collection('users').doc(post.userId).update({
        'postCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 作成された投稿に通知をスケジュール
      final createdPost = post.copyWith(id: docRef.id);
      await _notificationService.schedulePostNotifications(createdPost);

      // コミュニティ投稿の場合は、コミュニティメンバーに通知を送信
      if (createdPost.communityIds.isNotEmpty) {
        for (final communityId in createdPost.communityIds) {
          // コミュニティ情報を取得
          final communityDoc =
              await _firestore.collection('communities').doc(communityId).get();
          if (communityDoc.exists) {
            final communityData = communityDoc.data() as Map<String, dynamic>;
            final communityName = communityData['name'] ?? 'コミュニティ';
            final memberIds =
                List<String>.from(communityData['memberIds'] ?? []);
            // 投稿者情報を取得
            final userDoc = await _firestore
                .collection('users')
                .doc(createdPost.userId)
                .get();
            final posterName = userDoc.exists
                ? (userDoc.data() as Map<String, dynamic>)['displayName'] ??
                    'ユーザー'
                : 'ユーザー';

            // コミュニティ通知を送信
            await _notificationService.sendCommunityPostNotification(
              communityId: communityId,
              communityName: communityName,
              postTitle: createdPost.title,
              posterName: posterName,
              memberIds: memberIds,
              postId: docRef.id, // 投稿のID
            );
          }
        }
      }

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
      _setError('投稿の作成に失敗しました: ${e.toString()}');
      if (kDebugMode) {
        print('投稿作成エラー: $e');
        print('投稿データ: ${post.toFirestore()}');
      }
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // END投稿作成（START投稿を更新）
  Future<bool> createEndPost(String startPostId, String endComment,
      String? endImageUrl, DateTime? actualEndTime) async {
    try {
      _setLoading(true);
      _setError(null);

      // 投稿に関連する通知をキャンセル（重複通知を防ぐため）
      await _notificationService.cancelPostNotifications(startPostId);

      // START投稿にEND投稿の情報を追加
      await _firestore.collection('posts').doc(startPostId).update({
        'endComment': endComment,
        'endImageUrl': endImageUrl,
        'actualEndTime': actualEndTime != null
            ? Timestamp.fromDate(actualEndTime)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ローカルの投稿リストも更新
      final endTime = actualEndTime ?? DateTime.now();
      final updatedPost =
          _userPosts.firstWhere((post) => post.id == startPostId).copyWith(
                endComment: endComment,
                endImageUrl: endImageUrl,
                actualEndTime: endTime,
                updatedAt: endTime,
              );

      // 各リストから既存の投稿を削除
      _userPosts.removeWhere((post) => post.id == startPostId);
      _followingPosts.removeWhere((post) => post.id == startPostId);
      _communityPosts.removeWhere((post) => post.id == startPostId);

      // 更新された投稿を各リストの先頭に追加（最新として扱う）
      _userPosts.insert(0, updatedPost);
      _followingPosts.insert(0, updatedPost);
      if (updatedPost.communityIds.isNotEmpty) {
        _communityPosts.insert(0, updatedPost);
      }

      notifyListeners();

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

  // ユーザー投稿キャッシュをクリア
  void _clearUserPostsCache(String userId) {
    _userPostsCache.remove(userId);
    _userPostsCacheTime.remove(userId);
  }

  // フォロー中の投稿取得
  Future<List<PostModel>> getFollowingPosts(List<String> followingIds,
      {String? currentUserId}) async {
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
          .where((post) => _shouldShowInFollowing(post, currentUserId))
          .toList();

      // プライベートアカウントの制限を適用
      final filteredPosts = <PostModel>[];
      for (final post in posts) {
        if (await _canViewPost(post, currentUserId)) {
          filteredPosts.add(post);
        }
      }

      // クライアント側でソート（END投稿を最新として扱う）
      filteredPosts.sort((a, b) {
        // END投稿がある場合は、actualEndTimeを使用
        final aTime = a.actualEndTime ?? a.createdAt;
        final bTime = b.actualEndTime ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      _followingPosts = filteredPosts;
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

      // クライアント側でソート（END投稿を最新として扱う）
      posts.sort((a, b) {
        // END投稿がある場合は、actualEndTimeを使用
        final aTime = a.actualEndTime ?? a.createdAt;
        final bTime = b.actualEndTime ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

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
  Future<List<PostModel>> getUserPosts(String userId,
      {String? currentUserId}) async {
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

      // キャッシュをチェック
      if (_userPostsCache.containsKey(userId)) {
        final cacheTime = _userPostsCacheTime[userId];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _cacheExpiry) {
          if (kDebugMode) {
            print('ユーザー投稿をキャッシュから取得: $userId');
          }
          _userPosts = _userPostsCache[userId]!;
          return _userPosts;
        }
      }

      if (kDebugMode) {
        print('ユーザー投稿取得開始: $userId');
      }

      // プライベートアカウントの場合、閲覧権限をチェック
      if (currentUserId != userId) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final isPrivate = userData['isPrivate'] ?? false;

          if (isPrivate) {
            final followerIds =
                List<String>.from(userData['followerIds'] ?? []);
            if (currentUserId == null || !followerIds.contains(currentUserId)) {
              // プライベートアカウントで、フォロワーでない場合は空のリストを返す
              _userPosts = [];
              return _userPosts;
            }
          }
        }
      }

      // 期限切れ投稿を自動更新
      await _checkAndUpdateExpiredPosts();

      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _userPosts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // END投稿を最新として扱うようにソート
      _userPosts.sort((a, b) {
        // END投稿がある場合は、actualEndTimeを使用
        final aTime = a.actualEndTime ?? a.createdAt;
        final bTime = b.actualEndTime ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      // キャッシュに保存
      _userPostsCache[userId] = _userPosts;
      _userPostsCacheTime[userId] = DateTime.now();

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

  // 投稿をIDで取得
  Future<PostModel?> getPostById(String postId) async {
    try {
      print('PostProvider.getPostById called with ID: $postId');
      _setLoading(true);
      _setError(null);

      final doc = await _firestore.collection('posts').doc(postId).get();
      print('Firestore query result - exists: ${doc.exists}');
      if (doc.exists) {
        final post = PostModel.fromFirestore(doc);
        print('Post loaded successfully: ${post.id}');
        return post;
      }
      print('Post not found in Firestore');
      return null;
    } catch (e) {
      print('Error loading post: $e');
      _setError('投稿取得に失敗しました');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 投稿検索
  Future<List<PostModel>> searchPosts(String query,
      {String? currentUserId}) async {
    try {
      _setLoading(true);
      _setError(null);

      if (query.isEmpty) {
        return [];
      }

      print('投稿検索開始: $query');

      // シンプルな検索：最新の投稿から検索
      final querySnapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(1000) // 500から1000に増加
          .get();

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      print('取得した投稿数: ${posts.length}');

      // 部分一致でフィルタリング
      final searchQuery = query.toLowerCase();
      print('検索クエリ: $searchQuery');

      final filteredPosts = posts.where((post) {
        // タイトル、コメント、ENDコメントで検索
        final titleMatch = post.title.toLowerCase().contains(searchQuery);
        final commentMatch =
            post.comment?.toLowerCase().contains(searchQuery) ?? false;
        final endCommentMatch =
            post.endComment?.toLowerCase().contains(searchQuery) ?? false;

        // デバッグログを追加
        if (titleMatch || commentMatch || endCommentMatch) {
          print(
              '検索マッチ: 投稿ID=${post.id}, タイトル=${post.title}, コメント=${post.comment}, ENDコメント=${post.endComment}');
        }

        return titleMatch || commentMatch || endCommentMatch;
      }).toList();

      print('フィルタリング後の投稿数: ${filteredPosts.length}');

      // 検索結果の詳細をログ出力
      for (final post in filteredPosts.take(10)) {
        print(
            '検索結果例: ID=${post.id}, タイトル=${post.title}, 作成日=${post.createdAt}, タイプ=${post.type}');
      }

      // デバッグ用：全投稿のタイトルをログ出力
      print('=== 全投稿のタイトル ===');
      for (final post in posts.take(10)) {
        print('投稿: ${post.title}');
      }
      print('=====================');

      _searchResults = filteredPosts; // 検索結果をキャッシュ
      return filteredPosts;
    } catch (e) {
      print('投稿検索エラー: $e');
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

      // 投稿情報を取得してユーザーIDを取得
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        _setError('投稿が見つかりません');
        return false;
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      final userId = postData['userId'] as String;

      // 投稿に関連する通知をキャンセル
      await _notificationService.cancelPostNotifications(postId);

      // 投稿を削除
      await _firestore.collection('posts').doc(postId).delete();

      // ユーザーの投稿数を減らす
      await _firestore.collection('users').doc(userId).update({
        'postCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
  bool _shouldShowInFollowing(PostModel post, String? currentUserId) {
    final now = DateTime.now();

    // 自分のコミュニティ投稿は表示しない
    if (currentUserId != null &&
        post.userId == currentUserId &&
        post.communityIds.isNotEmpty) {
      return false;
    }

    // 完了している場合のみ、END投稿（actualEndTime）から24時間以内なら表示
    if (post.isCompleted && post.actualEndTime != null) {
      return now.difference(post.actualEndTime!).inHours <= 24;
    }

    // 未完了投稿と予定なし投稿は常に表示
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

  // 24時間経過した投稿のステータスを自動更新
  Future<void> updateExpiredPosts() async {
    try {
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

      // インデックスエラーを回避するため、複数のクエリに分割
      // まず、START投稿で未完了のものを取得
      final querySnapshot = await _firestore
          .collection('posts')
          .where('type', isEqualTo: 'start')
          .where('actualEndTime', isNull: true)
          .get();

      final batch = _firestore.batch();
      final expiredPosts = <PostModel>[];

      for (final doc in querySnapshot.docs) {
        final post = PostModel.fromFirestore(doc);

        // クライアント側で24時間経過をチェック
        if (post.scheduledEndTime != null &&
            post.scheduledEndTime!.isBefore(twentyFourHoursAgo)) {
          // 24時間経過した投稿を完了状態に変更
          batch.update(doc.reference, {
            'actualEndTime': FieldValue.serverTimestamp(),
            'endComment': '24時間経過により自動完了',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // 投稿に関連する通知をキャンセル（重複通知を防ぐため）
          await _notificationService.cancelPostNotifications(post.id);

          // ローカルリスト更新用の投稿データを作成
          final updatedPost = post.copyWith(
            actualEndTime: now,
            endComment: '24時間経過により自動完了',
          );
          expiredPosts.add(updatedPost);
        }
      }

      // バッチ更新を実行
      if (expiredPosts.isNotEmpty) {
        await batch.commit();

        // ローカルの投稿リストを更新
        for (final updatedPost in expiredPosts) {
          updatePostInLists(updatedPost);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('期限切れ投稿の自動更新エラー: $e');
      }
    }
  }

  // 投稿リスト取得時に期限切れ投稿を自動更新
  Future<void> _checkAndUpdateExpiredPosts() async {
    await updateExpiredPosts();
  }

  // 投稿を閲覧可能かチェック（プライベートアカウント制限）
  Future<bool> _canViewPost(PostModel post, String? currentUserId) async {
    // 自分の投稿は常に表示
    if (currentUserId != null && post.userId == currentUserId) {
      return true;
    }

    try {
      // 投稿者のユーザー情報を取得
      final userDoc =
          await _firestore.collection('users').doc(post.userId).get();
      if (!userDoc.exists) {
        return false;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final isPrivate = userData['isPrivate'] ?? false;

      // 公開アカウントの場合は表示
      if (!isPrivate) {
        return true;
      }

      // プライベートアカウントの場合、フォロワーのみ表示
      if (currentUserId != null) {
        final followerIds = List<String>.from(userData['followerIds'] ?? []);
        return followerIds.contains(currentUserId);
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('投稿閲覧権限チェックエラー: $e');
      }
      return false;
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

  // START投稿を削除（END投稿作成後に呼び出し）
  Future<void> deleteStartPost(String startPostId) async {
    try {
      // START投稿のユーザーIDを取得（複数のリストから検索）
      PostModel? startPost;
      String? userId;

      // 各リストから投稿を検索
      try {
        startPost = _posts.firstWhere((post) => post.id == startPostId);
      } catch (e) {
        try {
          startPost = _userPosts.firstWhere((post) => post.id == startPostId);
        } catch (e) {
          try {
            startPost =
                _followingPosts.firstWhere((post) => post.id == startPostId);
          } catch (e) {
            try {
              startPost =
                  _communityPosts.firstWhere((post) => post.id == startPostId);
            } catch (e) {
              startPost = null;
            }
          }
        }
      }

      // 投稿が見つからない場合は、Firestoreから直接取得
      if (startPost == null) {
        final doc = await _firestore.collection('posts').doc(startPostId).get();
        if (!doc.exists) {
          if (kDebugMode) {
            print('START投稿が見つかりません: $startPostId');
          }
          return; // 投稿が存在しない場合は何もしない
        }
        userId = doc.data()?['userId'] as String?;
      } else {
        userId = startPost.userId;
      }

      // FirestoreでSTART投稿を削除
      await _firestore.collection('posts').doc(startPostId).delete();

      // ユーザーの投稿数を減らす（START投稿を削除したため）
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'postCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // ローカルの投稿リストから削除
      _posts.removeWhere((post) => post.id == startPostId);
      _userPosts.removeWhere((post) => post.id == startPostId);
      _followingPosts.removeWhere((post) => post.id == startPostId);
      _communityPosts.removeWhere((post) => post.id == startPostId);

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('START投稿削除エラー: $e');
      }
      // エラーが発生しても処理を継続
    }
  }
}
