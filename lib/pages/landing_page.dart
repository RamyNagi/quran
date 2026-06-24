import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../widgets/arabesque_painter.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

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
              _buildHeader(context, controller, goldColor),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    SizedBox(height: 30.h),
                    _buildHeroSection(context, controller, goldColor),
                    SizedBox(height: 50.h),
                    _buildDevotionalRhythms(context, goldColor),
                    SizedBox(height: 50.h),
                    _buildVerseOfTheMoment(context, controller, goldColor),
                    SizedBox(height: 50.h),
                    _buildCommunitySection(context, goldColor),
                    SizedBox(height: 60.h),
                    _buildFooter(context, goldColor),
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

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(
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
        children: [
          // Location Info
          Expanded(
            child: Row(
              children: [
                Icon(Icons.location_on, color: goldColor, size: 18.r),
                SizedBox(width: 4.w),
                Expanded(
                  child: Obx(
                    () => Text(
                      controller.currentLanguage.value == 'en'
                          ? '12 RAMADAN • LONDON'
                          : '١٢ رمضان • لندن',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: goldColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // App Logo
          Flexible(
            child: Text(
              'title'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: goldColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Section ───────────────────────────────────────────────────────────
  Widget _buildHeroSection(
    BuildContext context,
    AppController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Established label
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32.w,
              height: 1,
              color: goldColor.withValues(alpha: 0.3),
            ),
            SizedBox(width: 8.w),
            Text(
              'est_1445'.tr,
              style: theme.textTheme.labelMedium?.copyWith(
                color: goldColor,
                fontSize: 11.sp,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              width: 32.w,
              height: 1,
              color: goldColor.withValues(alpha: 0.3),
            ),
          ],
        ),
        SizedBox(height: 20.h),

        // Display Title
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.textTheme.displayLarge,
            children: [
              TextSpan(text: '${'hero_title_1'.tr}\n'),
              TextSpan(
                text: 'hero_title_2'.tr,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: goldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),

        // Subtitle
        Text(
          'hero_subtitle'.tr,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
        SizedBox(height: 32.h),

        // CTAs
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldColor,
                  foregroundColor: theme.brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 48.w,
                    vertical: 16.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  elevation: 4,
                ),
                onPressed: () => controller.navigateToPage(1),
                child: Text(
                  'begin_reflection'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: goldColor,
                  side: BorderSide(color: goldColor.withValues(alpha: 0.5)),
                  padding: EdgeInsets.symmetric(
                    horizontal: 48.w,
                    vertical: 16.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                ),
                onPressed: () {
                  Get.snackbar(
                    'title'.tr,
                    'explore_quran'.tr,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: goldColor.withValues(alpha: 0.2),
                    colorText: theme.colorScheme.onSurface,
                  );
                },
                child: Text(
                  'explore_quran'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 30.h),

        // Decorative moon element
        Column(
          children: [
            Icon(
              Icons.dark_mode_outlined,
              size: 48.r,
              color: goldColor.withValues(alpha: 0.4),
            ),
            SizedBox(height: 16.h),
            Container(
              width: 1,
              height: 60.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    goldColor.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Devotional Rhythms ─────────────────────────────────────────────────────
  Widget _buildDevotionalRhythms(BuildContext context, Color goldColor) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(Icons.settings_input_component, color: goldColor, size: 24.r),
        SizedBox(height: 8.h),
        Text('devotional_rhythms'.tr, style: theme.textTheme.headlineLarge),
        SizedBox(height: 12.h),
        _buildDivider(goldColor),
        SizedBox(height: 24.h),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.3,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 16.h,
          children: [
            _buildPrayerTimeCard('fajr'.tr, '04:12', false, goldColor, theme),
            _buildPrayerTimeCard('dhuhr'.tr, '13:04', false, goldColor, theme),
            _buildPrayerTimeCard('asr'.tr, '16:42', false, goldColor, theme),
            _buildPrayerTimeCard('maghrib'.tr, '18:21', true, goldColor, theme),
            _buildPrayerTimeCard('isha'.tr, '20:15', false, goldColor, theme),
          ],
        ),
      ],
    );
  }

  Widget _buildPrayerTimeCard(
    String name,
    String time,
    bool isActive,
    Color goldColor,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? goldColor.withValues(alpha: 0.15)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isActive ? goldColor : goldColor.withValues(alpha: 0.1),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: goldColor.withValues(alpha: 0.1),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive
                        ? goldColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  time,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: isActive
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Positioned(
              bottom: 8.h,
              right: 8.w,
              child: Icon(
                Icons.fiber_manual_record,
                size: 10.r,
                color: goldColor,
              ),
            ),
        ],
      ),
    );
  }

  // ── Verse of the Moment ────────────────────────────────────────────────────
  Widget _buildVerseOfTheMoment(
    BuildContext context,
    AppController controller,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.format_quote, size: 40.r, color: goldColor),
          SizedBox(height: 12.h),
          Text(
            'verse_text'.tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20.w,
                height: 1,
                color: goldColor.withValues(alpha: 0.2),
              ),
              SizedBox(width: 8.w),
              Text(
                'verse_ref'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: goldColor,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 20.w,
                height: 1,
                color: goldColor.withValues(alpha: 0.2),
              ),
            ],
          ),
          SizedBox(height: 30.h),
          Row(
            children: [
              Expanded(
                child: _buildVerseQuickAction(
                  context,
                  Icons.auto_stories,
                  'continue_reading'.tr,
                  'Surah Al-Kahf, Ayah 12',
                  goldColor,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Obx(
                  () => _buildVerseQuickAction(
                    context,
                    Icons.volunteer_activism,
                    'daily_tasbih'.tr,
                    '${((controller.tasbihCount.value / 33) * 100).toInt()}% completed',
                    goldColor,
                    onTap: () => controller.incrementTasbih(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerseQuickAction(
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
            Get.snackbar(
              title,
              subtitle,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: goldColor.withValues(alpha: 0.15),
              colorText: theme.colorScheme.onSurface,
            );
          },
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16.r),
          border: Border(
            left: BorderSide(color: goldColor.withValues(alpha: 0.5), width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20.r, color: goldColor),
            SizedBox(height: 6.h),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
  }

  // ── Community Section ──────────────────────────────────────────────────────
  Widget _buildCommunitySection(BuildContext context, Color goldColor) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'sacred_connection'.tr,
          style: theme.textTheme.headlineLarge,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12.h),
        Text(
          'sacred_desc'.tr,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 30.h),

        // Community image
        Container(
          height: 250.h,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
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
              borderRadius: BorderRadius.circular(20.r),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
            padding: EdgeInsets.all(20.r),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color:
                      theme.cardTheme.color?.withValues(alpha: 0.9) ??
                      Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(15.r),
                  border: Border.all(color: goldColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2,400+',
                      style: TextStyle(
                        color: goldColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'sojourners'.tr.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 9.sp,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: 24.h),
        _buildCommunityFeatureRow(
          context,
          Icons.hub,
          'prayer_circles'.tr,
          'prayer_circles_desc'.tr,
          goldColor,
        ),
        SizedBox(height: 16.h),
        _buildCommunityFeatureRow(
          context,
          Icons.language,
          'global_resonance'.tr,
          'global_resonance_desc'.tr,
          goldColor,
        ),
      ],
    );
  }

  Widget _buildCommunityFeatureRow(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40.r,
          height: 40.r,
          decoration: BoxDecoration(
            color: goldColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: goldColor.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: goldColor, size: 20.r),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildDivider(Color goldColor) {
    return Container(
      width: 150.w,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, goldColor, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, Color goldColor) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildDivider(goldColor),
        SizedBox(height: 24.h),
        Text(
          'title'.tr,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: goldColor.withValues(alpha: 0.2),
            fontStyle: FontStyle.italic,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'curated_for_soul'.tr,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10.sp,
            letterSpacing: 2,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ],
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
                true,
                goldColor,
                () {},
              ),
              _buildBottomNavItem(
                Icons.schedule,
                'salat'.tr,
                false,
                goldColor,
                () => controller.navigateToPage(1),
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
          ],
        ),
      ),
    );
  }
}
