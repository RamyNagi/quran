import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../controllers/prayer_controller.dart';
import '../services/quran_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';
import '../static/mysnakbar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = Get.find<AppController>();
    final PrayerController prayerController = Get.find<PrayerController>();
    final QuranService quranService = Get.find<QuranService>();
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
                    _buildNextPrayerCard(context, prayerController, goldColor),
                    SizedBox(height: 24.h),
                    _buildOrnamentDivider(goldColor),
                    SizedBox(height: 16.h),
                    _buildPrayerTimesList(context, prayerController, goldColor),
                    SizedBox(height: 24.h),
                    _buildDailyInspiration(
                      context,
                      controller,
                      quranService,
                      goldColor,
                    ),
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
              MySnackbar.showInfo(
                title: 'ramadan_date'.tr,
                message: '12 Ramadan 1445 AH',
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
                          day.nextPrayerKey.tr,
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
                          color: Colors.white,
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
                            color: goldColor.withValues(alpha: 0.6),
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
                  color: Colors.white.withValues(alpha: 0.1),
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
  Widget _buildPrayerTimesList(
    BuildContext context,
    PrayerController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
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
                  color: goldColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => Get.find<AppController>().navigateToPage(1),
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
  Widget _buildDailyInspiration(
    BuildContext context,
    AppController controller,
    QuranService quranService,
    Color goldColor,
  ) {
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
                Obx(() {
                  controller.currentDayKey.value;
                  final ayah = quranService.getAyahOfDay(
                    DateTime.now(),
                    arabicReference: controller.currentLanguage.value == 'ar',
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ayah.verse.text,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                          fontSize: 20.sp,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        '— ${ayah.reference}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: goldColor.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        InkWell(
          onTap: controller.showCurrentDhikr,
          borderRadius: BorderRadius.circular(24.r),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 172.h),
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
            padding: EdgeInsets.all(20.r),
            child: Obx(() {
              final dhikr = controller.currentDailyDhikr;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.self_improvement,
                        color: goldColor,
                        size: 20.r,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'daily_dhikr'.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        color: Colors.white70,
                        size: 18.r,
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    dhikr.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      height: 1.45,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    dhikr.reference,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: controller.dhikrProgressValue,
                      minHeight: 6.h,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.dhikrProgressLabel,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed:
                            controller.dhikrCompletedCount.value >=
                                controller.dhikrDailyTarget.value
                            ? null
                            : controller.completeCurrentDhikr,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text('dhikr_done'.tr),
                        style: FilledButton.styleFrom(
                          backgroundColor: goldColor,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.18,
                          ),
                          disabledForegroundColor: Colors.white54,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
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
          onTap: () => Get.find<AppController>().navigateToPage(1),
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
    Color goldColor, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap:
          onTap ??
          () {
            MySnackbar.showInfo(
              title: title,
              message: subtitle,
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
}
