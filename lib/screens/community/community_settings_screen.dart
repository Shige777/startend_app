import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/community_model.dart';
import '../../providers/user_provider.dart';
import '../../services/community_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/wave_loading_widget.dart';

class CommunitySettingsScreen extends StatefulWidget {
  final String communityId;

  const CommunitySettingsScreen({
    super.key,
    required this.communityId,
  });

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  final CommunityService _communityService = CommunityService();
  final _formKey = GlobalKey<FormState>();

  CommunityModel? _community;
  bool _isLoading = true;
  bool _isSaving = false;

  // 設定項目
  bool _isPublic = true;
  CommunityCategory _category = CommunityCategory.other;
  bool _allowNewPostNotifications = true;
  bool _allowWeeklySummary = true;
  bool _allowMonthlySummary = true;
  bool _requireApproval = false;

  // コミュニティ基本情報
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _genreController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _genreController = TextEditingController();
    _loadCommunityData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityData() async {
    try {
      final community =
          await _communityService.getCommunity(widget.communityId);
      if (community != null) {
        setState(() {
          _community = community;
          _nameController.text = community.name;
          _descriptionController.text = community.description;
          _genreController.text = community.genre;

          // 設定項目
          _isPublic = community.settings.isPublic;
          _category = community.settings.category;
          _allowNewPostNotifications =
              community.settings.allowNewPostNotifications;
          _allowWeeklySummary = community.settings.allowWeeklySummary;
          _allowMonthlySummary = community.settings.allowMonthlySummary;
          _requireApproval = community.settings.requireApproval;

          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // 基本情報と設定の更新
      final updatedCommunity = _community!.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
        genre: _genreController.text,
        isPrivate: !_isPublic,
      );

      final newSettings = CommunitySettings(
        isPublic: _isPublic,
        category: _category,
        allowNewPostNotifications: _allowNewPostNotifications,
        allowWeeklySummary: _allowWeeklySummary,
        allowMonthlySummary: _allowMonthlySummary,
        requireApproval: _requireApproval,
      );

      // Firestoreのコミュニティドキュメントを直接更新
      await _communityService.updateCommunityInfo(
        widget.communityId,
        updatedCommunity,
        newSettings,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteCommunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('コミュニティを削除'),
        content: const Text('この操作は取り消せません。本当にコミュニティを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await _communityService.deleteCommunity(widget.communityId);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('コミュニティを削除しました')),
          );
          context.go('/home?tab=community');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('削除に失敗しました')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('コミュニティ設定'),
        ),
        body: const Center(
          child: WaveLoadingWidget(
            size: 80,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_community == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('コミュニティ設定'),
        ),
        body: const Center(
          child: Text('コミュニティが見つかりません'),
        ),
      );
    }

    final currentUser = context.watch<UserProvider>().currentUser;
    final isLeader =
        currentUser != null && _community!.isLeader(currentUser.id);

    if (!isLeader) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('コミュニティ設定'),
        ),
        body: const Center(
          child: Text('この機能を使用する権限がありません'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('コミュニティ設定'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本情報
              _buildBasicInfoSection(),
              const SizedBox(height: 24),

              // 公開設定
              _buildPrivacySection(),
              const SizedBox(height: 24),

              // カテゴリー設定
              _buildCategorySection(),
              const SizedBox(height: 24),

              // 通知設定
              _buildNotificationSection(),
              const SizedBox(height: 24),

              // 参加設定
              _buildJoinSection(),
              const SizedBox(height: 24),

              // 危険な操作
              _buildDangerSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基本情報',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'コミュニティ名',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'コミュニティ名を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '説明',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '説明を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _genreController,
              decoration: const InputDecoration(
                labelText: 'ジャンル',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'ジャンルを入力してください';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '公開設定',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('公開コミュニティ'),
              subtitle:
                  Text(_isPublic ? '検索結果に表示され、誰でも参加できます' : '招待リンクでのみ参加できます'),
              value: _isPublic,
              onChanged: (value) {
                setState(() {
                  _isPublic = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'カテゴリー',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CommunityCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'カテゴリーを選択',
                border: OutlineInputBorder(),
              ),
              items: CommunityCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(_getCategoryDisplayName(category)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _category = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '通知設定',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('新規投稿通知'),
              subtitle: const Text('メンバーが投稿した時に通知します'),
              value: _allowNewPostNotifications,
              onChanged: (value) {
                setState(() {
                  _allowNewPostNotifications = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('週次サマリー'),
              subtitle: const Text('週間の活動状況をまとめて配信します'),
              value: _allowWeeklySummary,
              onChanged: (value) {
                setState(() {
                  _allowWeeklySummary = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('月次サマリー'),
              subtitle: const Text('月間の活動状況をまとめて配信します'),
              value: _allowMonthlySummary,
              onChanged: (value) {
                setState(() {
                  _allowMonthlySummary = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '参加設定',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('参加承認制'),
              subtitle: const Text('新規参加者の承認が必要になります'),
              value: _requireApproval,
              onChanged: (value) {
                setState(() {
                  _requireApproval = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerSection() {
    return Card(
      color: AppColors.error.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '危険な操作',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _deleteCommunity,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('コミュニティを削除'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'この操作は取り消せません。コミュニティとすべての投稿が削除されます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryDisplayName(CommunityCategory category) {
    switch (category) {
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
