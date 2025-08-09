import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../constants/app_colors.dart';

import '../services/follow_service.dart';

class ProfileFollowButton extends StatefulWidget {
  final UserModel user;
  final UserModel currentUser;

  const ProfileFollowButton({
    super.key,
    required this.user,
    required this.currentUser,
  });

  @override
  State<ProfileFollowButton> createState() => _ProfileFollowButtonState();
}

class _ProfileFollowButtonState extends State<ProfileFollowButton> {
  bool _isFollowing = false;
  bool _isLoading = false;
  bool _hasRequestSent = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final isFollowing = await FollowService.isFollowing(
      followerId: widget.currentUser.id,
      followingId: widget.user.id,
    );

    // プライベートアカウントの場合、リクエスト送信済みかもチェック
    bool hasRequestSent = false;
    if (widget.user.isPrivate && !isFollowing) {
      hasRequestSent = await FollowService.hasFollowRequestSent(
        requesterId: widget.currentUser.id,
        targetUserId: widget.user.id,
      );
    }

    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _hasRequestSent = hasRequestSent;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool success;

      if (_isFollowing) {
        // フォロー解除
        success = await FollowService.unfollowUser(
          followerId: widget.currentUser.id,
          followingId: widget.user.id,
        );

        if (success) {
          setState(() {
            _isFollowing = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('フォローを解除しました')),
            );
          }
        }
      } else {
        if (widget.user.isPrivate) {
          // プライベートアカウントにフォローリクエスト送信
          success = await FollowService.sendFollowRequest(
            requesterId: widget.currentUser.id,
            targetUserId: widget.user.id,
            requesterName: widget.currentUser.displayName,
          );

          if (success) {
            setState(() {
              _hasRequestSent = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('フォローリクエストを送信しました')),
              );
            }
          }
        } else {
          // 公開アカウントを直接フォロー
          success = await FollowService.followUser(
            followerId: widget.currentUser.id,
            followingId: widget.user.id,
            followerName: widget.currentUser.displayName,
          );

          if (success) {
            setState(() {
              _isFollowing = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('フォローしました')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _hasRequestSent || _isLoading ? null : _toggleFollow,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: _hasRequestSent
                  ? AppColors.textSecondary
                  : AppColors.primary),
          foregroundColor:
              _hasRequestSent ? AppColors.textSecondary : AppColors.primary,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isFollowing
                    ? 'フォロー中'
                    : _hasRequestSent
                        ? 'リクエスト済み'
                        : widget.user.isPrivate
                            ? 'フォローリクエスト'
                            : 'フォロー',
              ),
      ),
    );
  }
}
