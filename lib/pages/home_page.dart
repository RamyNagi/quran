import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran;
import 'package:url_launcher/url_launcher.dart';

import '../controllers/app_controller.dart';
import '../controllers/prayer_controller.dart';
import '../services/quran_service.dart';
import '../services/audio_download_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';
import '../static/mysnakbar.dart';
import 'profile_page.dart';
import 'quran_audio_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _DownloadedReciterInfo {
  _DownloadedReciterInfo({required this.reciter, required this.surahIds});
  final QuranReciterOption reciter;
  final List<int> surahIds;
}

class _HomePageState extends State<HomePage> {
  late Future<List<_DownloadedReciterInfo>> _downloadsFuture;
  final Set<String> _expandedReciters = {};
  bool _showDownloads = false;

  @override
  void initState() {
    super.initState();
    _refreshDownloads();
  }

  void _refreshDownloads() {
    setState(() {
      _downloadsFuture = _loadDownloads();
    });
  }

  Future<List<_DownloadedReciterInfo>> _loadDownloads() async {
    final downloadService = Get.find<AudioDownloadService>();
    final List<_DownloadedReciterInfo> list = [];

    for (final reciter in QuranService.reciters) {
      final downloadedSurahIds = await downloadService.getDownloadedSurahs(reciter.key);
      if (downloadedSurahIds.isNotEmpty) {
        list.add(_DownloadedReciterInfo(
          reciter: reciter,
          surahIds: downloadedSurahIds.toList()..sort(),
        ));
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = Get.find<AppController>();
    final PrayerController prayerController = Get.find<PrayerController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = theme.colorScheme.secondary;
    final accentColor = isDark ? goldColor : theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white : Colors.black);

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

                    // Appearance settings card on HomePage
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
                          activeColor: accentColor,
                          onChanged: (_) => controller.toggleTheme(),
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // Audio downloads manager section on HomePage
                    // Audio downloads manager section on HomePage
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(22.r),
                        border: Border.all(
                          color: isDark
                              ? goldColor.withValues(alpha: 0.18)
                              : theme.colorScheme.primary.withValues(alpha: 0.12),
                        ),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: theme.shadowColor.withValues(alpha: 0.03),
                                  blurRadius: 10.r,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showDownloads = !_showDownloads;
                              });
                            },
                            borderRadius: BorderRadius.circular(22.r),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(10.r),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(14.r),
                                        ),
                                        child: Icon(
                                          Icons.cloud_download_outlined,
                                          color: accentColor,
                                          size: 22.r,
                                        ),
                                      ),
                                      SizedBox(width: 14.w),
                                      Text(
                                        'audio_downloads_manager'.tr,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    _showDownloads ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: accentColor,
                                    size: 24.r,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showDownloads) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Divider(
                                color: isDark
                                    ? goldColor.withValues(alpha: 0.15)
                                    : theme.colorScheme.primary.withValues(alpha: 0.1),
                                height: 1,
                              ),
                            ),
                            FutureBuilder<List<_DownloadedReciterInfo>>(
                              future: _downloadsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.r),
                                      child: CircularProgressIndicator(color: accentColor),
                                    ),
                                  );
                                }

                                final list = snapshot.data ?? [];
                                if (list.isEmpty) {
                                  return Padding(
                                    padding: EdgeInsets.all(20.r),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.cloud_off,
                                          color: isDark ? goldColor.withValues(alpha: 0.5) : theme.colorScheme.primary.withValues(alpha: 0.5),
                                          size: 24.r,
                                        ),
                                        SizedBox(width: 14.w),
                                        Expanded(
                                          child: Text(
                                            'no_downloads_yet'.tr,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: isDark ? theme.textTheme.bodyMedium?.color : theme.colorScheme.primary.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: list.length,
                                  padding: EdgeInsets.all(16.r),
                                  separatorBuilder: (context, index) => SizedBox(height: 14.h),
                                  itemBuilder: (context, index) {
                                    final info = list[index];
                                    final isExpanded = _expandedReciters.contains(info.reciter.key);
                                    final isFullQuran = info.surahIds.length == 114;
                                    final subtitleText = isFullQuran
                                        ? 'full_quran_downloaded'.tr
                                        : 'surahs_count_label'.trParams({'count': '${info.surahIds.length}'});

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: theme.brightness == Brightness.dark
                                            ? Colors.white.withValues(alpha: 0.02)
                                            : Colors.black.withValues(alpha: 0.01),
                                        borderRadius: BorderRadius.circular(22.r),
                                        border: Border.all(
                                          color: isDark
                                              ? goldColor.withValues(alpha: 0.1)
                                              : theme.colorScheme.primary.withValues(alpha: 0.06),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(22.r),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedReciters.remove(info.reciter.key);
                                              } else {
                                                _expandedReciters.clear();
                                                _expandedReciters.add(info.reciter.key);
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.all(16.r),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: EdgeInsets.all(10.r),
                                                      decoration: BoxDecoration(
                                                        color: accentColor.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(14.r),
                                                      ),
                                                      child: Icon(Icons.record_voice_over, color: accentColor, size: 22.r),
                                                    ),
                                                    SizedBox(width: 14.w),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            info.reciter.name,
                                                            style: theme.textTheme.bodyLarge?.copyWith(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16.sp,
                                                            ),
                                                          ),
                                                          Text(
                                                            subtitleText,
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                              color: isDark ? theme.textTheme.bodySmall?.color : theme.colorScheme.primary.withValues(alpha: 0.7),
                                                              fontWeight: isFullQuran ? FontWeight.bold : FontWeight.normal,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Icon(
                                                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                                      color: accentColor,
                                                      size: 24.r,
                                                    ),
                                                  ],
                                                ),
                                                if (isExpanded) ...[
                                                  Padding(
                                                    padding: EdgeInsets.symmetric(vertical: 8.h),
                                                    child: Divider(
                                                      color: isDark
                                                          ? goldColor.withValues(alpha: 0.15)
                                                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                                                      height: 1,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  if (isFullQuran)
                                                    Container(
                                                      width: double.infinity,
                                                      padding: EdgeInsets.symmetric(vertical: 8.h),
                                                      margin: EdgeInsets.only(bottom: 12.h),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.withValues(alpha: 0.08),
                                                        borderRadius: BorderRadius.circular(14.r),
                                                        border: Border.all(
                                                          color: Colors.green.withValues(alpha: 0.2),
                                                          width: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  _DownloadedSurahsList(
                                                    info: info,
                                                    isDark: isDark,
                                                    accentColor: accentColor,
                                                    textColor: textColor,
                                                    theme: theme,
                                                    controller: controller,
                                                    onRefresh: _refreshDownloads,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 30.h),

                    // Premium Developer credits section
                    Padding(
                      padding: EdgeInsets.only(top: 20.h, bottom: 40.h),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40.w,
                                height: 1.h,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      goldColor.withValues(alpha: 0.0),
                                      goldColor.withValues(alpha: 0.35),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10.w),
                                child: Icon(
                                  Icons.favorite,
                                  size: 10.r,
                                  color: goldColor.withValues(alpha: 0.65),
                                ),
                              ),
                              Container(
                                width: 40.w,
                                height: 1.h,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      goldColor.withValues(alpha: 0.35),
                                      goldColor.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14.h),
                          Text(
                            'developed_by'.tr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textColor.withValues(alpha: 0.55),
                              fontSize: 11.sp,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 14.h),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12.w,
                            runSpacing: 8.h,
                            children: [
                              _buildDeveloperChip(
                                context: context,
                                name: 'mahmoud_shebl'.tr,
                                phoneNumber: '01228580853',
                                goldColor: goldColor,
                                accentColor: accentColor,
                                isDark: isDark,
                              ),
                              _buildDeveloperChip(
                                context: context,
                                name: 'ramy_nagi'.tr,
                                phoneNumber: '01286348550',
                                goldColor: goldColor,
                                accentColor: accentColor,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

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
                    final location = day?.locationLabel ?? 'loading_location'.tr;
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
          Row(
            children: [
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
              Padding(
                padding: EdgeInsets.only(right: 4.w, left: 4.w),
                child: InkWell(
                  onTap: () {
                    Get.to(() => const ProfilePage());
                  },
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    width: 32.r,
                    height: 32.r,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.brightness == Brightness.dark
                          ? Colors.transparent
                          : theme.colorScheme.primary,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: theme.brightness == Brightness.dark
                          ? goldColor
                          : Colors.white,
                      size: 20.r,
                    ),
                  ),
                ),
              ),
            ],
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
            fontFamily: controller.currentLanguage.value == 'ar' ? 'Hafs' : null,
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
                            color: isDark ? goldColor.withValues(alpha: 0.6) : goldColor,
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

  String _getHijriDateString(DateTime date, String lang) {
    int year = date.year;
    int month = date.month;
    int day = date.day;

    if (month < 3) {
      year -= 1;
      month += 12;
    }

    final a = (year / 100).floor();
    final b = (a / 4).floor();
    final c = 2 - a + b;
    final e = (365.25 * (year + 4716)).floor();
    final f = (30.6001 * (month + 1)).floor();
    final jd = c + day + e + f - 1524.5;

    final base = jd - 1948439.5 + 0.5;
    final hijriYear = (base / 354.367068).floor();
    final rem = base - (hijriYear * 354.367068).floor();
    var hijriMonth = (rem / 29.530588).floor() + 1;
    var hijriDay = (rem - ((hijriMonth - 1) * 29.530588).floor()).floor() + 4;

    if (hijriDay > 30) {
      hijriDay -= 30;
      hijriMonth += 1;
    }
    if (hijriMonth > 12) {
      hijriMonth -= 12;
    }

    final List<String> arMonths = [
      'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر',
      'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
      'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
    ];

    final List<String> enMonths = [
      'Muharram', 'Safar', 'Rabi\' I', 'Rabi\' II',
      'Jumada I', 'Jumada II', 'Rajab', 'Sha\'ban',
      'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
    ];

    if (lang == 'ar') {
      return '$hijriDay ${arMonths[hijriMonth - 1]} $hijriYear هـ';
    } else {
      return '$hijriDay ${enMonths[hijriMonth - 1]} $hijriYear AH';
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        MySnackbar.showError(title: 'error'.tr, message: 'Could not launch dialer');
      }
    } catch (e) {
      MySnackbar.showError(
        title: 'error'.tr,
        message: 'Could not launch dialer: $e',
      );
    }
  }

  Widget _buildDeveloperChip({
    required BuildContext context,
    required String name,
    required String phoneNumber,
    required Color goldColor,
    required Color accentColor,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _makePhoneCall(phoneNumber),
      borderRadius: BorderRadius.circular(30.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.03),
                    Colors.white.withValues(alpha: 0.01),
                  ]
                : [
                    theme.colorScheme.primary.withValues(alpha: 0.04),
                    theme.colorScheme.primary.withValues(alpha: 0.01),
                  ],
          ),
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(
            color: isDark
                ? goldColor.withValues(alpha: 0.15)
                : theme.colorScheme.primary.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.02),
                    blurRadius: 6.r,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(5.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.phone_in_talk,
                size: 11.r,
                color: accentColor,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white.withValues(alpha: 0.9) : theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Settings Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.goldColor,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color goldColor;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? goldColor : theme.colorScheme.primary;

    final card = Container(
      constraints: BoxConstraints(minHeight: 78.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? goldColor.withValues(alpha: 0.18)
              : theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.03),
                  blurRadius: 10.r,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: accentColor, size: 22.r),
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
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? theme.textTheme.bodySmall?.color : theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          trailing,
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: onTap,
          child: card,
        ),
      );
    }
    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Downloaded Surahs List Widget
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadedSurahsList extends StatefulWidget {
  const _DownloadedSurahsList({
    required this.info,
    required this.isDark,
    required this.accentColor,
    required this.textColor,
    required this.theme,
    required this.controller,
    required this.onRefresh,
  });

  final _DownloadedReciterInfo info;
  final bool isDark;
  final Color accentColor;
  final Color textColor;
  final ThemeData theme;
  final AppController controller;
  final VoidCallback onRefresh;

  @override
  State<_DownloadedSurahsList> createState() => _DownloadedSurahsListState();
}

class _DownloadedSurahsListState extends State<_DownloadedSurahsList> {
  String _query = '';
  final ScrollController _scrollController = ScrollController();

  String _normalizeArabic(String text) {
    var str = text;
    str = str.replaceAll(RegExp(r'[أإآأ]'), 'ا');
    str = str.replaceAll(RegExp(r'[ة]'), 'ه');
    str = str.replaceAll(RegExp(r'[ى]'), 'ي');
    str = str.replaceAll(RegExp(r'[\u064B-\u065F]'), ''); // Remove diacritics
    return str;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _normalizeArabic(_query.trim().toLowerCase());
    final filteredSurahIds = widget.info.surahIds.where((surahId) {
      if (normalizedQuery.isEmpty) return true;
      final surahNameAr = _normalizeArabic(quran.getSurahNameArabic(surahId));
      final surahNameEn = quran.getSurahName(surahId).toLowerCase();
      return surahNameAr.contains(normalizedQuery) ||
          surahNameEn.contains(normalizedQuery) ||
          surahId.toString() == normalizedQuery;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: TextField(
            style: widget.theme.textTheme.bodyMedium?.copyWith(fontSize: 13.sp),
            decoration: InputDecoration(
              hintText: 'search_surah'.tr,
              hintStyle: TextStyle(
                color: widget.textColor.withValues(alpha: 0.4),
                fontSize: 13.sp,
              ),
              prefixIcon: Icon(Icons.search, color: widget.accentColor, size: 18.r),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              filled: true,
              fillColor: widget.isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: widget.accentColor, width: 1.5),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _query = val;
              });
            },
          ),
        ),
        Container(
          constraints: BoxConstraints(maxHeight: 200.h),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
            ),
          ),
          child: filteredSurahIds.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Text(
                      'no_surahs_found'.tr,
                      style: widget.theme.textTheme.bodyMedium?.copyWith(
                        color: widget.textColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
                    shrinkWrap: true,
                    itemCount: filteredSurahIds.length,
                    separatorBuilder: (context, idx) => Divider(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      height: 1,
                    ),
                    itemBuilder: (context, idx) {
                      final surahId = filteredSurahIds[idx];
                      final surahName = widget.controller.currentLanguage.value == 'ar'
                          ? quran.getSurahNameArabic(surahId)
                          : quran.getSurahName(surahId);

                      return InkWell(
                        onTap: () async {
                          await Get.to(() => QuranAudioPage(
                                initialReciterKey: widget.info.reciter.key,
                                initialSurah: surahId,
                              ));
                          widget.onRefresh();
                        },
                        borderRadius: BorderRadius.circular(10.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
                          child: Row(
                            children: [
                              Container(
                                width: 26.r,
                                height: 26.r,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.accentColor.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: widget.accentColor.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$surahId',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: widget.accentColor,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  surahName,
                                  style: widget.theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: widget.controller.currentLanguage.value == 'ar'
                                        ? 'naskh'
                                        : null,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.play_circle_fill_rounded,
                                color: widget.accentColor,
                                size: 24.r,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
