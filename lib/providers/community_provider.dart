import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_model.dart';

class CommunityProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CommunityModel> _communities = [];
  List<CommunityModel> _userCommunities = [];
  List<CommunityModel> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CommunityModel> get communities => _communities;
  List<CommunityModel> get userCommunities => _userCommunities;
  List<CommunityModel> get joinedCommunities => _userCommunities;
  List<CommunityModel> get searchResults => _searchResults;
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

  String? _lastCreatedCommunityId;

  // 最後に作成したコミュニティIDを取得
  String? get lastCreatedCommunityId => _lastCreatedCommunityId;

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

      // 1日5コミュニティ制限をチェック（クライアント側でフィルタリング）
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todayCommunitiesSnapshot = await _firestore
          .collection('communities')
          .where('leaderId', isEqualTo: userId)
          .get();

      final todayCommunities = todayCommunitiesSnapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .where((community) => 
              community.createdAt.isAfter(startOfDay) && 
              community.createdAt.isBefore(endOfDay))
          .toList();

      if (todayCommunities.length >= 5) {
        _setError('1日のコミュニティ作成制限（5個）に達しました。明日また作成してください。');
        return false;
      }

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

      // 作成したコミュニティIDを保存
      _lastCreatedCommunityId = docRef.id;

      // ユーザーのコミュニティリストにも追加
      await _firestore.collection('users').doc(userId).update({
        'communityIds': FieldValue.arrayUnion([docRef.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 作成したコミュニティの完全な情報を取得
      final createdCommunity =
          await _firestore.collection('communities').doc(docRef.id).get();

      if (createdCommunity.exists) {
        final community = CommunityModel.fromFirestore(createdCommunity);
        _communities.add(community);
        _userCommunities.add(community);
      }

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

      // 検索クエリが空の場合は検索結果をクリア
      if (query == null || query.isEmpty) {
        _searchResults = [];
        return _searchResults;
      }

      // 部分一致検索のため、全コミュニティを取得してフィルタリング
      Query queryRef = _firestore.collection('communities');

      if (genre != null && genre.isNotEmpty) {
        queryRef = queryRef.where('genre', isEqualTo: genre);
      }

      final querySnapshot = await queryRef
          .orderBy('createdAt', descending: true)
          .limit(100) // パフォーマンスのため上限を設定
          .get();

      final communities = querySnapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .toList();

      // 部分一致でフィルタリング
      final searchQuery = query.toLowerCase();
      _searchResults = communities.where((community) {
        return community.name.toLowerCase().contains(searchQuery) ||
            community.description.toLowerCase().contains(searchQuery);
      }).toList();

      return _searchResults.take(20).toList(); // 結果を20件に制限
    } catch (e) {
      _setError('コミュニティ検索に失敗しました');
      _searchResults = [];
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

      // メンバー数制限をチェック
      final community = await getCommunity(communityId);
      if (community == null) {
        _setError('コミュニティが見つかりません');
        return false;
      }

      if (community.memberIds.length >= 8) {
        _setError('コミュニティのメンバー数が上限に達しています');
        return false;
      }

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

      // コミュニティ情報を取得してメンバー数をチェック
      final community = await getCommunity(communityId);
      if (community == null) {
        _setError('コミュニティが見つかりません');
        return false;
      }

      // メンバー数が上限（8人）に達している場合は参加を拒否
      if (community.memberIds.length >= 8) {
        _setError('コミュニティのメンバー数が上限に達しています（8人）');
        return false;
      }

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

      // コミュニティ情報を取得
      final community = await getCommunity(communityId);
      if (community == null) {
        _setError('コミュニティが見つかりません');
        return false;
      }

      // 脱退後のメンバー数を計算
      final remainingMembers =
          community.memberIds.where((id) => id != userId).toList();

      if (remainingMembers.isEmpty) {
        // メンバーが0人になる場合、コミュニティを削除
        await _deleteCommunity(communityId);
      } else {
        // リーダーが脱退する場合、新しいリーダーを選出
        if (community.leaderId == userId) {
          final newLeaderId = remainingMembers.first;
          await _transferLeadershipAndRemoveMember(
              communityId, userId, newLeaderId);
        } else {
          // 通常のメンバーの脱退
          await _removeMemberFromCommunity(communityId, userId);
        }
      }

      // ローカルのユーザーコミュニティリストを更新
      await getUserCommunities(userId);

      return true;
    } catch (e) {
      _setError('コミュニティ脱退に失敗しました: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // コミュニティを削除
  Future<void> _deleteCommunity(String communityId) async {
    final batch = _firestore.batch();

    // コミュニティドキュメントを削除
    batch.delete(_firestore.collection('communities').doc(communityId));

    // 関連する投稿のcommunityIdsからこのコミュニティIDを削除
    final postsSnapshot = await _firestore
        .collection('posts')
        .where('communityIds', arrayContains: communityId)
        .get();

    for (final postDoc in postsSnapshot.docs) {
      batch.update(postDoc.reference, {
        'communityIds': FieldValue.arrayRemove([communityId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // ローカルのコミュニティリストからも削除
    _communities.removeWhere((community) => community.id == communityId);
    _userCommunities.removeWhere((community) => community.id == communityId);
    notifyListeners();
  }

  // リーダー移譲と同時にメンバーを削除
  Future<void> _transferLeadershipAndRemoveMember(
    String communityId,
    String leavingUserId,
    String newLeaderId,
  ) async {
    final batch = _firestore.batch();

    // リーダーを変更し、脱退するメンバーを削除
    batch.update(_firestore.collection('communities').doc(communityId), {
      'leaderId': newLeaderId,
      'memberIds': FieldValue.arrayRemove([leavingUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 脱退するユーザーのコミュニティリストから削除
    batch.update(_firestore.collection('users').doc(leavingUserId), {
      'communityIds': FieldValue.arrayRemove([communityId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // メンバーをコミュニティから削除
  Future<void> _removeMemberFromCommunity(
      String communityId, String userId) async {
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

  // コミュニティ情報更新（リーダー権限）
  Future<bool> updateCommunityInfo({
    required String communityId,
    String? name,
    String? description,
    String? genre,
    String? imageUrl,
    bool? isPrivate,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (genre != null) updateData['genre'] = genre;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (isPrivate != null) updateData['isPrivate'] = isPrivate;

      await _firestore
          .collection('communities')
          .doc(communityId)
          .update(updateData);

      // ローカルのコミュニティリストを更新
      final updatedCommunity = await getCommunity(communityId);
      if (updatedCommunity != null) {
        final index = _communities.indexWhere((c) => c.id == communityId);
        if (index != -1) {
          _communities[index] = updatedCommunity;
        }

        final userIndex =
            _userCommunities.indexWhere((c) => c.id == communityId);
        if (userIndex != -1) {
          _userCommunities[userIndex] = updatedCommunity;
        }

        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('コミュニティ情報更新に失敗しました');
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

      // インデックスエラーを回避するため、orderByを削除してクライアント側でソート
      final querySnapshot = await _firestore
          .collection('communities')
          .where('genre', isEqualTo: genre)
          .limit(20)
          .get();

      final communities = querySnapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .toList();

      // クライアント側でソート
      communities.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return communities;
    } catch (e) {
      _setError('ジャンル別コミュニティ取得に失敗しました');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // 招待URL生成
  Future<String?> generateInviteUrl(String communityId) async {
    try {
      _setLoading(true);
      _setError(null);

      // 招待トークンを生成
      final token = _generateRandomToken();

      // 招待情報をcommunity_invitesコレクションに保存
      await _firestore.collection('community_invites').add({
        'communityId': communityId,
        'inviteToken': token,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'maxUses': 10,
        'currentUses': 0,
        'isUsed': false,
      });

      // 招待URLを生成
      final inviteUrl = 'startend://invite/$token';

      return inviteUrl;
    } catch (e) {
      _setError('招待URL生成に失敗しました');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 招待URLで参加
  Future<bool> joinCommunityByInviteUrl(
      String inviteToken, String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      // 招待トークンを検索
      final inviteSnapshot = await _firestore
          .collection('community_invites')
          .where('inviteToken', isEqualTo: inviteToken)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();

      if (inviteSnapshot.docs.isEmpty) {
        _setError('無効な招待URLです');
        return false;
      }

      final inviteDoc = inviteSnapshot.docs.first;
      final inviteData = inviteDoc.data();
      final communityId = inviteData['communityId'] as String;
      final expiresAt = (inviteData['expiresAt'] as Timestamp).toDate();
      final maxUses = inviteData['maxUses'] as int;
      final currentUses = inviteData['currentUses'] as int;

      // 有効期限チェック
      if (DateTime.now().isAfter(expiresAt)) {
        _setError('招待URLの有効期限が切れています');
        return false;
      }

      // 使用回数チェック
      if (currentUses >= maxUses) {
        _setError('招待URLの使用回数が上限に達しています');
        return false;
      }

      // コミュニティに参加
      final success = await joinCommunity(communityId, userId: userId);
      if (!success) {
        return false;
      }

      // 招待URLの使用回数を更新
      await _firestore
          .collection('community_invites')
          .doc(inviteDoc.id)
          .update({
        'currentUses': currentUses + 1,
        'isUsed': currentUses + 1 >= maxUses,
      });

      return true;
    } catch (e) {
      _setError('招待URLでの参加に失敗しました');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ランダムトークン生成
  String _generateRandomToken() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String token = '';

    for (int i = 0; i < 32; i++) {
      token += chars[(random + i) % chars.length];
    }

    return token;
  }
}
