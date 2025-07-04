import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
    );
  }

  Map<String, dynamic> toFirestore() {
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

  int get memberCount => memberIds.length;
  int get pendingCount => pendingMemberIds.length;
  bool get isFull => memberIds.length >= maxMembers;

  // 最古参メンバーを取得（リーダー継承用）
  String? get oldestMemberId {
    if (memberIds.isEmpty) return null;
    // 実際の実装では、メンバーの参加日時を管理する別のコレクションが必要
    return memberIds.first;
  }
}
