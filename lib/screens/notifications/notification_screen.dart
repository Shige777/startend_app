import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../constants/app_colors.dart';
import '../../services/follow_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/wave_loading_widget.dart';
import '../../utils/date_time_utils.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('通知'),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'フォローリクエスト'),
            Tab(text: '通知'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowRequestsTab(),
          _buildNotificationsTab(),
        ],
      ),
    );
  }

  Widget _buildFollowRequestsTab() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final currentUser = userProvider.currentUser;
        if (currentUser == null) {
          return const Center(child: Text('ログインしてください'));
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FollowService.getFollowRequests(currentUser.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: WaveLoadingWidget());
            }

            if (snapshot.hasError) {
              return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
            }

            final requests = snapshot.data ?? [];

            if (requests.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_disabled,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'フォローリクエストはありません',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _buildFollowRequestCard(request);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFollowRequestCard(Map<String, dynamic> request) {
    final requesterId = request['requesterId'] as String;
    final requesterName = request['requesterName'] as String;
    final createdAt = request['createdAt'];
    final requestId = request['id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Text(
                    requesterName.isNotEmpty
                        ? requesterName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requesterName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'フォローリクエストを送信しました',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          DateTimeUtils.getRelativeTime(createdAt.toDate()),
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectFollowRequest(requestId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('拒否'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveFollowRequest(
                      requestId,
                      requesterId,
                      requesterName,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                    child: const Text('承認'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final currentUser = userProvider.currentUser;
        if (currentUser == null) {
          return const Center(child: Text('ログインしてください'));
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: NotificationService().getNotificationHistory(currentUser.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: WaveLoadingWidget());
            }

            if (snapshot.hasError) {
              return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '通知はありません',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(notification);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final title = notification['title'] as String;
    final body = notification['body'] as String;
    final createdAt = notification['createdAt'];
    final isRead = notification['read'] as bool? ?? false;
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final type = data['type'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRead ? null : AppColors.primary.withOpacity(0.1),
      child: ListTile(
        leading: _getNotificationIcon(type),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateTimeUtils.getRelativeTime(createdAt.toDate()),
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  Widget _getNotificationIcon(String? type) {
    switch (type) {
      case 'follow':
        return const Icon(Icons.person_add, color: AppColors.primary);
      case 'follow_request':
        return const Icon(Icons.person_add_alt_1, color: AppColors.warning);
      case 'follow_approved':
        return const Icon(Icons.check_circle, color: AppColors.success);
      case 'post':
        return const Icon(Icons.favorite, color: AppColors.error);
      case 'community':
        return const Icon(Icons.group, color: AppColors.primary);
      default:
        return const Icon(Icons.notifications, color: AppColors.textSecondary);
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final notificationId = notification['id'] as String;
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final type = data['type'] as String?;
    final id = data['id'] as String?;

    // 通知を既読にする
    NotificationService().markAsRead(notificationId);

    // 通知の種類に応じて適切な画面に遷移
    switch (type) {
      case 'follow':
      case 'follow_approved':
        if (id != null) {
          context.push('/profile/$id');
        }
        break;
      case 'post':
        if (id != null) {
          context.push('/post/$id');
        }
        break;
      case 'community':
        if (id != null) {
          context.push('/community/$id');
        }
        break;
    }
  }

  Future<void> _approveFollowRequest(
    String requestId,
    String requesterId,
    String requesterName,
  ) async {
    try {
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;

      if (currentUser == null) return;

      final success = await FollowService.approveFollowRequest(
        requestId: requestId,
        requesterId: requesterId,
        targetUserId: currentUser.id,
        requesterName: requesterName,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フォローリクエストを承認しました')),
        );

        // ユーザー情報を更新
        await userProvider.refreshCurrentUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  Future<void> _rejectFollowRequest(String requestId) async {
    try {
      final success = await FollowService.rejectFollowRequest(requestId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フォローリクエストを拒否しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }
}
