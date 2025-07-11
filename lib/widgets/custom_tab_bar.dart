import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<Widget> tabs;

  const CustomTabBar({super.key, required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background, // 背景色を統一
        // 境界線を削除してシームレスに
      ),
      child: TabBar(
        controller: controller,
        tabs: tabs,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}
