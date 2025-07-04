import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  List<UserModel> get users => _users;
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
      _setLoading(false);
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

  // ユーザー検索
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      _setLoading(true);
      _setError(null);

      final querySnapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: query + '\uf8ff')
          .limit(20)
          .get();

      _users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      return _users;
    } catch (e) {
      _setError('ユーザー検索に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // フォロー
  Future<bool> followUser(String userId) async {
    if (_currentUser == null) return false;

    try {
      _setLoading(true);
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

      return true;
    } catch (e) {
      _setError('フォローに失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // アンフォロー
  Future<bool> unfollowUser(String userId) async {
    if (_currentUser == null) return false;

    try {
      _setLoading(true);
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

      return true;
    } catch (e) {
      _setError('アンフォローに失敗しました');
      return false;
    } finally {
      _setLoading(false);
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

      final querySnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: user.followerIds)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
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

      final querySnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: user.followingIds)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
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

  // 現在のユーザーをクリア
  void clearCurrentUser() {
    _currentUser = null;
    notifyListeners();
  }
}
