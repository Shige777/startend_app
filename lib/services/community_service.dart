import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/community_model.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 既存のメソッド...

  // 招待システム
  Future<String> generateInviteCode(String communityId) async {
    final code = _generateRandomCode();
    final currentUser = _auth.currentUser;
    if (currentUser == null) return ''; // ユーザーがログインしていない場合は空文字列を返す

    final invite = CommunityInvite(
      id: '',
      communityId: communityId,
      inviterId: currentUser.uid,
      inviteCode: code,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      maxUses: 10,
    );

    await _firestore.collection('community_invites').add(invite.toFirestore());

    // コミュニティの現在の招待コードを更新
    await _firestore.collection('communities').doc(communityId).update({
      'inviteCode': code,
    });

    return code;
  }

  Future<CommunityInvite?> getInviteByCode(String inviteCode) async {
    final querySnapshot = await _firestore
        .collection('community_invites')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;
    return CommunityInvite.fromFirestore(querySnapshot.docs.first);
  }

  Future<bool> joinCommunityByInvite(String inviteCode) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final invite = await getInviteByCode(inviteCode);
    if (invite == null || !invite.canUse) return false;

    final community = await getCommunity(invite.communityId);
    if (community == null || !community.canJoin(currentUser.uid)) return false;

    try {
      await _firestore.runTransaction((transaction) async {
        final communityRef =
            _firestore.collection('communities').doc(invite.communityId);
        final inviteRef =
            _firestore.collection('community_invites').doc(invite.id);

        // コミュニティにメンバー追加
        final newMemberIds = [...community.memberIds, currentUser.uid];
        final newMember = CommunityMember(
          userId: currentUser.uid,
          role: CommunityRole.member,
          joinedAt: DateTime.now(),
          lastActive: DateTime.now(),
        );

        final updatedMembers =
            Map<String, CommunityMember>.from(community.members);
        updatedMembers[currentUser.uid] = newMember;

        transaction.update(communityRef, {
          'memberIds': newMemberIds,
          'members':
              updatedMembers.map((key, value) => MapEntry(key, value.toMap())),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        // 招待の使用回数を更新
        transaction.update(inviteRef, {
          'currentUses': invite.currentUses + 1,
          'isUsed': invite.currentUses + 1 >= invite.maxUses,
        });

        // ユーザーのコミュニティリストに追加
        final userRef = _firestore.collection('users').doc(currentUser.uid);
        transaction.update(userRef, {
          'communityIds': FieldValue.arrayUnion([invite.communityId]),
        });
      });

      return true;
    } catch (e) {
      print('Error joining community by invite: $e');
      return false;
    }
  }

  // メンバー管理
  Future<bool> removeMember(String communityId, String memberId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final community = await getCommunity(communityId);
    if (community == null || !community.isLeader(currentUser.uid)) return false;

    try {
      await _firestore.runTransaction((transaction) async {
        final communityRef =
            _firestore.collection('communities').doc(communityId);
        final userRef = _firestore.collection('users').doc(memberId);

        // コミュニティからメンバー削除
        final newMemberIds =
            community.memberIds.where((id) => id != memberId).toList();
        final updatedMembers =
            Map<String, CommunityMember>.from(community.members);
        updatedMembers.remove(memberId);

        transaction.update(communityRef, {
          'memberIds': newMemberIds,
          'members':
              updatedMembers.map((key, value) => MapEntry(key, value.toMap())),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        // ユーザーのコミュニティリストから削除
        transaction.update(userRef, {
          'communityIds': FieldValue.arrayRemove([communityId]),
        });
      });

      return true;
    } catch (e) {
      print('Error removing member: $e');
      return false;
    }
  }

  Future<bool> leaveCommunity(String communityId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final community = await getCommunity(communityId);
    if (community == null) return false;

    try {
      await _firestore.runTransaction((transaction) async {
        final communityRef =
            _firestore.collection('communities').doc(communityId);
        final userRef = _firestore.collection('users').doc(currentUser.uid);

        if (community.isLeader(currentUser.uid)) {
          // リーダーが脱退する場合の処理
          final nextSuccessor = community.nextSuccessor;

          if (nextSuccessor != null && nextSuccessor != currentUser.uid) {
            // 後継者に権限移譲
            final updatedMembers =
                Map<String, CommunityMember>.from(community.members);
            if (updatedMembers[nextSuccessor] != null) {
              updatedMembers[nextSuccessor] =
                  updatedMembers[nextSuccessor]!.copyWith(
                role: CommunityRole.leader,
              );
            }
            updatedMembers.remove(currentUser.uid);

            final newMemberIds = community.memberIds
                .where((id) => id != currentUser.uid)
                .toList();

            transaction.update(communityRef, {
              'leaderId': nextSuccessor,
              'memberIds': newMemberIds,
              'members': updatedMembers
                  .map((key, value) => MapEntry(key, value.toMap())),
              'successorCandidateIds': [], // 後継者候補リセット
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
          } else {
            // 後継者がいない場合はコミュニティ削除
            transaction.delete(communityRef);

            // 全メンバーのコミュニティリストから削除
            for (String memberId in community.memberIds) {
              final memberRef = _firestore.collection('users').doc(memberId);
              transaction.update(memberRef, {
                'communityIds': FieldValue.arrayRemove([communityId]),
              });
            }
            return;
          }
        } else {
          // 一般メンバーの脱退
          final newMemberIds =
              community.memberIds.where((id) => id != currentUser.uid).toList();
          final updatedMembers =
              Map<String, CommunityMember>.from(community.members);
          updatedMembers.remove(currentUser.uid);

          transaction.update(communityRef, {
            'memberIds': newMemberIds,
            'members': updatedMembers
                .map((key, value) => MapEntry(key, value.toMap())),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }

        // ユーザーのコミュニティリストから削除
        transaction.update(userRef, {
          'communityIds': FieldValue.arrayRemove([communityId]),
        });
      });

      return true;
    } catch (e) {
      print('Error leaving community: $e');
      return false;
    }
  }

  // 後継者管理
  Future<bool> addSuccessorCandidate(
      String communityId, String memberId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final community = await getCommunity(communityId);
    if (community == null || !community.isLeader(currentUser.uid)) return false;
    if (!community.isMember(memberId)) return false;

    try {
      final newCandidates = [...community.successorCandidateIds];
      if (!newCandidates.contains(memberId)) {
        newCandidates.add(memberId);
      }

      await _firestore.collection('communities').doc(communityId).update({
        'successorCandidateIds': newCandidates,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return true;
    } catch (e) {
      print('Error adding successor candidate: $e');
      return false;
    }
  }

  Future<bool> removeSuccessorCandidate(
      String communityId, String memberId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final community = await getCommunity(communityId);
    if (community == null || !community.isLeader(currentUser.uid)) return false;

    try {
      final newCandidates = community.successorCandidateIds
          .where((id) => id != memberId)
          .toList();

      await _firestore.collection('communities').doc(communityId).update({
        'successorCandidateIds': newCandidates,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return true;
    } catch (e) {
      print('Error removing successor candidate: $e');
      return false;
    }
  }

  // メンバープロフィール更新
  Future<bool> updateMemberProfile(
      String communityId, String? nickname, String? bio) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final community = await getCommunity(communityId);
    if (community == null || !community.isMember(currentUser.uid)) return false;

    try {
      final updatedMembers =
          Map<String, CommunityMember>.from(community.members);
      final currentMember = updatedMembers[currentUser.uid];

      if (currentMember != null) {
        updatedMembers[currentUser.uid] = currentMember.copyWith(
          nickname: nickname,
          bio: bio,
          lastActive: DateTime.now(),
        );

        await _firestore.collection('communities').doc(communityId).update({
          'members':
              updatedMembers.map((key, value) => MapEntry(key, value.toMap())),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        return true;
      }
    } catch (e) {
      print('Error updating member profile: $e');
    }
    return false;
  }

  // オンライン状態更新
  Future<bool> updateOnlineStatus(String communityId, bool isOnline) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final community = await getCommunity(communityId);
    if (community == null || !community.isMember(currentUser.uid)) return false;

    try {
      final updatedMembers =
          Map<String, CommunityMember>.from(community.members);
      final currentMember = updatedMembers[currentUser.uid];

      if (currentMember != null) {
        updatedMembers[currentUser.uid] = currentMember.copyWith(
          isOnline: isOnline,
          lastActive: DateTime.now(),
        );

        await _firestore.collection('communities').doc(communityId).update({
          'members':
              updatedMembers.map((key, value) => MapEntry(key, value.toMap())),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        return true;
      }
    } catch (e) {
      print('Error updating online status: $e');
    }
    return false;
  }

  // コミュニティ設定更新
  Future<bool> updateCommunitySettings(
      String communityId, CommunitySettings settings) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final community = await getCommunity(communityId);
    if (community == null || !community.isLeader(currentUser.uid)) return false;

    try {
      await _firestore.collection('communities').doc(communityId).update({
        'settings': settings.toMap(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return true;
    } catch (e) {
      print('Error updating community settings: $e');
      return false;
    }
  }

  // コミュニティ削除（リーダー権限）
  Future<bool> deleteCommunity(String communityId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final community = await getCommunity(communityId);
    if (community == null || !community.isLeader(currentUser.uid)) return false;

    try {
      await _firestore.runTransaction((transaction) async {
        // コミュニティドキュメントを削除
        transaction
            .delete(_firestore.collection('communities').doc(communityId));

        // 全メンバーのコミュニティリストから削除
        for (String memberId in community.memberIds) {
          final memberRef = _firestore.collection('users').doc(memberId);
          transaction.update(memberRef, {
            'communityIds': FieldValue.arrayRemove([communityId]),
          });
        }

        // 関連する投稿のcommunityIdsからこのコミュニティIDを削除
        final postsSnapshot = await _firestore
            .collection('posts')
            .where('communityIds', arrayContains: communityId)
            .get();

        for (final postDoc in postsSnapshot.docs) {
          transaction.update(postDoc.reference, {
            'communityIds': FieldValue.arrayRemove([communityId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // 関連する招待コードを削除
        final invitesSnapshot = await _firestore
            .collection('community_invites')
            .where('communityId', isEqualTo: communityId)
            .get();

        for (final inviteDoc in invitesSnapshot.docs) {
          transaction.delete(inviteDoc.reference);
        }
      });

      return true;
    } catch (e) {
      print('Error deleting community: $e');
      return false;
    }
  }

  // コミュニティ情報更新
  Future<bool> updateCommunityInfo(
    String communityId,
    CommunityModel updatedCommunity,
    CommunitySettings settings,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final community = await getCommunity(communityId);
    if (community == null || !community.isLeader(currentUser.uid)) return false;

    try {
      await _firestore.collection('communities').doc(communityId).update({
        'name': updatedCommunity.name,
        'description': updatedCommunity.description,
        'genre': updatedCommunity.genre,
        'isPrivate': updatedCommunity.isPrivate,
        'settings': settings.toMap(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return true;
    } catch (e) {
      print('Error updating community info: $e');
      return false;
    }
  }

  // 既存のメソッドは保持...
  Future<CommunityModel?> getCommunity(String communityId) async {
    try {
      final doc =
          await _firestore.collection('communities').doc(communityId).get();
      if (doc.exists) {
        return CommunityModel.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting community: $e');
    }
    return null;
  }

  // ヘルパーメソッド
  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}
