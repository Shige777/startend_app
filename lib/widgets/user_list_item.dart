import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../providers/user_provider.dart';
import '../services/follow_service.dart';

class UserListItem extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onTap;

  const UserListItem({super.key, required this.user, this.onTap});

  @override
  State<UserListItem> createState() => _UserListItemState();
}

class _UserListItemState extends State<UserListItem> {
  bool _isFollowing = false;
  bool _isLoading = false;

  // 画像URLがネットワークURLかローカルファイルパスかを判別
  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // プロフィール画像を表示するWidgetを構築
  Widget _buildProfileImage(String? imageUrl) {
    if (imageUrl == null) {
      return const CircleAvatar(
        radius: 25,
        child: Icon(Icons.person),
      );
    }

    if (_isNetworkUrl(imageUrl)) {
      // ネットワーク画像
      return CircleAvatar(
        radius: 25,
        backgroundImage: CachedNetworkImageProvider(imageUrl),
      );
    } else {
      // ローカルファイル
      if (kIsWeb) {
        // Webの場合はエラー表示
        return const CircleAvatar(
          radius: 25,
          child: Icon(Icons.error),
        );
      } else {
        // モバイルの場合はFileImageを使用
        try {
          return CircleAvatar(
            radius: 25,
            backgroundImage: FileImage(File(imageUrl)),
          );
        } catch (e) {
          return const CircleAvatar(
            radius: 25,
            child: Icon(Icons.error),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser != null) {
      final isFollowing = await FollowService.isFollowing(
        followerId: currentUser.id,
        followingId: widget.user.id,
      );
      setState(() {
        _isFollowing = isFollowing;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    if (currentUser.id == widget.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自分自身をフォローすることはできません')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool success;
      if (_isFollowing) {
        success = await FollowService.unfollowUser(
          followerId: currentUser.id,
          followingId: widget.user.id,
        );
      } else {
        if (widget.user.requiresApproval) {
          success = await FollowService.sendFollowRequest(
            requesterId: currentUser.id,
            targetUserId: widget.user.id,
            requesterName: currentUser.displayName,
          );
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('フォロー申請を送信しました')),
            );
          }
        } else {
          success = await FollowService.followUser(
            followerId: currentUser.id,
            followingId: widget.user.id,
            followerName: currentUser.displayName,
          );
        }
      }

      if (success && !widget.user.requiresApproval) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;
    final isCurrentUser = currentUser?.id == widget.user.id;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.smallPadding,
        vertical: AppConstants.smallPadding / 2,
      ),
      child: ListTile(
        onTap: widget.onTap,
        leading: _buildProfileImage(widget.user.profileImageUrl),
        title: Row(
          children: [
            Flexible(
              child: Text(
                widget.user.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.user.isPrivate) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.lock,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.user.bio!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'フォロワー ${widget.user.followersCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(width: 12),
                Text(
                  'フォロー中 ${widget.user.followingCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
        trailing: isCurrentUser
            ? null
            : SizedBox(
                width: 100,
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? AppColors.surfaceVariant
                              : AppColors.primary,
                          foregroundColor: _isFollowing
                              ? AppColors.textPrimary
                              : AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _isFollowing
                              ? 'フォロー中'
                              : widget.user.requiresApproval
                                  ? '申請'
                                  : 'フォロー',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
              ),
      ),
    );
  }
}
