import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final theme = Theme.of(context);
    final goldColor = theme.brightness == Brightness.dark
        ? const Color(0xFFD4AF37)
        : const Color(0xFFC5A059);

    return Scaffold(
      body: ArabesqueBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 40.h),
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, color: goldColor, size: 28.r),
                  SizedBox(width: 12.w),
                  Text(
                    'profile'.tr,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              Center(
                child: Container(
                  width: 104.r,
                  height: 104.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: goldColor.withValues(alpha: 0.12),
                    border: Border.all(color: goldColor, width: 2),
                  ),
                  child: Icon(Icons.person, color: goldColor, size: 58.r),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                'user_name'.tr,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 36.h),
              Text(
                'settings'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: goldColor,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 12.h),
              _SettingsCard(
                icon: Icons.language,
                title: 'language'.tr,
                goldColor: goldColor,
                trailing: Obx(
                  () => OutlinedButton(
                    onPressed: controller.toggleLanguage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldColor,
                      side: BorderSide(color: goldColor),
                      padding: EdgeInsets.symmetric(
                        horizontal: 18.w,
                        vertical: 10.h,
                      ),
                    ),
                    child: Text(
                      controller.currentLanguage.value == 'en' ? 'AR' : 'EN',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Obx(
                () => _SettingsCard(
                  icon: controller.isNightMode.value
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  title: 'appearance'.tr,
                  subtitle: controller.isNightMode.value
                      ? 'theme_night'.tr
                      : 'theme_light'.tr,
                  goldColor: goldColor,
                  trailing: Switch.adaptive(
                    value: controller.isNightMode.value,
                    activeColor: goldColor,
                    onChanged: (_) => controller.toggleTheme(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 5),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.goldColor,
    required this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color goldColor;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: goldColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: goldColor, size: 22.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Flexible(child: trailing),
        ],
      ),
    );
  }
}
