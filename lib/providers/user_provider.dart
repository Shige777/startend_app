import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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

        if (kDebugMode) {
          print('ユーザー取得/作成開始 (試行 ${retryCount + 1}/$maxRetries): $userId');
        }

        final doc =
            await _firestore.collection('users').doc(userId).get().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
                'Firestore get timeout', const Duration(seconds: 10));
          },
        );

        if (doc.exists) {
          _currentUser = UserModel.fromFirestore(doc);
          if (kDebugMode) {
            print('既存ユーザー取得成功: ${_currentUser?.displayName}');
          }
        } else {
          // ユーザーが存在しない場合は新規作成
          final authUser = _authProvider?.user;
          if (authUser != null) {
            _currentUser = UserModel(
              id: userId,
              displayName: authUser.displayName ?? 'ユーザー',
              email: authUser.email ?? '',
              profileImageUrl: authUser.photoURL,
              bio: '',
              isPrivate: false,
              requiresApproval: false,
              followerIds: [],
              followingIds: [],
              communityIds: [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Firestoreに保存（タイムアウト付き）
            await _firestore
                .collection('users')
                .doc(userId)
                .set(_currentUser!.toFirestore())
                .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                    'Firestore set timeout', const Duration(seconds: 15));
              },
            );

            if (kDebugMode) {
              print('新規ユーザー作成成功: ${_currentUser?.displayName}');
            }

            // 作成後の短い待機時間
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        // 成功した場合はリターン
        return;
      } on TimeoutException catch (e) {
        retryCount++;
        if (kDebugMode) {
          print(
              'UserProvider Firestore操作タイムアウト (試行 $retryCount/$maxRetries): $e');
        }

        if (retryCount >= maxRetries) {
          _setError('ネットワーク接続が不安定です。しばらく待ってからもう一度お試しください。');
          return;
        }

        await Future.delayed(Duration(milliseconds: 1000 * retryCount));
      } catch (e) {
        retryCount++;
        if (kDebugMode) {
          print('UserProvider エラー (試行 $retryCount/$maxRetries): $e');
        }

        if (retryCount >= maxRetries) {
          _setError('ユーザー情報の取得に失敗しました: ${e.toString()}');
          return;
        }

        // ネットワーク関連のエラーの場合は長めに待機
        if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          await Future.delayed(Duration(milliseconds: 2000 * retryCount));
        } else {
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        }
      } finally {
        if (retryCount >= maxRetries || _currentUser != null) {
          _setLoading(false);
        }
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

  // ユーザー取得
  Future<UserModel?> getUser(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final user = UserModel.fromFirestore(doc);
        if (userId == _currentUser?.id) {
          _currentUser = user;
        }
        return user;
      }
      return null;
    } catch (e) {
      _setError('ユーザー取得に失敗しました');
      return null;
    } finally {
      // ビルド中にsetStateが呼ばれないようにSchedulerBindingを使用
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _setLoading(false);
      });
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
      if (user.id == _currentUser?.id) {
        _currentUser = user;
      }
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
      await getUser(_currentUser!.id);
    }
  }

  // 現在のユーザー情報をクリア
  void clearCurrentUser() {
    _currentUser = null;
    _userCache.clear();
    _searchResults.clear();
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
      List<String> updatedFollowerIds =
          List<String>.from(_currentUser!.followerIds);
      List<String> updatedFollowingIds =
          List<String>.from(_currentUser!.followingIds);

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

      // 部分一致検索のため、全ユーザーを取得してフィルタリング
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(100) // パフォーマンスのため上限を設定
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // 部分一致でフィルタリング
      final searchQuery = query.toLowerCase();
      _searchResults = users.where((user) {
        return user.displayName.toLowerCase().contains(searchQuery) ||
            (user.email.toLowerCase().contains(searchQuery));
      }).toList();

      return _searchResults.take(20).toList(); // 結果を20件に制限
    } catch (e) {
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
