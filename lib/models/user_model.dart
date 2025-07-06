import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? profileImageUrl;
  final String? bio;
  final List<String> followerIds;
  final List<String> followingIds;
  final List<String> communityIds;
  final int postCount;
  final bool isPrivate;
  final bool requiresApproval;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
    this.bio,
    required this.followerIds,
    required this.followingIds,
    required this.communityIds,
    this.postCount = 0,
    required this.isPrivate,
    required this.requiresApproval,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      bio: data['bio'],
      followerIds: List<String>.from(data['followerIds'] ?? []),
      followingIds: List<String>.from(data['followingIds'] ?? []),
      communityIds: List<String>.from(data['communityIds'] ?? []),
      postCount: data['postCount'] ?? 0,
      isPrivate: data['isPrivate'] ?? false,
      requiresApproval: data['requiresApproval'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'followerIds': followerIds,
      'followingIds': followingIds,
      'communityIds': communityIds,
      'postCount': postCount,
      'isPrivate': isPrivate,
      'requiresApproval': requiresApproval,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    List<String>? followerIds,
    List<String>? followingIds,
    List<String>? communityIds,
    int? postCount,
    bool? isPrivate,
    bool? requiresApproval,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      followerIds: followerIds ?? this.followerIds,
      followingIds: followingIds ?? this.followingIds,
      communityIds: communityIds ?? this.communityIds,
      postCount: postCount ?? this.postCount,
      isPrivate: isPrivate ?? this.isPrivate,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ヘルパーメソッド
  bool isFollowing(String userId) {
    return followingIds.contains(userId);
  }

  bool isFollowedBy(String userId) {
    return followerIds.contains(userId);
  }

  bool isMutualFollow(String userId) {
    return isFollowing(userId) && isFollowedBy(userId);
  }

  bool isInCommunity(String communityId) {
    return communityIds.contains(communityId);
  }

  int get followersCount => followerIds.length;
  int get followingCount => followingIds.length;
  int get communitiesCount => communityIds.length;
}
