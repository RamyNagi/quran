import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../widgets/arabesque_painter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = Get.find<AppController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = isDark
        ? const Color(0xFFD4AF37)
        : const Color(0xFFC5A059);

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
                    _buildNextPrayerCard(context, controller, goldColor),
                    SizedBox(height: 24.h),
                    _buildOrnamentDivider(goldColor),
                    SizedBox(height: 16.h),
                    _buildPrayerTimesList(context, goldColor),
                    SizedBox(height: 24.h),
                    _buildDailyInspiration(context, goldColor),
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
      bottomNavigationBar: _buildBottomNav(context, controller, goldColor),
    );
  }

  // ── Top App Bar ────────────────────────────────────────────────────────────
  Widget _buildTopAppBar(
    BuildContext context,
    AppController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
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
                  Obx(
                    () => Text(
                      controller.currentLanguage.value == 'en'
                          ? '12 Ramadan 1445 • London, UK'
                          : '١٢ رمضان ١٤٤٥ • لندن، بريطانيا',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10.sp,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          IconButton(
            icon: Icon(Icons.calendar_today, color: goldColor, size: 20.r),
            onPressed: () {
              Get.snackbar(
                'ramadan_date'.tr,
                '12 Ramadan 1445 AH',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: goldColor.withValues(alpha: 0.15),
                colorText: theme.colorScheme.onSurface,
              );
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
    return Column(
      children: [
        Text(
          'welcome_back'.tr.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: goldColor.withValues(alpha: 0.7),
            letterSpacing: 2.0,
            fontSize: 11.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'user_name'.tr,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 36.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── Next Prayer Card ───────────────────────────────────────────────────────
  Widget _buildNextPrayerCard(
    BuildContext context,
    AppController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            goldColor.withValues(alpha: 0.3),
            goldColor.withValues(alpha: 0.05),
            goldColor.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
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
                        'maghrib'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'in_minutes'.trParams({'val': '42'}),
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
                      '18:14',
                      style: TextStyle(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${'sunset'.tr} 18:12',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: goldColor.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20.h),
            // Progress bar
            Obx(
              () => Container(
                height: 4.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2.r),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: controller.prayerProgress.value.clamp(0.0, 1.0),
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Ornament Divider ───────────────────────────────────────────────────────
  Widget _buildOrnamentDivider(Color goldColor) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, goldColor.withValues(alpha: 0.4)],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            '❧',
            style: TextStyle(
              color: goldColor.withValues(alpha: 0.6),
              fontSize: 18.sp,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [goldColor.withValues(alpha: 0.4), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Prayer Times List ──────────────────────────────────────────────────────
  Widget _buildPrayerTimesList(BuildContext context, Color goldColor) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'prayer_times'.tr.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: goldColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Get.snackbar(
                  'settings',
                  'adjust_settings'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              child: Text(
                'adjust_settings'.tr,
                style: TextStyle(
                  color: goldColor.withValues(alpha: 0.6),
                  fontSize: 12.sp,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Column(
          children: [
            _buildPrayerRow(
              context,
              Icons.wb_twilight,
              'fajr'.tr,
              '04:32',
              goldColor,
            ),
            SizedBox(height: 10.h),
            _buildPrayerRow(
              context,
              Icons.wb_sunny,
              'dhuhr'.tr,
              '12:58',
              goldColor,
            ),
            SizedBox(height: 10.h),
            _buildPrayerRow(
              context,
              Icons.light_mode,
              'asr'.tr,
              '16:24',
              goldColor,
            ),
            SizedBox(height: 10.h),
            _buildPrayerRow(
              context,
              Icons.wb_twilight,
              'maghrib'.tr,
              '18:14',
              goldColor,
              isHighlighted: true,
            ),
            SizedBox(height: 10.h),
            _buildPrayerRow(
              context,
              Icons.dark_mode,
              'isha'.tr,
              '20:30',
              goldColor,
            ),
          ],
        ),
      ],
    );
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: isHighlighted
            ? goldColor.withValues(alpha: 0.08)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isHighlighted
              ? goldColor.withValues(alpha: 0.4)
              : goldColor.withValues(alpha: 0.1),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: goldColor.withValues(alpha: 0.6), size: 20.r),
              SizedBox(width: 16.w),
              Text(
                name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isHighlighted
                      ? FontWeight.bold
                      : FontWeight.normal,
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
                  ? goldColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Daily Inspiration ──────────────────────────────────────────────────────
  Widget _buildDailyInspiration(BuildContext context, Color goldColor) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(2.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: LinearGradient(
              colors: [
                goldColor.withValues(alpha: 0.2),
                Colors.transparent,
                goldColor.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(22.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ayah_of_the_day'.tr.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: goldColor.withValues(alpha: 0.7),
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'verse_text'.tr,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    fontSize: 20.sp,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  '— Surah Ash-Sharh 94:5',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: goldColor.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          height: 160.h,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primary,
                Colors.black,
              ],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
            padding: EdgeInsets.all(20.r),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'daily_dhikr'.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'dhikr_goal'.tr,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Bento Actions ──────────────────────────────────────────────────────────
  Widget _buildBentoActions(BuildContext context, Color goldColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      crossAxisSpacing: 16.w,
      mainAxisSpacing: 16.h,
      children: [
        _buildBentoCard(
          context,
          Icons.explore,
          'qibla'.tr,
          'qibla_val'.tr,
          goldColor,
        ),
        _buildBentoCard(
          context,
          Icons.volunteer_activism,
          'zakat'.tr,
          'zakat_val'.tr,
          goldColor,
        ),
      ],
    );
  }

  Widget _buildBentoCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Get.snackbar(
          title,
          subtitle,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: goldColor.withValues(alpha: 0.15),
          colorText: theme.colorScheme.onSurface,
        );
      },
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: goldColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: goldColor.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: goldColor, size: 20.r),
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
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: goldColor.withValues(alpha: 0.6),
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
  Widget _buildBottomNav(
    BuildContext context,
    AppController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: goldColor.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                Icons.home,
                'home'.tr,
                false,
                goldColor,
                () => controller.navigateToPage(0),
              ),
              _buildBottomNavItem(
                Icons.schedule,
                'salat'.tr,
                true,
                goldColor,
                () {},
              ),
              _buildBottomNavItem(
                Icons.menu_book,
                'quran'.tr,
                false,
                goldColor,
                () {
                  Get.snackbar(
                    'quran'.tr,
                    'explore_quran'.tr,
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
              ),
              _buildBottomNavItem(
                Icons.groups,
                'ummah'.tr,
                false,
                goldColor,
                () {
                  Get.snackbar(
                    'ummah'.tr,
                    'prayer_circles'.tr,
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
              ),
              _buildBottomNavItem(
                Icons.person,
                'profile'.tr,
                false,
                goldColor,
                () => controller.navigateToPage(5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    IconData icon,
    String label,
    bool isActive,
    Color goldColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22.r,
              color: isActive ? goldColor : Colors.grey.withValues(alpha: 0.6),
            ),
            SizedBox(height: 4.h),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isActive
                    ? goldColor
                    : Colors.grey.withValues(alpha: 0.6),
              ),
            ),
            if (isActive) ...[
              SizedBox(height: 4.h),
              Container(
                width: 4.r,
                height: 4.r,
                decoration: BoxDecoration(
                  color: goldColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
