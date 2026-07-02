import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';

class MySnackbar {
  static void show({
    required String title,
    required String message,
    required IconData icon,
    required Color statusColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final isDark = Get.isDarkMode;
    final bgColor = isDark ? AppTheme.surfaceNight : AppTheme.surfaceLight;
    final textColor = isDark ? AppTheme.textNight : AppTheme.textLight;
    final goldColor = isDark ? AppTheme.goldNight : AppTheme.goldLight;

    Get.rawSnackbar(
      titleText: Text(
        title,
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: goldColor,
        ),
      ),
      messageText: Text(
        message,
        style: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 13.sp,
          color: textColor.withOpacity(0.9),
        ),
      ),
      icon: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: statusColor,
          size: 22.r,
        ),
      ),
      backgroundColor: bgColor,
      borderRadius: 16.r,
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      borderWidth: 1.5,
      borderColor: statusColor.withOpacity(0.2),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      duration: duration,
      snackPosition: SnackPosition.TOP,
      barBlur: 0,
      dismissDirection: DismissDirection.horizontal,
    );
  }

  static void showSuccess({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      statusColor: const Color(0xFF2ECC71),
      duration: duration,
    );
  }

  static void showError({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      title: title,
      message: message,
      icon: Icons.error_outline_rounded,
      statusColor: const Color(0xFFE74C3C),
      duration: duration,
    );
  }

  static void showInfo({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      title: title,
      message: message,
      icon: Icons.info_outline_rounded,
      statusColor: const Color(0xFF3498DB),
      duration: duration,
    );
  }

  static void showWarning({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    final isDark = Get.isDarkMode;
    final goldColor = isDark ? AppTheme.goldNight : AppTheme.goldLight;
    show(
      title: title,
      message: message,
      icon: Icons.warning_amber_rounded,
      statusColor: goldColor,
      duration: duration,
    );
  }
}
