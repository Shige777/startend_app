import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthProvider? _authProvider;

  UserModel? _currentUser;
  List<UserModel> _users = [];
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  List<UserModel> get users => _users;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    _initializeCurrentUser();
  }

  // 現在のユーザーを初期化
  Future<void> _initializeCurrentUser() async {
    final userId = _authProvider?.currentUserId;
    if (userId != null) {
      // 実際のFirestoreからユーザーを取得または作成
      await _getOrCreateUser(userId);
    }
  }

  // ユーザーを取得または作成
  Future<void> _getOrCreateUser(String userId) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        _setLoading(true);
        _setError(null);

        final userDoc = await _firestore.collection('users').doc(userId).get();

        if (userDoc.exists) {
          _currentUser = UserModel.fromFirestore(userDoc);
          notifyListeners();
          return;
        } else {
          // 新規ユーザー作成
          final newUser = UserModel(
            id: userId,
            displayName: 'ユーザー',
            email: '',
            bio: '',
            profileImageUrl: '',
            followerIds: [],
            followingIds: [],
            communityIds: [],
            postCount: 0,
            isPrivate: false,
            requiresApproval: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _firestore
              .collection('users')
              .doc(userId)
              .set(newUser.toFirestore());
          _currentUser = newUser;
          notifyListeners();
          return;
        }
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          // 最大試行回数に達した場合
          return;
        }
        // 少し待ってから再試行
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // ユーザー作成
  Future<bool> createUser(UserModel user) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection('users').doc(user.id).set(user.toFirestore());
      _currentUser = user;
      return true;
    } catch (e) {
      _setError('ユーザー作成に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ユーザー情報を取得
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final user = UserModel.fromFirestore(doc);

        // 投稿数を取得して更新（名前やプロフィール画像は更新しない）
        final postsSnapshot = await _firestore
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .get();

        final actualPostCount = postsSnapshot.docs.length;

        // 投稿数が異なる場合のみ更新
        if (user.postCount != actualPostCount) {
          await _firestore.collection('users').doc(userId).update({
            'postCount': actualPostCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // 更新されたユーザー情報を返す
          return user.copyWith(postCount: actualPostCount);
        }

        return user;
      }
      return null;
    } catch (e) {
      print('ユーザー情報取得エラー: $e');
      return null;
    }
  }

  // ユーザーをIDで取得（キャッシュ機能付き）
  Map<String, UserModel> _userCache = {};

  Future<UserModel?> getUserById(String userId) async {
    // キャッシュにある場合はそれを返す
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final user = UserModel.fromFirestore(doc);
        _userCache[userId] = user; // キャッシュに保存
        return user;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user by ID: $e');
      }
      return null;
    }
  }

  // ユーザー更新
  Future<bool> updateUser(UserModel user) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore
          .collection('users')
          .doc(user.id)
          .update(user.toFirestore());

      // 現在のユーザーを更新
      if (user.id == _currentUser?.id) {
        _currentUser = user;
      }

      // キャッシュを更新
      _userCache[user.id] = user;

      // UIを即座に更新
      notifyListeners();

      return true;
    } catch (e) {
      _setError('ユーザー更新に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 現在のユーザー情報を再読み込み
  Future<void> refreshCurrentUser() async {
    if (_currentUser?.id != null) {
      final updatedUser = await getUser(_currentUser!.id);
      if (updatedUser != null) {
        _currentUser = updatedUser;
        // キャッシュも更新
        _userCache[_currentUser!.id] = updatedUser;
        notifyListeners();
      }
    }
  }

  // 現在のユーザー情報をクリア
  void clearCurrentUser() {
    _currentUser = null;
    _userCache.clear();
    _searchResults.clear();
    notifyListeners();
  }

  // 特定のユーザーのキャッシュをクリア
  void clearUserCache(String userId) {
    _userCache.remove(userId);
    notifyListeners();
  }

  // フォロー操作の即座反映
  void updateFollowStatus({
    required String targetUserId,
    required bool isFollowing,
    required String currentUserId,
  }) {
    // 現在のユーザーのフォロー中リストを更新
    if (_currentUser?.id == currentUserId) {
      final updatedFollowingIds = List<String>.from(_currentUser!.followingIds);
      if (isFollowing) {
        if (!updatedFollowingIds.contains(targetUserId)) {
          updatedFollowingIds.add(targetUserId);
        }
      } else {
        updatedFollowingIds.remove(targetUserId);
      }

      _currentUser = _currentUser!.copyWith(followingIds: updatedFollowingIds);
    }

    // キャッシュされたターゲットユーザーのフォロワーリストを更新
    if (_userCache.containsKey(targetUserId)) {
      final targetUser = _userCache[targetUserId]!;
      final updatedFollowerIds = List<String>.from(targetUser.followerIds);
      if (isFollowing) {
        if (!updatedFollowerIds.contains(currentUserId)) {
          updatedFollowerIds.add(currentUserId);
        }
      } else {
        updatedFollowerIds.remove(currentUserId);
      }

      _userCache[targetUserId] =
          targetUser.copyWith(followerIds: updatedFollowerIds);
    }

    notifyListeners();
  }

  // フォロー関連の数値を即座に更新
  void updateFollowCounts({
    required String userId,
    int? followerCountDelta,
    int? followingCountDelta,
  }) {
    // 現在のユーザーを更新
    if (_currentUser?.id == userId) {
      if (followerCountDelta != null) {
        // フォロワー数の変更（実際のIDは後でFirestoreから同期）
        // ここでは数値のみを一時的に調整
      }

      if (followingCountDelta != null) {
        // フォロー中数の変更（実際のIDは後でFirestoreから同期）
        // ここでは数値のみを一時的に調整
      }
    }

    // キャッシュされたユーザーを更新
    if (_userCache.containsKey(userId)) {
      final user = _userCache[userId]!;
      List<String> updatedFollowerIds = List<String>.from(user.followerIds);
      List<String> updatedFollowingIds = List<String>.from(user.followingIds);

      _userCache[userId] = user.copyWith(
        followerIds: updatedFollowerIds,
        followingIds: updatedFollowingIds,
      );
    }

    notifyListeners();
  }

  // ユーザー検索
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      _setLoading(true);
      _setError(null);

      if (query.isEmpty) {
        _searchResults = [];
        return _searchResults;
      }

      print('ユーザー検索開始: $query');

      // シンプルな検索：全ユーザーを取得
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(200) // 100から200に増加
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      print('取得したユーザー数: ${users.length}');

      // 部分一致でフィルタリング
      final searchQuery = query.toLowerCase();
      _searchResults = users.where((user) {
        final nameMatch = user.displayName.toLowerCase().contains(searchQuery);
        final emailMatch = user.email.toLowerCase().contains(searchQuery);

        // デバッグログを追加
        if (nameMatch || emailMatch) {
          print(
              'ユーザー検索マッチ: ID=${user.id}, 名前=${user.displayName}, メール=${user.email}');
        }

        return nameMatch || emailMatch;
      }).toList();

      print('フィルタリング後のユーザー数: ${_searchResults.length}');

      // 検索結果の詳細をログ出力
      for (final user in _searchResults.take(10)) {
        print(
            'ユーザー検索結果例: ID=${user.id}, 名前=${user.displayName}, メール=${user.email}');
      }

      return _searchResults;
    } catch (e) {
      print('ユーザー検索エラー: $e');
      _setError('ユーザー検索に失敗しました');
      _searchResults = [];
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // フォロー
  Future<bool> followUser(String userId) async {
    if (_currentUser == null) return false;

    // 自分自身をフォローしようとした場合はエラー
    if (_currentUser!.id == userId) {
      _setError('自分自身をフォローすることはできません');
      return false;
    }

    try {
      _setError(null);

      final batch = _firestore.batch();

      // フォローする側のfollowingIdsに追加
      batch.update(_firestore.collection('users').doc(_currentUser!.id), {
        'followingIds': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // フォローされる側のfollowerIdsに追加
      batch.update(_firestore.collection('users').doc(userId), {
        'followerIds': FieldValue.arrayUnion([_currentUser!.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // ローカルの状態を更新
      _currentUser = _currentUser!.copyWith(
        followingIds: [..._currentUser!.followingIds, userId],
        updatedAt: DateTime.now(),
      );

      // キャッシュからフォローしたユーザーを削除（最新データを取得するため）
      _userCache.remove(userId);

      return true;
    } catch (e) {
      _setError('フォローに失敗しました');
      return false;
    }
  }

  // アンフォロー
  Future<bool> unfollowUser(String userId) async {
    if (_currentUser == null) return false;

    // 自分自身をアンフォローしようとした場合はエラー
    if (_currentUser!.id == userId) {
      _setError('自分自身をアンフォローすることはできません');
      return false;
    }

    try {
      _setError(null);

      final batch = _firestore.batch();

      // フォローする側のfollowingIdsから削除
      batch.update(_firestore.collection('users').doc(_currentUser!.id), {
        'followingIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // フォローされる側のfollowerIdsから削除
      batch.update(_firestore.collection('users').doc(userId), {
        'followerIds': FieldValue.arrayRemove([_currentUser!.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // ローカルの状態を更新
      final updatedFollowingIds = _currentUser!.followingIds.toList();
      updatedFollowingIds.remove(userId);
      _currentUser = _currentUser!.copyWith(
        followingIds: updatedFollowingIds,
        updatedAt: DateTime.now(),
      );

      // キャッシュからアンフォローしたユーザーを削除（最新データを取得するため）
      _userCache.remove(userId);

      return true;
    } catch (e) {
      _setError('アンフォローに失敗しました');
      return false;
    }
  }

  // フォロワー取得
  Future<List<UserModel>> getFollowers(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final user = await getUser(userId);
      if (user == null) return [];

      if (user.followerIds.isEmpty) return [];

      // Firestoreのwhereインデックスエラーを回避するため、個別に取得
      final List<UserModel> followerUsers = [];

      // 10個ずつバッチで処理（Firestoreの制限）
      for (int i = 0; i < user.followerIds.length; i += 10) {
        final batch = user.followerIds.skip(i).take(10).toList();

        final querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final batchUsers = querySnapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();

        followerUsers.addAll(batchUsers);
      }

      return followerUsers;
    } catch (e) {
      _setError('フォロワー取得に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // フォロー中取得
  Future<List<UserModel>> getFollowing(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final user = await getUser(userId);
      if (user == null) return [];

      if (user.followingIds.isEmpty) return [];

      // Firestoreのwhereインデックスエラーを回避するため、個別に取得
      final List<UserModel> followingUsers = [];

      // 10個ずつバッチで処理（Firestoreの制限）
      for (int i = 0; i < user.followingIds.length; i += 10) {
        final batch = user.followingIds.skip(i).take(10).toList();

        final querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final batchUsers = querySnapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();

        followingUsers.addAll(batchUsers);
      }

      return followingUsers;
    } catch (e) {
      _setError('フォロー中取得に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // 現在のユーザーを設定
  void setCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }
}
