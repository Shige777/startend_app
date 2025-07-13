import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _followNotifications = true;
  bool _likeNotifications = true;
  bool _commentNotifications = true;
  bool _communityNotifications = true;
  bool _reminderNotifications = true;
  bool _pushNotifications = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    // TODO: ユーザーの通知設定を読み込む
    // 現在はデフォルト値を使用
  }

  Future<void> _saveNotificationSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: 通知設定をFirestoreに保存
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログインが必要です')),
        );
        return;
      }

      // 通知設定をユーザーデータに保存
      final updatedUser = currentUser.copyWith(
        // TODO: 通知設定フィールドを追加
        updatedAt: DateTime.now(),
      );

      await userProvider.updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知設定を保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('通知設定'),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveNotificationSettings,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // プッシュ通知の全体設定
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'プッシュ通知',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'アプリからの通知を受け取るかどうかを設定します',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('プッシュ通知'),
                      subtitle: const Text('アプリが閉じている時も通知を受け取る'),
                      value: _pushNotifications,
                      onChanged: (value) {
                        setState(() {
                          _pushNotifications = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 通知の種類別設定
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '通知の種類',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '受け取りたい通知の種類を選択してください',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('フォロー通知'),
                      subtitle: const Text('新しいフォロワーやフォローリクエストの通知'),
                      value: _followNotifications,
                      onChanged: _pushNotifications
                          ? (value) {
                              setState(() {
                                _followNotifications = value;
                              });
                            }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('いいね通知'),
                      subtitle: const Text('投稿にいいねがついた時の通知'),
                      value: _likeNotifications,
                      onChanged: _pushNotifications
                          ? (value) {
                              setState(() {
                                _likeNotifications = value;
                              });
                            }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('コメント通知'),
                      subtitle: const Text('投稿にコメントがついた時の通知'),
                      value: _commentNotifications,
                      onChanged: _pushNotifications
                          ? (value) {
                              setState(() {
                                _commentNotifications = value;
                              });
                            }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('コミュニティ通知'),
                      subtitle: const Text('コミュニティの新しい投稿やお知らせ'),
                      value: _communityNotifications,
                      onChanged: _pushNotifications
                          ? (value) {
                              setState(() {
                                _communityNotifications = value;
                              });
                            }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('リマインダー通知'),
                      subtitle: const Text('投稿の予定時刻や進捗確認の通知'),
                      value: _reminderNotifications,
                      onChanged: _pushNotifications
                          ? (value) {
                              setState(() {
                                _reminderNotifications = value;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 通知時間の設定
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '通知時間',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '通知を受け取る時間帯を設定します',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('通知時間帯'),
                      subtitle: const Text('8:00 - 22:00'),
                      trailing: const Icon(Icons.keyboard_arrow_right),
                      onTap: () {
                        // TODO: 時間設定ダイアログを実装
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('時間設定は今後実装予定です')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 注意事項
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '注意事項',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• プッシュ通知をオフにすると、すべての通知が無効になります\n'
                      '• 端末の設定で通知が無効になっている場合は、設定アプリから有効にしてください\n'
                      '• 重要な通知（セキュリティ関連など）は設定に関わらず送信される場合があります',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
