import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/fatawa_controller.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fatawa Main Search Page (Stateless with GetX)
// ─────────────────────────────────────────────────────────────────────────────

class FatawaPage extends StatelessWidget {
  const FatawaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FatawaController>();
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? goldColor : theme.colorScheme.primary;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ArabesqueBackground(
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.question_answer, color: accentColor, size: 28.r),
                            SizedBox(width: 12.w),
                            Text(
                              'fatwa'.tr,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'fatwa_source_note'.tr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Field
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                    child: Obx(() => TextField(
                      enabled: !controller.isServiceStopped.value,
                      controller: controller.searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: controller.performSearch,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'fatwa_search_hint'.tr,
                        hintStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                        filled: true,
                        fillColor: theme.cardTheme.color,
                        prefixIcon: IconButton(
                          onPressed: controller.isServiceStopped.value
                              ? null
                              : () => controller.performSearch(controller.searchController.text),
                          icon: Icon(Icons.search, color: controller.isServiceStopped.value ? Colors.grey : goldColor),
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller.searchController,
                          builder: (context, value, _) {
                            return value.text.isEmpty
                                ? const SizedBox.shrink()
                                : IconButton(
                                    onPressed: () {
                                      controller.searchController.clear();
                                    },
                                    icon: const Icon(Icons.close),
                                    color: goldColor,
                                  );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18.r),
                          borderSide: BorderSide(
                            color: goldColor.withValues(alpha: 0.18),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18.r),
                          borderSide: BorderSide(
                            color: goldColor.withValues(alpha: 0.18),
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18.r),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18.r),
                          borderSide: BorderSide(
                            color: goldColor,
                            width: 1.4,
                          ),
                        ),
                      ),
                    )),
                  ),

                  SizedBox(height: 16.h),

                  // Results list / State switcher (Reactive)
                  Expanded(
                    child: Obx(() {
                      if (controller.isServiceStopped.value) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.r),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.construction_rounded, color: goldColor, size: 54.r),
                                SizedBox(height: 16.h),
                                Text(
                                  'fatwa_service_stopped'.tr,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'يرجى تحديث التطبيق لاحقاً أو المحاولة في وقت آخر.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (controller.isLoading.value) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: goldColor),
                              SizedBox(height: 16.h),
                              Text(
                                'fatwa_loading'.tr,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (controller.errorMessage.value.isNotEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Center(
                            child: Text(
                              controller.errorMessage.value,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        );
                      }

                      if (controller.query.value.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      if (controller.results.isEmpty) {
                        return ListView(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          children: [
                            _EmptySearch(goldColor: goldColor),
                          ],
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
                        physics: const BouncingScrollPhysics(),
                        itemCount: controller.results.length,
                        separatorBuilder: (_, _) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final item = controller.results[index];
                          return _FatwaCard(
                            result: item,
                            goldColor: goldColor,
                            index: index + 1,
                            onTap: () {
                              Get.to(() => _FatwaDetailsPage(
                                    title: item.title,
                                    url: item.url,
                                    goldColor: goldColor,
                                  ));
                            },
                          );
                        },
                      );
                    }),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.8),
                      border: Border(
                        top: BorderSide(
                          color: goldColor.withValues(alpha: 0.15),
                          width: 1.h,
                        ),
                      ),
                    ),
                    child: Text(
                      'fatwa_disclaimer'.tr,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 11.sp,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const AppBottomNav(currentIndex: 4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fatwa Result Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _FatwaCard extends StatelessWidget {
  const _FatwaCard({
    required this.result,
    required this.goldColor,
    required this.index,
    required this.onTap,
  });

  final FatwaResult result;
  final Color goldColor;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.16)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28.r,
                    height: 28.r,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: goldColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      '$index',
                      style: TextStyle(
                        color: goldColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14.r,
                    color: goldColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
              if (result.snippet.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Text(
                  result.snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.45,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty Search Placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.goldColor});

  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(Icons.manage_search, color: goldColor, size: 42.r),
          SizedBox(height: 10.h),
          Text(
            'fatwa_no_results'.tr,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'fatwa_no_results_desc'.tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fatwa Details Screen (Failsafe Scraper calling FatawaController)
// ─────────────────────────────────────────────────────────────────────────────

class _FatwaDetailsPage extends StatefulWidget {
  const _FatwaDetailsPage({
    required this.title,
    required this.url,
    required this.goldColor,
  });

  final String title;
  final String url;
  final Color goldColor;

  @override
  State<_FatwaDetailsPage> createState() => _FatwaDetailsPageState();
}

class _FatwaDetailsPageState extends State<_FatwaDetailsPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  String _question = '';
  String _answer = '';
  double _fontSize = 17.0;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final controller = Get.find<FatawaController>();
      final data = await controller.fetchFatwaDetails(widget.url, widget.title);

      if (mounted) {
        setState(() {
          _question = data['question'] ?? '';
          _answer = data['answer'] ?? '';
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'sunnah_timeout_error'.tr;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'sunnah_download_error'.tr;
        });
      }
    }
  }  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: false,
        ),
        body: ArabesqueBackground(
          child: SafeArea(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: widget.goldColor),
                  )
                : _errorMessage.isNotEmpty
                    ? Padding(
                        padding: EdgeInsets.all(24.r),
                        child: Center(
                          child: Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Font Size Slider
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color?.withValues(alpha: 0.7),
                              border: Border(
                                bottom: BorderSide(
                                  color: widget.goldColor.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.format_size, size: 18.r, color: widget.goldColor),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: widget.goldColor,
                                      thumbColor: widget.goldColor,
                                      inactiveTrackColor: widget.goldColor.withValues(alpha: 0.2),
                                    ),
                                    child: Slider(
                                      value: _fontSize,
                                      min: 14.0,
                                      max: 26.0,
                                      divisions: 6,
                                      onChanged: (val) {
                                        setState(() {
                                          _fontSize = val;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_fontSize.toInt()}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: widget.goldColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Scrollable QA Content
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.all(20.r),
                              physics: const BouncingScrollPhysics(),
                              children: [
                                // Question Box
                                Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'fatwa_question'.tr,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        _question,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontSize: (_fontSize - 2).sp,
                                          height: 1.6,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 20.h),

                                // Answer Box
                                Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: theme.cardTheme.color,
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: widget.goldColor.withValues(alpha: 0.16),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'fatwa_answer'.tr,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: widget.goldColor,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        _answer,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontSize: _fontSize.sp,
                                          height: 1.85,
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final uri = Uri.parse(widget.url);
                                    try {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } catch (_) {}
                                  },
                                  icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white),
                                  label: Text(
                                    'عرض الفتوى في المصدر الأصلي',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.goldColor,
                                    padding: EdgeInsets.symmetric(vertical: 14.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                                SizedBox(height: 30.h),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      ),
    );
  }
}
