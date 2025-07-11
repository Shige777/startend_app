import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityRole { leader, member }

enum CommunityCategory { hobby, study, work, fitness, other }

class CommunityMember {
  final String userId;
  final CommunityRole role;
  final DateTime joinedAt;
  final String? nickname;
  final String? bio;
  final bool isOnline;
  final DateTime lastActive;

  CommunityMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.nickname,
    this.bio,
    this.isOnline = false,
    required this.lastActive,
  });

  factory CommunityMember.fromMap(Map<String, dynamic> data) {
    return CommunityMember(
      userId: data['userId'] ?? '',
      role: CommunityRole.values.firstWhere(
        (e) => e.toString() == data['role'],
        orElse: () => CommunityRole.member,
      ),
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      nickname: data['nickname'],
      bio: data['bio'],
      isOnline: data['isOnline'] ?? false,
      lastActive: (data['lastActive'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role.toString(),
      'joinedAt': Timestamp.fromDate(joinedAt),
      'nickname': nickname,
      'bio': bio,
      'isOnline': isOnline,
      'lastActive': Timestamp.fromDate(lastActive),
    };
  }

  CommunityMember copyWith({
    String? userId,
    CommunityRole? role,
    DateTime? joinedAt,
    String? nickname,
    String? bio,
    bool? isOnline,
    DateTime? lastActive,
  }) {
    return CommunityMember(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      nickname: nickname ?? this.nickname,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}

class CommunityInvite {
  final String id;
  final String communityId;
  final String inviterId;
  final String? inviteeId; // 特定ユーザー招待の場合
  final String inviteCode; // 招待リンク用コード
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isUsed;
  final int maxUses;
  final int currentUses;

  CommunityInvite({
    required this.id,
    required this.communityId,
    required this.inviterId,
    this.inviteeId,
    required this.inviteCode,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
    this.maxUses = 1,
    this.currentUses = 0,
  });

  factory CommunityInvite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityInvite(
      id: doc.id,
      communityId: data['communityId'] ?? '',
      inviterId: data['inviterId'] ?? '',
      inviteeId: data['inviteeId'],
      inviteCode: data['inviteCode'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isUsed: data['isUsed'] ?? false,
      maxUses: data['maxUses'] ?? 1,
      currentUses: data['currentUses'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'communityId': communityId,
      'inviterId': inviterId,
      'inviteeId': inviteeId,
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isUsed': isUsed,
      'maxUses': maxUses,
      'currentUses': currentUses,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get canUse => !isUsed && !isExpired && currentUses < maxUses;
}

class CommunitySettings {
  final bool isPublic;
  final CommunityCategory category;
  final bool allowNewPostNotifications;
  final bool allowWeeklySummary;
  final bool allowMonthlySummary;
  final bool requireApproval;

  CommunitySettings({
    this.isPublic = true,
    this.category = CommunityCategory.other,
    this.allowNewPostNotifications = true,
    this.allowWeeklySummary = true,
    this.allowMonthlySummary = true,
    this.requireApproval = false,
  });

  factory CommunitySettings.fromMap(Map<String, dynamic> data) {
    return CommunitySettings(
      isPublic: data['isPublic'] ?? true,
      category: CommunityCategory.values.firstWhere(
        (e) => e.toString() == data['category'],
        orElse: () => CommunityCategory.other,
      ),
      allowNewPostNotifications: data['allowNewPostNotifications'] ?? true,
      allowWeeklySummary: data['allowWeeklySummary'] ?? true,
      allowMonthlySummary: data['allowMonthlySummary'] ?? true,
      requireApproval: data['requireApproval'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isPublic': isPublic,
      'category': category.toString(),
      'allowNewPostNotifications': allowNewPostNotifications,
      'allowWeeklySummary': allowWeeklySummary,
      'allowMonthlySummary': allowMonthlySummary,
      'requireApproval': requireApproval,
    };
  }

  CommunitySettings copyWith({
    bool? isPublic,
    CommunityCategory? category,
    bool? allowNewPostNotifications,
    bool? allowWeeklySummary,
    bool? allowMonthlySummary,
    bool? requireApproval,
  }) {
    return CommunitySettings(
      isPublic: isPublic ?? this.isPublic,
      category: category ?? this.category,
      allowNewPostNotifications:
          allowNewPostNotifications ?? this.allowNewPostNotifications,
      allowWeeklySummary: allowWeeklySummary ?? this.allowWeeklySummary,
      allowMonthlySummary: allowMonthlySummary ?? this.allowMonthlySummary,
      requireApproval: requireApproval ?? this.requireApproval,
    );
  }
}

class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String genre;
  final String? imageUrl;
  final String leaderId;
  final List<String> memberIds;
  final List<String> pendingMemberIds;
  final bool isPrivate;
  final int maxMembers;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 新機能フィールド
  final List<String> successorCandidateIds; // 後継者候補
  final CommunitySettings settings;
  final Map<String, CommunityMember> members; // 詳細メンバー情報
  final String? inviteCode; // 現在有効な招待コード

  CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.genre,
    this.imageUrl,
    required this.leaderId,
    required this.memberIds,
    required this.pendingMemberIds,
    required this.isPrivate,
    required this.maxMembers,
    required this.createdAt,
    required this.updatedAt,
    this.successorCandidateIds = const [],
    CommunitySettings? settings,
    this.members = const {},
    this.inviteCode,
  }) : settings = settings ?? CommunitySettings();

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // メンバー情報をパース
    Map<String, CommunityMember> membersMap = {};
    if (data['members'] != null) {
      final membersData = data['members'] as Map<String, dynamic>;
      membersMap = membersData.map(
        (key, value) => MapEntry(key, CommunityMember.fromMap(value)),
      );
    }

    return CommunityModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      genre: data['genre'] ?? '',
      imageUrl: data['imageUrl'],
      leaderId: data['leaderId'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      pendingMemberIds: List<String>.from(data['pendingMemberIds'] ?? []),
      isPrivate: data['isPrivate'] ?? false,
      maxMembers: data['maxMembers'] ?? 8,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      successorCandidateIds:
          List<String>.from(data['successorCandidateIds'] ?? []),
      settings: data['settings'] != null
          ? CommunitySettings.fromMap(data['settings'])
          : CommunitySettings(),
      members: membersMap,
      inviteCode: data['inviteCode'],
    );
  }

  Map<String, dynamic> toFirestore() {
    // メンバー情報をマップに変換
    Map<String, dynamic> membersData = {};
    members.forEach((key, value) {
      membersData[key] = value.toMap();
    });

    return {
      'name': name,
      'description': description,
      'genre': genre,
      'imageUrl': imageUrl,
      'leaderId': leaderId,
      'memberIds': memberIds,
      'pendingMemberIds': pendingMemberIds,
      'isPrivate': isPrivate,
      'maxMembers': maxMembers,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'successorCandidateIds': successorCandidateIds,
      'settings': settings.toMap(),
      'members': membersData,
      'inviteCode': inviteCode,
    };
  }

  CommunityModel copyWith({
    String? id,
    String? name,
    String? description,
    String? genre,
    String? imageUrl,
    String? leaderId,
    List<String>? memberIds,
    List<String>? pendingMemberIds,
    bool? isPrivate,
    int? maxMembers,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? successorCandidateIds,
    CommunitySettings? settings,
    Map<String, CommunityMember>? members,
    String? inviteCode,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      genre: genre ?? this.genre,
      imageUrl: imageUrl ?? this.imageUrl,
      leaderId: leaderId ?? this.leaderId,
      memberIds: memberIds ?? this.memberIds,
      pendingMemberIds: pendingMemberIds ?? this.pendingMemberIds,
      isPrivate: isPrivate ?? this.isPrivate,
      maxMembers: maxMembers ?? this.maxMembers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      successorCandidateIds:
          successorCandidateIds ?? this.successorCandidateIds,
      settings: settings ?? this.settings,
      members: members ?? this.members,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }

  // ヘルパーメソッド
  bool isLeader(String userId) {
    return leaderId == userId;
  }

  bool isMember(String userId) {
    return memberIds.contains(userId);
  }

  bool hasPendingRequest(String userId) {
    return pendingMemberIds.contains(userId);
  }

  bool canJoin(String userId) {
    return !isMember(userId) &&
        !hasPendingRequest(userId) &&
        memberIds.length < maxMembers;
  }

  bool isSuccessorCandidate(String userId) {
    return successorCandidateIds.contains(userId);
  }

  CommunityMember? getMember(String userId) {
    return members[userId];
  }

  CommunityRole? getMemberRole(String userId) {
    if (isLeader(userId)) return CommunityRole.leader;
    if (isMember(userId)) return CommunityRole.member;
    return null;
  }

  List<CommunityMember> get onlineMembers {
    return members.values.where((member) => member.isOnline).toList();
  }

  List<CommunityMember> get sortedMembers {
    final membersList = members.values.toList();
    membersList.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return membersList;
  }

  String? get nextSuccessor {
    // 指名された後継者候補から最初の有効なメンバーを返す
    for (String candidateId in successorCandidateIds) {
      if (isMember(candidateId)) {
        return candidateId;
      }
    }

    // 後継者候補がいない場合は最古参メンバー
    if (sortedMembers.isNotEmpty) {
      return sortedMembers.first.userId;
    }

    return null;
  }

  int get memberCount => memberIds.length;
  int get pendingCount => pendingMemberIds.length;
  bool get isFull => memberIds.length >= maxMembers;

  // カテゴリー表示用
  String get categoryDisplayName {
    switch (settings.category) {
      case CommunityCategory.hobby:
        return '趣味';
      case CommunityCategory.study:
        return '学習';
      case CommunityCategory.work:
        return '仕事';
      case CommunityCategory.fitness:
        return 'フィットネス';
      case CommunityCategory.other:
        return 'その他';
    }
  }
}
