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
  Future<bool> createCommunity(CommunityModel community) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection('communities').add(community.toFirestore());
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

  // コミュニティ脱退
  Future<bool> leaveCommunity(String communityId, String userId) async {
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
      return true;
    } catch (e) {
      _setError('コミュニティ脱退に失敗しました');
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
