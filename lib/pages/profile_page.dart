import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran;

import '../controllers/app_controller.dart';
import '../services/quran_service.dart';
import '../services/audio_download_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';
import 'quran_audio_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _DownloadedReciterInfo {
  _DownloadedReciterInfo({required this.reciter, required this.surahIds});
  final QuranReciterOption reciter;
  final List<int> surahIds;
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<List<_DownloadedReciterInfo>> _downloadsFuture;
  final Set<String> _expandedReciters = {};

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
    final controller = Get.find<AppController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = theme.colorScheme.secondary;
    final accentColor = isDark ? goldColor : theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white : Colors.black);

    return Scaffold(
      body: ArabesqueBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 40.h),
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, color: accentColor, size: 28.r),
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
                    color: accentColor.withValues(alpha: 0.12),
                    border: Border.all(color: accentColor, width: 2),
                  ),
                  child: Icon(Icons.person, color: accentColor, size: 58.r),
                ),
              ),
              SizedBox(height: 14.h),
              Obx(
                () => Text(
                  controller.userName.value,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 36.h),
              Text(
                'settings'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accentColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Obx(
                () => _SettingsCard(
                  icon: Icons.badge_outlined,
                  title: 'name_label'.tr,
                  subtitle: controller.userName.value,
                  goldColor: goldColor,
                  onTap: () => _showEditNameSheet(context, controller),
                  trailing: Text(
                    'edit'.tr,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Obx(
                () {
                  // Read currentLanguage to register reactive dependency and trigger rebuilds
                  final _ = controller.currentLanguage.value;
                  return _SettingsCard(
                    icon: Icons.language,
                    title: 'language'.tr,
                    subtitle: 'current_language_label'.tr,
                    goldColor: goldColor,
                    onTap: () => _showLanguageDialog(context, controller),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16.r,
                      color: accentColor,
                    ),
                  );
                },
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
                    activeColor: accentColor,
                    onChanged: (_) => controller.toggleTheme(),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'audio_downloads_manager'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accentColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
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
                    return Container(
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isDark
                              ? goldColor.withValues(alpha: 0.1)
                              : theme.colorScheme.primary.withValues(alpha: 0.08),
                        ),
                      ),
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
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.green,
                                              size: 18.r,
                                            ),
                                            SizedBox(width: 8.w),
                                            Text(
                                              'full_quran_downloaded'.tr,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
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
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 5),
    );
  }
}

void _showEditNameSheet(BuildContext context, AppController controller) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final goldColor = theme.colorScheme.secondary;
  final accentColor = isDark ? goldColor : theme.colorScheme.primary;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _EditNameSheetContent(
        controller: controller,
        accentColor: accentColor,
      );
    },
  );
}

void _showLanguageDialog(BuildContext context, AppController controller) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final goldColor = theme.colorScheme.secondary;
  final accentColor = isDark ? goldColor : theme.colorScheme.primary;

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final dialogBg = isDark ? const Color(0xFF0D1512) : theme.colorScheme.surface;
      return Dialog(
        backgroundColor: dialogBg,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.r),
          side: BorderSide(
            color: isDark
                ? goldColor.withValues(alpha: 0.3)
                : theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 26.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: isDark ? 0.15 : 0.12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(
                  Icons.translate,
                  color: accentColor,
                  size: 32.r,
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'select_language'.tr,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp,
                  color: isDark ? Colors.white : theme.textTheme.titleLarge?.color,
                ),
              ),
              SizedBox(height: 20.h),
              Obx(() {
                final isArabic = controller.currentLanguage.value == 'ar';
                final bg = isArabic
                    ? accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
                    : Colors.transparent;
                final borderCol = isArabic
                    ? accentColor
                    : (isDark ? goldColor.withValues(alpha: 0.15) : theme.colorScheme.onSurface.withValues(alpha: 0.08));
                
                return InkWell(
                  onTap: () {
                    if (!isArabic) {
                      controller.toggleLanguage();
                    }
                    Navigator.pop(dialogContext);
                  },
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: borderCol, width: isArabic ? 2.0 : 1.0),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: isArabic ? accentColor : (isDark ? Colors.white30 : theme.disabledColor.withValues(alpha: 0.4)),
                          size: 24.r,
                        ),
                        SizedBox(width: 14.w),
                        Text(
                          'arabic'.tr,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isArabic ? FontWeight.bold : FontWeight.w500,
                            color: isArabic ? accentColor : (isDark ? Colors.white70 : theme.textTheme.bodyLarge?.color),
                            fontSize: 16.sp,
                          ),
                        ),
                        const Spacer(),
                        if (isArabic)
                          Icon(
                            Icons.check,
                            color: accentColor,
                            size: 20.r,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(height: 12.h),
              Obx(() {
                final isEnglish = controller.currentLanguage.value == 'en';
                final bg = isEnglish
                    ? accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
                    : Colors.transparent;
                final borderCol = isEnglish
                    ? accentColor
                    : (isDark ? goldColor.withValues(alpha: 0.15) : theme.colorScheme.onSurface.withValues(alpha: 0.08));
                
                return InkWell(
                  onTap: () {
                    if (!isEnglish) {
                      controller.toggleLanguage();
                    }
                    Navigator.pop(dialogContext);
                  },
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: borderCol, width: isEnglish ? 2.0 : 1.0),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: isEnglish ? accentColor : (isDark ? Colors.white30 : theme.disabledColor.withValues(alpha: 0.4)),
                          size: 24.r,
                        ),
                        SizedBox(width: 14.w),
                        Text(
                          'english'.tr,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isEnglish ? FontWeight.bold : FontWeight.w500,
                            color: isEnglish ? accentColor : (isDark ? Colors.white70 : theme.textTheme.bodyLarge?.color),
                            fontSize: 16.sp,
                          ),
                        ),
                        const Spacer(),
                        if (isEnglish)
                          Icon(
                            Icons.check,
                            color: accentColor,
                            size: 20.r,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}

class _EditNameSheetContent extends StatefulWidget {
  const _EditNameSheetContent({
    required this.controller,
    required this.accentColor,
  });

  final AppController controller;
  final Color accentColor;

  @override
  State<_EditNameSheetContent> createState() => _EditNameSheetContentState();
}

class _EditNameSheetContentState extends State<_EditNameSheetContent> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.userName.value);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20.w,
            18.h,
            20.w,
            MediaQuery.viewInsetsOf(context).bottom + 22.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تعديل الاسم',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) async {
                  final navigator = Navigator.of(context);
                  await widget.controller.setUserName(_nameController.text);
                  navigator.pop();
                },
                decoration: InputDecoration(
                  labelText: 'اسمك',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: widget.accentColor),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await widget.controller.setUserName(_nameController.text);
                  navigator.pop();
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
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

class _DownloadedSurahsList extends StatefulWidget {
  final _DownloadedReciterInfo info;
  final bool isDark;
  final Color accentColor;
  final Color textColor;
  final ThemeData theme;
  final AppController controller;
  final VoidCallback onRefresh;

  const _DownloadedSurahsList({
    required this.info,
    required this.isDark,
    required this.accentColor,
    required this.textColor,
    required this.theme,
    required this.controller,
    required this.onRefresh,
  });

  @override
  State<_DownloadedSurahsList> createState() => _DownloadedSurahsListState();
}

class _DownloadedSurahsListState extends State<_DownloadedSurahsList> {
  final ScrollController _scrollController = ScrollController();
  String _query = '';

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '') // remove diacritics
        .replaceAll('أ', 'a')
        .replaceAll('إ', 'a')
        .replaceAll('آ', 'a')
        .replaceAll('ى', 'y')
        .replaceAll('ة', 'h');
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
