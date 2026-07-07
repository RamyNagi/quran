import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return Obx(() {
      final visible = controller.isNavBarVisible.value;
      final isNight = controller.isNightMode.value;
      final goldColor = isNight
          ? const Color(0xFFD4AF37)
          : const Color(0xFFC5A059);

      return AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        offset: visible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1.0 : 0.0,
          child: Container(
            decoration: BoxDecoration(
              color: isNight ? AppTheme.appBarDark : AppTheme.appBarLight,
              border: Border(
                top: BorderSide(color: goldColor.withValues(alpha: 0.14)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home,
                      label: 'home'.tr,
                      active: currentIndex == 0,
                      goldColor: goldColor,
                      isDark: isNight,
                      onTap: () => controller.navigateToPage(0),
                    ),
                    _NavItem(
                      icon: Icons.schedule,
                      label: 'salat'.tr,
                      active: currentIndex == 1,
                      goldColor: goldColor,
                      isDark: isNight,
                      onTap: () => controller.navigateToPage(1),
                    ),
                    _NavItem(
                      icon: Icons.menu_book,
                      label: 'quran'.tr,
                      active: currentIndex == 2,
                      goldColor: goldColor,
                      isDark: isNight,
                      onTap: () => controller.navigateToPage(2),
                    ),
                    _NavItem(
                      icon: Icons.local_library,
                      label: 'sunnah'.tr,
                      active: currentIndex == 3,
                      goldColor: goldColor,
                      isDark: isNight,
                      onTap: () => controller.navigateToPage(3),
                    ),
                    _NavItem(
                      icon: Icons.person,
                      label: 'profile'.tr,
                      active: currentIndex == 5,
                      goldColor: goldColor,
                      isDark: isNight,
                      onTap: () => controller.navigateToPage(5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.goldColor,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color goldColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    
    // Active: white for dark mode, primary green for light mode. Inactive: transparent white for dark, transparent green for light.
    final Color itemColor = active
        ? (isDark ? Colors.white : AppTheme.primaryLight)
        : (isDark ? Colors.white.withValues(alpha: 0.5) : AppTheme.primaryLight.withValues(alpha: 0.45));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: SizedBox(
        width: 68.w,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22.r,
                color: itemColor,
              ),
              SizedBox(height: 4.h),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  color: itemColor,
                ),
              ),
              SizedBox(height: 4.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 16.w : 4.w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: active ? (isDark ? goldColor : AppTheme.primaryLight) : Colors.transparent,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
