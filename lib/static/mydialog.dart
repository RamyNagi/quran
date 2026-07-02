import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';

class MyDialog {
  static Future<T?> show<T>({
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    IconData? icon,
    bool isDismissible = true,
  }) {
    final isDark = Get.isDarkMode;

    final bgColor = isDark ? AppTheme.surfaceNight : AppTheme.surfaceLight;
    final textColor = isDark ? AppTheme.textNight : AppTheme.textLight;
    final textVarColor = isDark ? AppTheme.textVariantNight : AppTheme.textVariantLight;
    final goldColor = isDark ? AppTheme.goldNight : AppTheme.goldLight;
    final borderColor = goldColor.withOpacity(0.15);

    return Get.dialog<T>(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top elegant design element
              Container(
                height: 4.h,
                width: 40.w,
                margin: EdgeInsets.only(top: 12.h),
                decoration: BoxDecoration(
                  color: goldColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),
              if (icon != null) ...[
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: goldColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: goldColor.withOpacity(0.2), width: 1.5),
                  ),
                  child: Icon(
                    icon,
                    size: 32.r,
                    color: goldColor,
                  ),
                ),
                SizedBox(height: 16.h),
              ],
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: goldColor,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 14.sp,
                    color: textColor.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              // Buttons
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: textColor.withOpacity(0.08), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    if (cancelText != null || onCancel != null)
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Get.back();
                            if (onCancel != null) onCancel();
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(24.r),
                              ),
                            ),
                          ),
                          child: Text(
                            cancelText ?? 'cancel'.tr,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: textVarColor,
                            ),
                          ),
                        ),
                      ),
                    if ((cancelText != null || onCancel != null) && (confirmText != null || onConfirm != null))
                      Container(
                        height: 48.h,
                        width: 1,
                        color: textColor.withOpacity(0.08),
                      ),
                    if (confirmText != null || onConfirm != null)
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Get.back();
                            if (onConfirm != null) onConfirm();
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(24.r),
                                bottomLeft: (cancelText == null && onCancel == null)
                                    ? Radius.circular(24.r)
                                    : Radius.zero,
                              ),
                            ),
                          ),
                          child: Text(
                            confirmText ?? 'confirm'.tr,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: goldColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: isDismissible,
      barrierColor: Colors.black.withOpacity(0.55),
    );
  }
}
