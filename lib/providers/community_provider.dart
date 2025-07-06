import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_model.dart';

class CommunityProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CommunityModel> _communities = [];
  List<CommunityModel> _userCommunities = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CommunityModel> get communities => _communities;
  List<CommunityModel> get userCommunities => _userCommunities;
  List<CommunityModel> get joinedCommunities => _userCommunities;
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

  // コミュニティ作成
  Future<bool> createCommunity({
    required String name,
    required String description,
    required String userId,
    bool requiresApproval = false,
    String? imageUrl,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final community = CommunityModel(
        id: '',
        name: name,
        description: description,
        leaderId: userId,
        memberIds: [userId], // 作成者は自動でメンバーになる
        pendingMemberIds: [],
        genre: 'その他',
        maxMembers: 8,
        isPrivate: requiresApproval, // 承認制の場合はプライベートに設定
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('communities')
          .add(community.toFirestore());

      // ユーザーのコミュニティリストにも追加
      await _firestore.collection('users').doc(userId).update({
        'communityIds': FieldValue.arrayUnion([docRef.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // コミュニティ一覧を更新
      await searchCommunities();

      // ユーザーのコミュニティ一覧も更新
      await getUserCommunities(userId);

      return true;
    } catch (e) {
      _setError('コミュニティ作成に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティ更新
  Future<bool> updateCommunity(CommunityModel community) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore
          .collection('communities')
          .doc(community.id)
          .update(community.toFirestore());
      return true;
    } catch (e) {
      _setError('コミュニティ更新に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティ検索
  Future<List<CommunityModel>> searchCommunities({
    String? query,
    String? genre,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      Query queryRef = _firestore.collection('communities');

      if (genre != null && genre.isNotEmpty) {
        queryRef = queryRef.where('genre', isEqualTo: genre);
      }

      if (query != null && query.isNotEmpty) {
        queryRef = queryRef
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThan: query + '\uf8ff');
      }

      final querySnapshot = await queryRef.limit(20).get();

      _communities = querySnapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .toList();

      return _communities;
    } catch (e) {
      _setError('コミュニティ検索に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ユーザーのコミュニティ取得
  Future<List<CommunityModel>> getUserCommunities(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final querySnapshot = await _firestore
          .collection('communities')
          .where('memberIds', arrayContains: userId)
          .get();

      _userCommunities = querySnapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .toList();

      return _userCommunities;
    } catch (e) {
      _setError('ユーザーコミュニティ取得に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティ参加申請
  Future<bool> requestJoinCommunity(String communityId, String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection('communities').doc(communityId).update({
        'pendingMemberIds': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _setError('参加申請に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 参加申請承認
  Future<bool> approveMember(String communityId, String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final batch = _firestore.batch();

      // コミュニティのメンバーリストに追加、保留リストから削除
      batch.update(_firestore.collection('communities').doc(communityId), {
        'memberIds': FieldValue.arrayUnion([userId]),
        'pendingMemberIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ユーザーのコミュニティリストに追加
      batch.update(_firestore.collection('users').doc(userId), {
        'communityIds': FieldValue.arrayUnion([communityId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      _setError('メンバー承認に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 参加申請拒否
  Future<bool> rejectMember(String communityId, String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection('communities').doc(communityId).update({
        'pendingMemberIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _setError('メンバー拒否に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティ参加
  Future<bool> joinCommunity(String communityId, {String? userId}) async {
    try {
      _setLoading(true);
      _setError(null);

      // userIdが指定されていない場合は現在のユーザーIDを使用
      final targetUserId = userId ?? 'test_user_001'; // TODO: 実際のユーザーIDを取得

      final batch = _firestore.batch();

      // コミュニティのメンバーリストに追加
      batch.update(_firestore.collection('communities').doc(communityId), {
        'memberIds': FieldValue.arrayUnion([targetUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ユーザーのコミュニティリストに追加
      batch.update(_firestore.collection('users').doc(targetUserId), {
        'communityIds': FieldValue.arrayUnion([communityId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      _setError('コミュニティ参加に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティ脱退
  Future<bool> leaveCommunity(String communityId, {String? userId}) async {
    try {
      _setLoading(true);
      _setError(null);

      // userIdが指定されていない場合はエラー
      if (userId == null) {
        _setError('ユーザーIDが指定されていません');
        return false;
      }

      final batch = _firestore.batch();

      // コミュニティのメンバーリストから削除
      batch.update(_firestore.collection('communities').doc(communityId), {
        'memberIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ユーザーのコミュニティリストから削除
      batch.update(_firestore.collection('users').doc(userId), {
        'communityIds': FieldValue.arrayRemove([communityId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // ユーザーコミュニティリストを更新
      await getUserCommunities(userId);

      return true;
    } catch (e) {
      _setError('コミュニティ脱退に失敗しました: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // メンバーを脱退させる（リーダー権限）
  Future<bool> removeMember(String communityId, String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final batch = _firestore.batch();

      // コミュニティのメンバーリストから削除
      batch.update(_firestore.collection('communities').doc(communityId), {
        'memberIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ユーザーのコミュニティリストから削除
      batch.update(_firestore.collection('users').doc(userId), {
        'communityIds': FieldValue.arrayRemove([communityId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // ユーザーコミュニティリストを更新
      await getUserCommunities(userId);

      return true;
    } catch (e) {
      _setError('メンバー削除に失敗しました: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティ設定更新（リーダー権限）
  Future<bool> updateCommunitySettings({
    required String communityId,
    required bool isPrivate,
    required int maxMembers,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection('communities').doc(communityId).update({
        'isPrivate': isPrivate,
        'maxMembers': maxMembers,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _setError('コミュニティ設定更新に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // リーダー移譲
  Future<bool> transferLeadership(
    String communityId,
    String newLeaderId,
  ) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection('communities').doc(communityId).update({
        'leaderId': newLeaderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _setError('リーダー移譲に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティ取得
  Future<CommunityModel?> getCommunity(String communityId) async {
    try {
      _setLoading(true);
      _setError(null);

      final doc =
          await _firestore.collection('communities').doc(communityId).get();
      if (doc.exists) {
        return CommunityModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _setError('コミュニティ取得に失敗しました');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ジャンル別コミュニティ取得
  Future<List<CommunityModel>> getCommunitiesByGenre(String genre) async {
    try {
      _setLoading(true);
      _setError(null);

      final querySnapshot = await _firestore
          .collection('communities')
          .where('genre', isEqualTo: genre)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      _setError('ジャンル別コミュニティ取得に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }
}
