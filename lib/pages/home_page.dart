import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../controllers/prayer_controller.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';
import '../static/mysnakbar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = Get.find<AppController>();
    final PrayerController prayerController = Get.find<PrayerController>();
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return Scaffold(
      body: ArabesqueBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopAppBar(context, controller, goldColor),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    SizedBox(height: 20.h),
                    _buildWelcomeSection(context, controller, goldColor),
                    SizedBox(height: 24.h),
                    _buildNextPrayerCard(context, prayerController, goldColor),
                    SizedBox(height: 24.h),
                    _buildOrnamentDivider(context, goldColor),
                    SizedBox(height: 16.h),
                    _buildPrayerTimesList(context, prayerController, goldColor),
                    SizedBox(height: 24.h),
                    _buildBentoActions(context, goldColor),
                    SizedBox(height: 100.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  // ── Top App Bar ────────────────────────────────────────────────────────────
  Widget _buildTopAppBar(
    BuildContext context,
    AppController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    final prayerController = Get.find<PrayerController>();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: goldColor.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & date
          Row(
            children: [
              Icon(Icons.mosque, color: goldColor, size: 24.r),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'title'.tr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  Obx(() {
                    final day = prayerController.prayerDay.value;
                    final location =
                        day?.locationLabel ?? 'loading_location'.tr;
                    final hijri = _getHijriDateString(
                      DateTime.now(),
                      controller.currentLanguage.value,
                    );
                    return Text(
                      '$hijri • $location',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          IconButton(
            icon: Icon(Icons.calendar_today, color: goldColor, size: 20.r),
            onPressed: () {
              final hijri = _getHijriDateString(
                DateTime.now(),
                controller.currentLanguage.value,
              );
              MySnackbar.showInfo(title: 'ramadan_date'.tr, message: hijri);
            },
          ),
        ],
      ),
    );
  }

  // ── Welcome ────────────────────────────────────────────────────────────────
  Widget _buildWelcomeSection(
    BuildContext context,
    AppController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          'welcome_back'.tr,
          style: TextStyle(
            color: isDark ? goldColor : theme.colorScheme.primary,
            fontSize: 17.sp,
            fontWeight: FontWeight.bold,
            fontFamily: controller.currentLanguage.value == 'ar'
                ? 'Hafs'
                : null,
          ),
        ),
        SizedBox(height: 4.h),
        Obx(
          () => Text(
            controller.userName.value,
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 36.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ── Next Prayer Card ───────────────────────────────────────────────────────
  Widget _buildNextPrayerCard(
    BuildContext context,
    PrayerController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Obx(() {
      final day = controller.prayerDay.value;
      if (day == null) {
        return Container(
          height: 180.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: goldColor.withValues(alpha: 0.18)),
          ),
          child: CircularProgressIndicator(color: goldColor),
        );
      }

      return Container(
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    goldColor.withValues(alpha: 0.3),
                    goldColor.withValues(alpha: 0.05),
                    goldColor.withValues(alpha: 0.2),
                  ]
                : [
                    theme.colorScheme.primary.withValues(alpha: 0.25),
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                    theme.colorScheme.primary.withValues(alpha: 0.18),
                  ],
          ),
        ),
        child: Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
                : theme.colorScheme.primary.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28.r),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_active,
                              color: goldColor,
                              size: 14.r,
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                'upcoming_prayer'.tr.toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: goldColor,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          day.nextPrayerKey.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'in_time'.trParams({
                            'time': controller.countdownText(),
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.inversePrimary,
                            fontStyle: FontStyle.italic,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        controller.formatTime(day.nextPrayerTime),
                        style: TextStyle(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      SizedBox(
                        width: 110.w,
                        child: Text(
                          day.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark
                                ? goldColor.withValues(alpha: 0.6)
                                : goldColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Container(
                height: 4.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2.r),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: controller.nextPrayerProgress(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: goldColor,
                      borderRadius: BorderRadius.circular(2.r),
                      boxShadow: [
                        BoxShadow(
                          color: goldColor,
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── Ornament Divider ───────────────────────────────────────────────────────
  Widget _buildOrnamentDivider(BuildContext context, Color goldColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? goldColor : theme.colorScheme.primary;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  dividerColor.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            '❧',
            style: TextStyle(
              color: dividerColor.withValues(alpha: 0.55),
              fontSize: 18.sp,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  dividerColor.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Prayer Times List ──────────────────────────────────────────────────────
  Widget _buildPrayerTimesList(
    BuildContext context,
    PrayerController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerColor = isDark ? goldColor : theme.colorScheme.primary;
    final btnColor = isDark
        ? goldColor.withValues(alpha: 0.85)
        : theme.colorScheme.primary.withValues(alpha: 0.85);

    return Obx(() {
      final day = controller.prayerDay.value;
      if (day == null) return const SizedBox.shrink();

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'prayer_times'.tr.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: headerColor,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => Get.find<AppController>().navigateToPage(1),
                child: Text(
                  'adjust_settings'.tr,
                  style: TextStyle(
                    color: btnColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Column(
            children: [
              for (final prayer in day.prayers) ...[
                _buildPrayerRow(
                  context,
                  _prayerIcon(prayer.key),
                  prayer.labelKey.tr,
                  controller.formatTime(prayer.time),
                  goldColor,
                  isHighlighted: prayer.key == day.nextPrayerKey,
                ),
                SizedBox(height: 10.h),
              ],
            ],
          ),
        ],
      );
    });
  }

  IconData _prayerIcon(String key) {
    switch (key) {
      case 'fajr':
        return Icons.wb_twilight;
      case 'dhuhr':
        return Icons.wb_sunny;
      case 'asr':
        return Icons.light_mode;
      case 'maghrib':
        return Icons.wb_twilight;
      case 'isha':
        return Icons.dark_mode;
      default:
        return Icons.schedule;
    }
  }

  Widget _buildPrayerRow(
    BuildContext context,
    IconData icon,
    String name,
    String time,
    Color goldColor, {
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? goldColor : theme.colorScheme.primary;
    final activeBg = isDark
        ? goldColor.withValues(alpha: 0.08)
        : theme.colorScheme.primary.withValues(alpha: 0.06);
    final activeBorder = isDark
        ? goldColor.withValues(alpha: 0.35)
        : theme.colorScheme.primary.withValues(alpha: 0.3);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: isHighlighted ? activeBg : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isHighlighted
              ? activeBorder
              : (isDark
                    ? goldColor.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06)),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isHighlighted
                    ? activeColor
                    : (isDark
                          ? goldColor.withValues(alpha: 0.6)
                          : theme.colorScheme.primary.withValues(alpha: 0.5)),
                size: 20.r,
              ),
              SizedBox(width: 16.w),
              Text(
                name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isHighlighted
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isHighlighted
                      ? activeColor
                      : theme.textTheme.bodyLarge?.color,
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
          Text(
            time,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 18.sp,
              color: isHighlighted
                  ? activeColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bento Actions ──────────────────────────────────────────────────────────
  Widget _buildBentoActions(BuildContext context, Color goldColor) {
    return SizedBox(
      height: 110.h,
      child: _buildBentoCard(
        context,
        Icons.explore,
        'qibla'.tr,
        'qibla_val'.tr,
        goldColor,
        onTap: () => Get.find<AppController>().navigateToPage(1),
      ),
    );
  }

  Widget _buildBentoCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color goldColor, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? goldColor : theme.colorScheme.primary;

    return InkWell(
      onTap:
          onTap ??
          () {
            MySnackbar.showInfo(title: title, message: subtitle);
          },
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isDark
                ? goldColor.withValues(alpha: 0.15)
                : theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10.r,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: accentColor, size: 20.r),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? goldColor.withValues(alpha: 0.6)
                        : theme.colorScheme.primary.withValues(alpha: 0.7),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
  String _getHijriDateString(DateTime date, String lang) {
    int year = date.year;
    int month = date.month;
    int day = date.day;

    if (month < 3) {
      year -= 1;
      month += 12;
    }

    int a = (year / 100).floor();
    int b = (a / 4).floor();
    int c = 2 - a + b;
    int e = (365.25 * (year + 4716)).floor();
    int f = (30.6001 * (month + 1)).floor();
    double jd = c + day + e + f - 1524.5;

    double epoch = 1948439.5;
    double diff = jd - epoch;

    int cycle = (diff / 10631).floor();
    double cycleRemainder = diff % 10631;

    int yearInCycle = (cycleRemainder / 354.36667).floor();
    double yearRemainder = cycleRemainder - (yearInCycle * 354.36667);

    int hijriYear = cycle * 30 + yearInCycle + 1;
    int hijriMonth = (yearRemainder / 29.5).floor() + 1;
    int hijriDay = (yearRemainder % 29.5).round();

    if (hijriDay == 0) {
      hijriMonth -= 1;
      hijriDay = 30;
    }
    if (hijriMonth == 0) {
      hijriYear -= 1;
      hijriMonth = 12;
    }
    if (hijriMonth > 12) {
      hijriMonth = 12;
    }
    if (hijriDay > 30) {
      hijriDay = 30;
    }

    final String dayStr = lang == 'ar'
        ? _toArabicDigits(hijriDay)
        : hijriDay.toString();
    final String yearStr = lang == 'ar'
        ? _toArabicDigits(hijriYear)
        : hijriYear.toString();
    final String monthName = 'hijri_month_$hijriMonth'.tr;

    return 'hijri_date_format'.trParams({
      'day': dayStr,
      'month': monthName,
      'year': yearStr,
    });
  }

  String _toArabicDigits(int number) {
    final arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((char) {
          final val = int.tryParse(char);
          return val != null ? arabicDigits[val] : char;
        })
        .join('');
  }
}
