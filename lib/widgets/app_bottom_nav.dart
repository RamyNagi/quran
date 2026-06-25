import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final theme = Theme.of(context);
    final goldColor = theme.brightness == Brightness.dark
        ? const Color(0xFFD4AF37)
        : const Color(0xFFC5A059);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
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
                onTap: () => controller.navigateToPage(0),
              ),
              _NavItem(
                icon: Icons.schedule,
                label: 'salat'.tr,
                active: currentIndex == 1,
                goldColor: goldColor,
                onTap: () => controller.navigateToPage(1),
              ),
              _NavItem(
                icon: Icons.menu_book,
                label: 'quran'.tr,
                active: currentIndex == 2,
                goldColor: goldColor,
                onTap: () => controller.navigateToPage(2),
              ),
              _NavItem(
                icon: Icons.person,
                label: 'profile'.tr,
                active: currentIndex == 5,
                goldColor: goldColor,
                onTap: () => controller.navigateToPage(5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.goldColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color goldColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                color: active ? goldColor : Colors.grey.withValues(alpha: 0.62),
              ),
              SizedBox(height: 4.h),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  color: active
                      ? goldColor
                      : Colors.grey.withValues(alpha: 0.62),
                ),
              ),
              SizedBox(height: 4.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 16.w : 4.w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: active ? goldColor : Colors.transparent,
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
