import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/progress_model.dart';
import '../../services/progress_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';

class CreateGoalScreen extends StatefulWidget {
  final String? communityId;

  const CreateGoalScreen({
    super.key,
    this.communityId,
  });

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final ProgressService _progressService = ProgressService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetCountController = TextEditingController(text: '1');

  GoalType _selectedType = GoalType.custom;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 7));
  List<String> _milestones = [];
  final _milestoneController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetCountController.dispose();
    _milestoneController.dispose();
    super.dispose();
  }

  Future<void> _createGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final goalId = await _progressService.createGoal(
        title: _titleController.text,
        description: _descriptionController.text,
        type: _selectedType,
        targetDate: _targetDate,
        targetCount: int.parse(_targetCountController.text),
        communityId: widget.communityId,
        milestones: _milestones,
      );

      if (goalId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目標を作成しました')),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目標の作成に失敗しました')),
        );
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

  void _addMilestone() {
    if (_milestoneController.text.trim().isNotEmpty) {
      setState(() {
        _milestones.add(_milestoneController.text.trim());
        _milestoneController.clear();
      });
    }
  }

  void _removeMilestone(int index) {
    setState(() {
      _milestones.removeAt(index);
    });
  }

  void _selectTargetDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      setState(() {
        _targetDate = selectedDate;
      });
    }
  }

  void _updateTargetDateFromType() {
    final now = DateTime.now();
    switch (_selectedType) {
      case GoalType.daily:
        setState(() {
          _targetDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        });
        break;
      case GoalType.weekly:
        setState(() {
          _targetDate = now.add(const Duration(days: 7));
        });
        break;
      case GoalType.monthly:
        setState(() {
          _targetDate = DateTime(now.year, now.month + 1, now.day);
        });
        break;
      case GoalType.custom:
        // カスタムの場合は変更しない
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目標を作成'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGoal,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('作成'),
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

              // 目標設定
              _buildGoalSettingsSection(),
              const SizedBox(height: 24),

              // マイルストーン
              _buildMilestonesSection(),
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
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '目標タイトル',
                border: OutlineInputBorder(),
                hintText: '例: 毎日30分読書する',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'タイトルを入力してください';
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
                hintText: '目標の詳細や理由を記入してください',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '説明を入力してください';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '目標設定',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // 目標タイプ
            DropdownButtonFormField<GoalType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: '目標タイプ',
                border: OutlineInputBorder(),
              ),
              items: GoalType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeDisplayName(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                  _updateTargetDateFromType();
                }
              },
            ),
            const SizedBox(height: 16),

            // 目標回数
            TextFormField(
              controller: _targetCountController,
              decoration: const InputDecoration(
                labelText: '目標回数',
                border: OutlineInputBorder(),
                hintText: '1',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '目標回数を入力してください';
                }
                final count = int.tryParse(value);
                if (count == null || count <= 0) {
                  return '1以上の数値を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 目標日時
            InkWell(
              onTap:
                  _selectedType == GoalType.custom ? _selectTargetDate : null,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '目標日時',
                  border: const OutlineInputBorder(),
                  enabled: _selectedType == GoalType.custom,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_targetDate.year}/${_targetDate.month}/${_targetDate.day}',
                      style: TextStyle(
                        color: _selectedType == GoalType.custom
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (_selectedType == GoalType.custom)
                      const Icon(Icons.calendar_today, size: 16),
                  ],
                ),
              ),
            ),

            if (_selectedType != GoalType.custom) ...[
              const SizedBox(height: 8),
              Text(
                '※ ${_getTypeDisplayName(_selectedType)}は自動的に期限が設定されます',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMilestonesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'マイルストーン',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              '目標達成までの中間地点を設定できます',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // マイルストーン追加
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _milestoneController,
                    decoration: const InputDecoration(
                      labelText: 'マイルストーンを追加',
                      border: OutlineInputBorder(),
                      hintText: '例: 1週間継続',
                    ),
                    onFieldSubmitted: (_) => _addMilestone(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addMilestone,
                  child: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // マイルストーン一覧
            if (_milestones.isNotEmpty) ...[
              const Text(
                '設定済みマイルストーン',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _milestones.length,
                itemBuilder: (context, index) {
                  final milestone = _milestones[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(milestone),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error),
                        onPressed: () => _removeMilestone(index),
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.surfaceVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'マイルストーンが設定されていません',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTypeDisplayName(GoalType type) {
    switch (type) {
      case GoalType.daily:
        return '日次目標';
      case GoalType.weekly:
        return '週次目標';
      case GoalType.monthly:
        return '月次目標';
      case GoalType.custom:
        return 'カスタム目標';
    }
  }
}
