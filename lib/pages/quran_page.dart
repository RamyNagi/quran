import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/quran_controller.dart';
import '../services/quran_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';

class QuranPage extends StatelessWidget {
  const QuranPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<QuranController>();
    final theme = Theme.of(context);
    final goldColor = theme.brightness == Brightness.dark
        ? const Color(0xFFD4AF37)
        : const Color(0xFFC5A059);

    return Scaffold(
      body: ArabesqueBackground(
        child: SafeArea(
          child: Obx(() {
            final selectedVerse = controller.selectedVerse.value;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 8.h),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book, color: goldColor, size: 28.r),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'quran'.tr,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: TextField(
                    onChanged: controller.updateSearch,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: goldColor),
                      hintText: 'search_quran'.tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Expanded(
                  child: controller.query.value.trim().isEmpty
                      ? Row(
                          children: [
                            SizedBox(
                              width: 132.w,
                              child: _SurahList(
                                controller: controller,
                                goldColor: goldColor,
                              ),
                            ),
                            Expanded(
                              child: _Reader(
                                controller: controller,
                                goldColor: goldColor,
                              ),
                            ),
                          ],
                        )
                      : _SearchResults(
                          controller: controller,
                          goldColor: goldColor,
                        ),
                ),
                if (selectedVerse != null)
                  _VerseToolbar(
                    verse: selectedVerse,
                    controller: controller,
                    goldColor: goldColor,
                  ),
              ],
            );
          }),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList({required this.controller, required this.goldColor});

  final QuranController controller;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ListView.builder(
        padding: EdgeInsets.only(left: 12.w, bottom: 100.h),
        itemCount: controller.surahs.length,
        itemBuilder: (context, index) {
          final surah = controller.surahs[index];
          final active = controller.selectedSurah.value == surah.number;
          return InkWell(
            onTap: () => controller.openSurah(surah.number),
            child: Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: active ? goldColor.withValues(alpha: 0.14) : null,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: active
                      ? goldColor
                      : goldColor.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${surah.number}. ${surah.nameArabic}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? goldColor : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    surah.nameEnglish,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Reader extends StatelessWidget {
  const _Reader({required this.controller, required this.goldColor});

  final QuranController controller;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ListView.builder(
        padding: EdgeInsets.fromLTRB(12.w, 0, 20.w, 100.h),
        itemCount: controller.verses.length,
        itemBuilder: (context, index) {
          final verse = controller.verses[index];
          final active = controller.selectedVerse.value?.id == verse.id;
          return _VerseCard(
            verse: verse,
            active: active,
            fontScale: controller.fontScale.value,
            goldColor: goldColor,
            onTap: () => controller.selectVerse(verse),
          );
        },
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.controller, required this.goldColor});

  final QuranController controller;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ListView.builder(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
        itemCount: controller.searchResults.length,
        itemBuilder: (context, index) {
          final verse = controller.searchResults[index];
          return _VerseCard(
            verse: verse,
            active: false,
            fontScale: controller.fontScale.value,
            goldColor: goldColor,
            onTap: () {
              controller.openSurah(verse.surah, initialVerse: verse.verse);
              controller.updateSearch('');
            },
          );
        },
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({
    required this.verse,
    required this.active,
    required this.fontScale,
    required this.goldColor,
    required this.onTap,
  });

  final QuranVerse verse;
  final bool active;
  final double fontScale;
  final Color goldColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: active
              ? goldColor.withValues(alpha: 0.10)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: active ? goldColor : goldColor.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${verse.surah}:${verse.verse} | ${'page'.tr} ${verse.page} | ${'juz'.tr} ${verse.juz}',
              style: theme.textTheme.bodySmall?.copyWith(color: goldColor),
            ),
            SizedBox(height: 10.h),
            Text(
              verse.text,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 24.sp * fontScale,
                height: 1.8,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              verse.translation,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            if (verse.isSajdah) ...[
              SizedBox(height: 8.h),
              Text('sajdah_verse'.tr, style: TextStyle(color: goldColor)),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerseToolbar extends StatelessWidget {
  const _VerseToolbar({
    required this.verse,
    required this.controller,
    required this.goldColor,
  });

  final QuranVerse verse;
  final QuranController controller;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: goldColor.withValues(alpha: 0.2))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'play_audio'.tr,
                onPressed: () => controller.playVerse(verse),
                icon: Icon(Icons.play_arrow, color: goldColor),
              ),
              IconButton(
                tooltip: 'favorite'.tr,
                onPressed: () => controller.toggleFavorite(verse),
                icon: Icon(
                  controller.isFavorite(verse)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: goldColor,
                ),
              ),
              IconButton(
                tooltip: 'bookmark'.tr,
                onPressed: () => controller.toggleBookmark(verse),
                icon: Icon(
                  controller.isBookmarked(verse)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: goldColor,
                ),
              ),
              IconButton(
                tooltip: 'tafsir'.tr,
                onPressed: () => controller.loadTafsir(verse),
                icon: Icon(Icons.article_outlined, color: goldColor),
              ),
              Expanded(
                child: Slider(
                  value: controller.fontScale.value,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  activeColor: goldColor,
                  onChanged: controller.setFontScale,
                ),
              ),
            ],
          ),
          Obx(() {
            if (controller.isLoadingTafsir.value) {
              return LinearProgressIndicator(color: goldColor);
            }
            if (controller.errorMessage.value.isNotEmpty) {
              return Text(
                controller.errorMessage.value,
                style: theme.textTheme.bodySmall?.copyWith(color: goldColor),
              );
            }
            if (controller.tafsir.value.isEmpty) return const SizedBox.shrink();
            return Text(
              controller.tafsir.value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            );
          }),
        ],
      ),
    );
  }
}
