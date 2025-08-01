import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _likeNotifications = true;
  bool _followNotifications = true;
  bool _communityNotifications = true;
  bool _deadlineNotifications = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('通知設定'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // プッシュ通知
                SwitchListTile(
                  title: const Text('プッシュ通知'),
                  subtitle: const Text('アプリからの通知を有効にする'),
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                    });
                  },
                  activeColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
                const Divider(),

                // いいね通知
                SwitchListTile(
                  title: const Text('いいね通知'),
                  subtitle: const Text('投稿にいいねされた時の通知'),
                  value: _likeNotifications,
                  onChanged: (value) {
                    setState(() {
                      _likeNotifications = value;
                    });
                  },
                  activeColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
                const Divider(),

                // フォロー通知
                SwitchListTile(
                  title: const Text('フォロー通知'),
                  subtitle: const Text('フォローされた時の通知'),
                  value: _followNotifications,
                  onChanged: (value) {
                    setState(() {
                      _followNotifications = value;
                    });
                  },
                  activeColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
                const Divider(),

                // コミュニティ通知
                SwitchListTile(
                  title: const Text('コミュニティ通知'),
                  subtitle: const Text('コミュニティ関連の通知'),
                  value: _communityNotifications,
                  onChanged: (value) {
                    setState(() {
                      _communityNotifications = value;
                    });
                  },
                  activeColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
                const Divider(),

                // 終了予定時刻通知
                SwitchListTile(
                  title: const Text('終了予定時刻通知'),
                  subtitle: const Text('投稿の終了予定時刻が近づいた時の通知'),
                  value: _deadlineNotifications,
                  onChanged: (value) {
                    setState(() {
                      _deadlineNotifications = value;
                    });
                  },
                  activeColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
                const Divider(),

                const SizedBox(height: 32),

                // 保存ボタン
                ElevatedButton(
                  onPressed: () async {
                    await _saveNotificationSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
    );
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 設定を読み込み
      final pushNotifications = prefs.getBool('push_notifications') ?? true;
      final likeNotifications = prefs.getBool('like_notifications') ?? true;
      final followNotifications = prefs.getBool('follow_notifications') ?? true;
      final communityNotifications =
          prefs.getBool('community_notifications') ?? true;
      final deadlineNotifications =
          prefs.getBool('deadline_notifications') ?? true;

      print('読み込まれた設定:');
      print('プッシュ通知: $pushNotifications');
      print('いいね通知: $likeNotifications');
      print('フォロー通知: $followNotifications');
      print('コミュニティ通知: $communityNotifications');
      print('終了予定時刻通知: $deadlineNotifications');

      if (mounted) {
        setState(() {
          _pushNotifications = pushNotifications;
          _likeNotifications = likeNotifications;
          _followNotifications = followNotifications;
          _communityNotifications = communityNotifications;
          _deadlineNotifications = deadlineNotifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('通知設定の読み込みに失敗しました: $e');
    }
  }

  Future<void> _saveNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 各設定を個別に保存
      await prefs.setBool('push_notifications', _pushNotifications);
      await prefs.setBool('like_notifications', _likeNotifications);
      await prefs.setBool('follow_notifications', _followNotifications);
      await prefs.setBool('community_notifications', _communityNotifications);
      await prefs.setBool('deadline_notifications', _deadlineNotifications);

      // 保存が完了したことを確認
      final savedPush = prefs.getBool('push_notifications');
      final savedLike = prefs.getBool('like_notifications');
      final savedFollow = prefs.getBool('follow_notifications');
      final savedCommunity = prefs.getBool('community_notifications');
      final savedDeadline = prefs.getBool('deadline_notifications');

      print('保存された設定:');
      print('プッシュ通知: $savedPush');
      print('いいね通知: $savedLike');
      print('フォロー通知: $savedFollow');
      print('コミュニティ通知: $savedCommunity');
      print('終了予定時刻通知: $savedDeadline');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知設定を保存しました')),
        );
        context.pop();
      }
    } catch (e) {
      print('通知設定保存エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('通知設定の保存に失敗しました: $e')),
        );
      }
    }
  }
}
