// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran_text;
import 'package:quran_library/quran_library.dart';

import '../controllers/app_controller.dart';
import '../services/audio_service.dart';
import '../services/quran_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'quran_memorization_page.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  static const _goldColor = Color(0xFFD4AF37);

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  late final QuranService _quranService;
  late final AppController _appController;
  // البارات ظاهرة افتراضياً عند فتح الصفحة
  bool _isToolbarVisible = true;

  // وضع الليل - يُحدَّث عبر ever() + setState لتجنب Obx حول QuranLibraryScreen
  bool _isNight = false;

  // وضعية القراءة فقط أو الاستماع مع القراءة
  final RxBool _isListenAndReadMode = false.obs;
  StreamSubscription? _audioIndexSubscription;
  StreamSubscription? _audioStateSubscription;

  // لتتبع الصفحة الحالية والصفحة المحفوظة لتلوين علامة الحفظ
  final RxInt _currentPage = 1.obs;
  final RxInt _savedMarkPage = 0.obs;

  @override
  void initState() {
    super.initState();
    _quranService = Get.find<QuranService>();
    _appController = Get.find<AppController>();
    // قراءة الوضع الحالي مرة واحدة + الاشتراك في التغييرات بدون Obx
    _isNight = _appController.isNightMode.value;
    ever(_appController.isNightMode, (val) {
      if (mounted) setState(() => _isNight = val);
    });
    // إظهار الـ Bottom Nav Bar عند دخول صفحة القرآن
    _appController.setNavBarVisible(true);

    // تهيئة الصفحة الحالية والصفحة المحفوظة
    try {
      final lastRead = _quranService.getLastRead();
      _currentPage.value = lastRead.page;
      final savedMark = _quranService.getReadingMark();
      _savedMarkPage.value = savedMark?.page ?? 0;
    } catch (_) {}

    // تعيين خط حفص العثماني المدمج (0) فوراً بشكل متزامن قبل بدء البناء لمنع الانهيار
    try {
      final quranCtrl = QuranCtrl.instance;
      quranCtrl.state.fontsSelected.value = 0;
    } catch (e) {
      log('Error forcing default font in initState: $e');
    }

    final audioService = Get.find<QuranAudioService>();
    _audioIndexSubscription = audioService.currentIndexStream.listen((index) {
      if (index == null || !audioService.isPlaying.value) return;
      if (_isListenAndReadMode.value) {
        final verses = audioService.playingVerses;
        if (index >= 0 && index < verses.length) {
          final currentVerse = verses[index];
          try {
            final page = currentVerse.page;
            if (QuranLibrary().currentPageNumber != page) {
              QuranLibrary().jumpToPage(page);
            }
          } catch (e) {
            log('Error auto-scrolling to page: $e');
          }
          try {
            final quranCtrl = QuranCtrl.instance;
            final uq = getAyahUQNumber(currentVerse.surah, currentVerse.verse);
            quranCtrl.selectedAyahsByUnequeNumber.clear();
            quranCtrl.selectedAyahsByUnequeNumber.add(uq);
            quranCtrl.selectedAyahsByUnequeNumber.refresh();
          } catch (e) {
            log('Error highlighting active verse: $e');
          }
        }
      }
    });

    _audioStateSubscription = audioService.playerStateStream.listen((state) {
      final processing = state.processingState;
      final playing = state.playing;
      if (!playing || processing == ProcessingState.completed || processing == ProcessingState.idle) {
        if (_isListenAndReadMode.value) {
          try {
            QuranCtrl.instance.selectedAyahsByUnequeNumber.clear();
            QuranCtrl.instance.selectedAyahsByUnequeNumber.refresh();
          } catch (_) {}
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lastRead = _quranService.getLastRead();
      QuranLibrary().jumpToPage(lastRead.page);

      // التأكيد على حفظ الإعداد الافتراضي
      try {
        final quranCtrl = QuranCtrl.instance;
        if (quranCtrl.state.fontsSelected.value != 0) {
          await quranCtrl.switchFontType(fontIndex: 0);
        }
      } catch (e) {
        log('Error forcing default Hafs font: $e');
      }
    });
  }

  @override
  void dispose() {
    _audioIndexSubscription?.cancel();
    _audioStateSubscription?.cancel();
    // إظهار الـ Bottom Nav Bar عند الخروج من صفحة القرآن
    _appController.setNavBarVisible(true);
    super.dispose();
  }

  void _setListenAndReadMode(bool active) {
    _isListenAndReadMode.value = active;
    try {
      final quranCtrl = QuranCtrl.instance;
      quranCtrl.selectedAyahsByUnequeNumber.clear();
      quranCtrl.selectedAyahsByUnequeNumber.refresh();

      if (active) {
        final audioService = Get.find<QuranAudioService>();
        if (audioService.isPlaying.value && audioService.playingVerses.isNotEmpty) {
          final index = audioService.currentIndex;
          if (index != null && index >= 0 && index < audioService.playingVerses.length) {
            final currentVerse = audioService.playingVerses[index];
            try {
              final page = currentVerse.page;
              if (QuranLibrary().currentPageNumber != page) {
                QuranLibrary().jumpToPage(page);
              }
            } catch (_) {}
            final uq = getAyahUQNumber(currentVerse.surah, currentVerse.verse);
            quranCtrl.selectedAyahsByUnequeNumber.add(uq);
            quranCtrl.selectedAyahsByUnequeNumber.refresh();
          }
        }
      }
    } catch (e) {
      log('Error switching listen and read mode: $e');
    }
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color goldColor,
    required Color inactiveColor,
    bool active = false,
  }) {
    final Color itemColor = active ? goldColor : inactiveColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: itemColor, size: 24.r),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5.sp,
                fontWeight: FontWeight.bold,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _isNight ? AppTheme.backgroundNight : AppTheme.backgroundLight;
    final Color textColor = _isNight ? AppTheme.textNight : AppTheme.textLight;
    final Color goldColor = _isNight ? AppTheme.goldNight : AppTheme.goldLight;
    final Color inactiveColor = _isNight
        ? Colors.white.withOpacity(0.4)
        : Colors.black.withOpacity(0.4);
    final audioService = Get.find<QuranAudioService>();

    return Theme(
      data: ThemeData(
        useMaterial3: false,
        brightness: _isNight ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: bgColor,
        colorScheme: _isNight
            ? const ColorScheme.dark(
                primary: AppTheme.goldNight,
                secondary: AppTheme.goldNight,
                surface: AppTheme.surfaceNight,
                onPrimary: Colors.black,
                onSecondary: Colors.black,
                onSurface: AppTheme.textNight,
              )
            : const ColorScheme.light(
                primary: AppTheme.goldLight,
                secondary: AppTheme.goldLight,
                surface: AppTheme.surfaceLight,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: AppTheme.textLight,
              ),
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, _) {
          if (!_isToolbarVisible) {
            _showBars();
          } else {
            _appController.navigateToPage(0);
          }
        },
        child: Scaffold(
          backgroundColor: bgColor,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _toggleBars,
            child: Stack(
              children: [
                // ── المصحف: بدون أي Obx حوله تمامًا ──
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: _isToolbarVisible ? 74.h : 0,
                    ),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: const TextScaler.linear(1.28),
                      ),
                      child: QuranLibraryScreen(
                        isDark: _isNight,
                        languageCode: Get.locale?.languageCode ?? 'ar',
                        backgroundColor: bgColor,
                        textColor: textColor,
                        ayahIconColor: goldColor,
                        ayahSelectedBackgroundColor: _isListenAndReadMode.value
                            ? Colors.red.withValues(alpha: 0.18)
                            : goldColor.withValues(alpha: 0.22),
                        ayahSelectedFontColor:
                            _isListenAndReadMode.value ? Colors.red : textColor,
                        bookmarksColor: goldColor,
                        withPageView: true,
                        optimizeScrolling: false,
                        useDefaultAppBar: false,
                        showAyahBookmarkedIcon: true,
                        downloadFontsDialogStyle: DownloadFontsDialogStyle(
                          iconWidget: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {},
                            child: const SizedBox(width: 100, height: 100),
                          ),
                          linearProgressColor: Colors.transparent,
                          linearProgressBackgroundColor: Colors.transparent,
                        ),
                        onPageChanged: (pageIndex) {
                          _currentPage.value = pageIndex + 1;
                          _quranService.saveLastReadPage(pageIndex + 1);
                        },
                        onPagePress: () {},
                        onAyahLongPress: (_, ayah) =>
                            _showAyahMoreOptions(context: context, ayah: ayah),
                        anotherMenuChild: const Icon(
                          Icons.more_horiz,
                          color: Colors.grey,
                        ),
                        anotherMenuChildOnTap: (ayah) =>
                            _showAyahMoreOptions(context: context, ayah: ayah),
                      ),
                    ),
                  ),
                ),

                // ── شريط الأدوات العلوي ──
                if (_isToolbarVisible)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: bgColor,
                      child: SafeArea(
                        bottom: false,
                        child: SizedBox(
                          height: 74.h,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Obx(() => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 8.w),
                                _buildAppBarAction(
                                  icon: Icons.menu_book_rounded,
                                  label: 'quran_read_only'.tr,
                                  active: !_isListenAndReadMode.value,
                                  goldColor: goldColor,
                                  inactiveColor: inactiveColor,
                                  onTap: () => _setListenAndReadMode(false),
                                ),
                                if (!_isListenAndReadMode.value) ...[
                                  _buildAppBarAction(
                                    icon: Icons.bookmark_add_rounded,
                                    label: 'quran_save_mark'.tr,
                                    active: false,
                                    goldColor: goldColor,
                                    inactiveColor: inactiveColor,
                                    onTap: () =>
                                        _saveCurrentReadingMark(context),
                                  ),
                                  _buildAppBarAction(
                                    icon: Icons.flag_rounded,
                                    label: 'quran_go_to_mark'.tr,
                                    active: false,
                                    goldColor: goldColor,
                                    inactiveColor: inactiveColor,
                                    onTap: () => _goToReadingMark(context),
                                  ),
                                ],
                                _buildAppBarAction(
                                  icon: Icons.hearing_rounded,
                                  label: 'quran_listen_read'.tr,
                                  active: _isListenAndReadMode.value,
                                  goldColor: goldColor,
                                  inactiveColor: inactiveColor,
                                  onTap: () => _setListenAndReadMode(true),
                                ),
                                Obx(() => _buildAppBarAction(
                                  icon: Icons.volume_up_rounded,
                                  label: 'quran_audio'.tr,
                                  active: audioService.isPlaying.value,
                                  goldColor: goldColor,
                                  inactiveColor: inactiveColor,
                                  onTap: () => _showQuranAudioSheet(
                                      context, _currentPage.value),
                                )),
                                _buildAppBarAction(
                                  icon: Icons.psychology_rounded,
                                  label: 'quran_memorize'.tr,
                                  active: false,
                                  goldColor: goldColor,
                                  inactiveColor: inactiveColor,
                                  onTap: () => _showQuranMemorizationSheet(
                                      context, _currentPage.value),
                                ),
                                SizedBox(width: 8.w),
                              ],
                            )),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── أيقونة العلامة المحفوظة ──
                // Positioned يجب أن يكون دائمًا direct child للـ Stack
                // Obx يتحكم فقط في المحتوى الداخلي (أيقونة أو فراغ)
                Positioned(
                  top: _isToolbarVisible ? 84.h : 20.h,
                  right: 20.w,
                  child: Obx(() {
                    if (_savedMarkPage.value > 0 &&
                        _currentPage.value == _savedMarkPage.value) {
                      return Icon(
                        Icons.bookmark_rounded,
                        color: goldColor,
                        size: 38.r,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 4.r,
                            offset: Offset(0, 2.h),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ),

                // ── شريط التنقل السفلي ──
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AppBottomNav(currentIndex: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ضغطة واحدة: تبديل إظهار/إخفاء كل البارات
  void _toggleBars() {
    if (_isToolbarVisible) {
      _hideBars();
    } else {
      _showBars();
    }
  }

  void _showBars() {
    if (mounted) {
      setState(() => _isToolbarVisible = true);
    }
    _appController.setNavBarVisible(true);
  }

  void _hideBars() {
    if (mounted) {
      setState(() => _isToolbarVisible = false);
    }
    _appController.setNavBarVisible(false);
  }

  Future<void> _saveCurrentReadingMark(BuildContext context) async {
    final page = _currentPage.value;
    await _quranService.saveReadingMarkPage(page);
    await _quranService.saveLastReadPage(page);
    _savedMarkPage.value = page;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ العلامة في الموضع الحالي')),
    );
  }

  void _goToReadingMark(BuildContext context) {
    final savedMark = _quranService.getReadingMark();
    if (savedMark != null) {
      QuranLibrary().jumpToPage(savedMark.page);
      _quranService.saveLastRead(savedMark.surah, savedMark.verse);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الانتقال للعلامة المحفوظة: صفحة ${savedMark.page}'),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم تقم بحفظ أي علامة بعد. اضغط على "حفظ علامة" لحفظ الصفحة الحالية.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}


void _showQuranMemorizationSheet(BuildContext context, int currentPage) {
  final quranService = Get.find<QuranService>();
  final initialPageVerses = quranService.getPageVerses(currentPage);
  final initialVerse = initialPageVerses.isEmpty
      ? quranService.getLastRead()
      : initialPageVerses.first;
  var selectedSurah = initialVerse.surah;
  var selectedVerse = initialVerse.verse;
  var selectedEndVerse = initialPageVerses
      .where((verse) => verse.surah == selectedSurah)
      .map((verse) => verse.verse)
      .fold<int>(
        initialVerse.verse,
        (previous, verse) => verse > previous ? verse : previous,
      );

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final verseCount = quran_text.getVerseCount(selectedSurah);
          selectedVerse = selectedVerse.clamp(1, verseCount).toInt();
          selectedEndVerse = selectedEndVerse
              .clamp(selectedVerse, verseCount)
              .toInt();

          return SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18.w,
                  14.h,
                  18.w,
                  MediaQuery.viewInsetsOf(context).bottom + 22.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          color: QuranPage._goldColor,
                          size: 24.r,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'مساعد الحفظ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    _QuranRangeDropdown<int>(
                      value: selectedSurah,
                      label: 'السورة',
                      items: List.generate(quran_text.totalSurahCount, (index) {
                        final surah = index + 1;
                        return DropdownMenuItem<int>(
                          value: surah,
                          child: Text(
                            '$surah. ${quran_text.getSurahNameArabic(surah)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedSurah = value;
                          selectedVerse = 1;
                          selectedEndVerse = quran_text.getVerseCount(value);
                        });
                      },
                    ),
                    SizedBox(height: 12.h),
                    _QuranRangeDropdown<int>(
                      value: selectedVerse,
                      label: 'بداية الحفظ',
                      items: List.generate(verseCount, (index) {
                        final verse = index + 1;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedVerse = value;
                          if (selectedEndVerse < value) {
                            selectedEndVerse = value;
                          }
                        });
                      },
                    ),
                    SizedBox(height: 12.h),
                    _QuranRangeDropdown<int>(
                      value: selectedEndVerse,
                      label: 'نهاية الحفظ',
                      items: List.generate(verseCount - selectedVerse + 1, (
                        index,
                      ) {
                        final verse = selectedVerse + index;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedEndVerse = value);
                      },
                    ),
                    SizedBox(height: 16.h),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: QuranPage._goldColor,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => QuranMemorizationPage(
                              initialSurah: selectedSurah,
                              initialStartVerse: selectedVerse,
                              initialEndVerse: selectedEndVerse,
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.play_arrow_rounded, size: 24.r),
                      label: Text(
                        'بدء الحفظ',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'سيتم إخفاء الكلمات ثم إظهارها تدريجياً أثناء التلاوة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

void _showQuranAudioSheet(BuildContext context, int currentPageVal) {
  final quranService = Get.find<QuranService>();
  final audioService = Get.find<QuranAudioService>();
  final initialPageVerses = quranService.getPageVerses(currentPageVal);
  final initialVerse = initialPageVerses.isEmpty
      ? quranService.getLastRead()
      : initialPageVerses.first;
  var selectedReciterKey = quranService.getSelectedReciter().key;
  var selectedSurah = initialVerse.surah;
  var selectedVerse = initialVerse.verse;
  var selectedEndVerse = quran_text.getVerseCount(initialVerse.surah);
  var isLoading = false;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final verseCount = quran_text.getVerseCount(selectedSurah);
          if (selectedVerse > verseCount) {
            selectedVerse = verseCount;
          }
          if (selectedEndVerse > verseCount) {
            selectedEndVerse = verseCount;
          }
          if (selectedEndVerse < selectedVerse) {
            selectedEndVerse = selectedVerse;
          }
          final versesToPlay = quranService.getSurahVersesRange(
            selectedSurah,
            selectedVerse,
            selectedEndVerse,
          );
          final firstVerse = versesToPlay.isEmpty ? null : versesToPlay.first;
          final lastVerse = versesToPlay.isEmpty ? null : versesToPlay.last;

          Future<void> playSelectedVerses() async {
            setSheetState(() => isLoading = true);
            try {
              final urls = versesToPlay
                  .map((verse) => verse.audioUrl)
                  .where((url) => url.trim().isNotEmpty)
                  .toList();
              await audioService.playPlaylist(urls);
            } catch (_) {
              Get.snackbar(
                'الصوت',
                'تعذر تشغيل التلاوة. تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.',
                backgroundColor: Colors.red.shade900,
                colorText: Colors.white,
              );
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => isLoading = false);
              }
            }
          }

          return SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18.w,
                  14.h,
                  18.w,
                  MediaQuery.viewInsetsOf(context).bottom + 22.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.volume_up_rounded,
                          color: QuranPage._goldColor,
                          size: 24.r,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'تشغيل التلاوة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    DropdownButtonFormField<String>(
                      value: selectedReciterKey,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'القارئ',
                        labelStyle: TextStyle(color: Colors.white70, fontSize: 14.sp),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      items: QuranService.reciters
                          .map(
                            (reciter) => DropdownMenuItem<String>(
                              value: reciter.key,
                              child: Text(reciter.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        setSheetState(() => selectedReciterKey = value);
                        await quranService.setSelectedReciter(value);
                        if (sheetContext.mounted) setSheetState(() {});
                      },
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<int>(
                      value: selectedSurah,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'السورة',
                        labelStyle: TextStyle(color: Colors.white70, fontSize: 14.sp),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      items: List.generate(quran_text.totalSurahCount, (index) {
                        final surah = index + 1;
                        return DropdownMenuItem<int>(
                          value: surah,
                          child: Text(
                            '$surah. ${quran_text.getSurahNameArabic(surah)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedSurah = value;
                          selectedVerse = 1;
                          selectedEndVerse = quran_text.getVerseCount(value);
                        });
                      },
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<int>(
                      value: selectedVerse,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'بدء التشغيل من الآية',
                        labelStyle: TextStyle(color: Colors.white70, fontSize: 14.sp),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      items: List.generate(verseCount, (index) {
                        final verse = index + 1;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedVerse = value;
                          if (selectedEndVerse < value) {
                            selectedEndVerse = value;
                          }
                        });
                      },
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<int>(
                      value: selectedEndVerse,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'انتهاء التشغيل عند الآية',
                        labelStyle: TextStyle(color: Colors.white70, fontSize: 14.sp),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      items: List.generate(verseCount - selectedVerse + 1, (
                        index,
                      ) {
                        final verse = selectedVerse + index;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedEndVerse = value);
                      },
                    ),
                    SizedBox(height: 14.h),
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'الصفحة الحالية: $currentPageVal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (firstVerse != null && lastVerse != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              'سيتم التشغيل من ${quran_text.getSurahNameArabic(firstVerse.surah)} '
                              'آية ${firstVerse.verse} إلى آية ${lastVerse.verse}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14.sp,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    StreamBuilder(
                      stream: audioService.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying =
                            snapshot.data?.playing ?? audioService.isPlaying.value;

                        return Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: QuranPage._goldColor,
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 13.h,
                                  ),
                                ),
                                onPressed: isLoading
                                    ? null
                                    : playSelectedVerses,
                                icon: isLoading
                                    ? SizedBox(
                                        width: 18.w,
                                        height: 18.h,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Icon(
                                        isPlaying
                                            ? Icons.replay_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 24.r,
                                      ),
                                label: Text(
                                  isPlaying
                                      ? 'إعادة التشغيل'
                                      : 'تشغيل النطاق المحدد',
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white12,
                                foregroundColor: Colors.white,
                                fixedSize: Size(48.w, 48.h),
                              ),
                              onPressed: () => audioService.stop(),
                              icon: Icon(Icons.stop_rounded, size: 24.r),
                              tooltip: 'إيقاف',
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'سيتم تشغيل الآيات المختارة بالتتابع حسب القارئ المحدد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

void _showAyahMoreOptions({
  required BuildContext context,
  required AyahModel ayah,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'خيارات الآية',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _QuranOptionTile(
                icon: Icons.menu_book,
                title: 'عرض التفسير',
                subtitle: 'فتح التفسير المحدد للآية',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAyahTafsir(context, ayah);
                },
              ),
              _QuranOptionTile(
                icon: Icons.download_for_offline_outlined,
                title: 'تحميل أو اختيار تفسير',
                subtitle: 'اختر من التفاسير والترجمات المتاحة',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showTafsirDownloads(context, ayah);
                },
              ),
              _QuranOptionTile(
                icon: Icons.translate,
                title: 'معنى الآية بالعربية',
                subtitle: 'عرض معنى مبسط للآية باللغة العربية',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showArabicMeaning(context, ayah);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showAyahTafsir(BuildContext context, AyahModel ayah) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.82,
          child: FutureBuilder<String>(
            future: _loadSelectedTafsirText(ayah),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: QuranPage._goldColor),
                );
              }

              final hasError = snapshot.hasError;
              final tafsirText = snapshot.data?.trim() ?? '';

              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'تفسير الآية',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ayah.text,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.8,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 28),
                    Expanded(
                      child: hasError || tafsirText.isEmpty
                          ? _TafsirEmptyState(
                              ayah: ayah,
                              error: hasError ? '${snapshot.error}' : null,
                            )
                          : SingleChildScrollView(
                              child: Text(
                                tafsirText,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.75,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<String> _loadSelectedTafsirText(AyahModel ayah) async {
  final appTafsirText = await _loadAppTafsirText(ayah);
  if (appTafsirText.trim().isNotEmpty) {
    return appTafsirText;
  }

  final quran = QuranLibrary();
  await quran.initTafsir();

  var selectedIndex = quran.tafsirSelected;
  if (selectedIndex > 4) {
    selectedIndex = 3;
  }

  final selectedText = await _tryLoadTafsirByIndex(quran, ayah, selectedIndex);
  if (selectedText.trim().isNotEmpty) {
    return selectedText;
  }

  if (selectedIndex != 3) {
    final fallbackText = await _tryLoadTafsirByIndex(quran, ayah, 3);
    if (fallbackText.trim().isNotEmpty) return fallbackText;
  }

  return '';
}

Future<String> _loadAppTafsirText(AyahModel ayah) async {
  try {
    final quranService = Get.find<QuranService>();
    final surah = ayah.surahNumber ?? _surahNumberFromGlobalAyah(ayah);
    if (surah <= 0) return '';

    final tafsir = await quranService.getTafsir(surah, ayah.ayahNumber);
    log(
      'Loaded app tafsir length=${tafsir.length} surah=$surah ayah=${ayah.ayahNumber}',
      name: 'HayahQuran',
    );
    return _cleanTafsirText(tafsir);
  } catch (error) {
    log('App tafsir failed: $error', name: 'HayahQuran');
    return '';
  }
}

int _surahNumberFromGlobalAyah(AyahModel ayah) {
  var cursor = 0;
  for (var surah = 1; surah <= quran_text.totalSurahCount; surah++) {
    cursor += quran_text.getVerseCount(surah);
    if (ayah.ayahUQNumber <= cursor) return surah;
  }
  return ayah.surahNumber ?? 0;
}

Future<String> _tryLoadTafsirByIndex(
  QuranLibrary quran,
  AyahModel ayah,
  int tafsirIndex,
) async {
  try {
    if (!quran.getTafsirDownloaded(tafsirIndex) && tafsirIndex != 3) {
      await quran.tafsirDownload(tafsirIndex);
    }

    quran.changeTafsirSwitch(tafsirIndex, pageNumber: ayah.page);
    await quran.closeAndInitializeDatabase(pageNumber: ayah.page);

    final result = await quran.getTafsirOfAyah(
      ayahUniqNumber: ayah.ayahUQNumber,
      databaseName: 'tafsir',
    );
    log(
      'Loaded tafsir rows=${result.length} index=${ayah.ayahUQNumber} tafsirIndex=$tafsirIndex',
      name: 'HayahQuran',
    );
    if (result.isEmpty) return '';
    return _cleanTafsirText(result.first.tafsirText);
  } catch (_) {
    return '';
  }
}

void _showTafsirDownloads(BuildContext context, AyahModel ayah) {
  final quran = QuranLibrary();
  final tafsirs = quran.tafsirAndTraslationCollection;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Text(
                  'التفاسير والترجمات المتاحة',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: tafsirs.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: Colors.white.withValues(alpha: 0.08)),
                  itemBuilder: (context, index) {
                    final tafsir = tafsirs[index];
                    final downloaded = quran.getTafsirDownloaded(index);
                    final selected = quran.tafsirSelected == index;

                    return ListTile(
                      leading: Icon(
                        downloaded
                            ? Icons.check_circle
                            : Icons.download_outlined,
                        color: downloaded
                            ? QuranPage._goldColor
                            : Colors.white70,
                      ),
                      title: Text(
                        _decodeLegacyArabic(tafsir.name),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _decodeLegacyArabic(tafsir.bookName),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.radio_button_checked,
                              color: QuranPage._goldColor,
                            )
                          : const Icon(
                              Icons.radio_button_unchecked,
                              color: Colors.white38,
                            ),
                      onTap: () async {
                        if (!downloaded) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'جاري تحميل ${_decodeLegacyArabic(tafsir.name)}',
                              ),
                            ),
                          );
                          await quran.tafsirDownload(index);
                        }
                        quran.changeTafsirSwitch(index, pageNumber: ayah.page);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted) _showAyahTafsir(context, ayah);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showArabicMeaning(BuildContext context, AyahModel ayah) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'المعنى المبسط للآية',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ayah.text,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<String>(
                future: _loadSimpleArabicMeaning(ayah),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: QuranPage._goldColor,
                      ),
                    );
                  }

                  final meaning = snapshot.data?.trim() ?? '';
                  if (meaning.isEmpty) {
                    return Text(
                      'تعذر تحميل المعنى المبسط الآن. تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 18,
                        height: 1.7,
                      ),
                    );
                  }

                  return Text(
                    meaning,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 18,
                      height: 1.7,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<String> _loadSimpleArabicMeaning(AyahModel ayah) async {
  try {
    final quranService = Get.find<QuranService>();
    final surah = ayah.surahNumber ?? _surahNumberFromGlobalAyah(ayah);
    if (surah <= 0) return '';

    final meaning = await quranService.getTafsirForEdition(
      surah,
      ayah.ayahNumber,
      'ar.muyassar',
    );
    return _cleanTafsirText(meaning);
  } catch (error) {
    log('Simple meaning failed: $error', name: 'HayahQuran');
    return '';
  }
}

String _decodeLegacyArabic(String value) {
  try {
    return utf8.decode(latin1.encode(value));
  } catch (_) {
    return value;
  }
}

String _cleanTafsirText(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .trim();
}

class _TafsirEmptyState extends StatelessWidget {
  const _TafsirEmptyState({required this.ayah, this.error});

  final AyahModel ayah;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: QuranPage._goldColor, size: 34),
          const SizedBox(height: 12),
          const Text(
            'لم يتم العثور على تفسير لهذه الآية في التفسير الحالي.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showTafsirDownloads(context, ayah);
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('تحميل أو اختيار تفسير آخر'),
          ),
        ],
      ),
    );
  }
}

class _QuranOptionTile extends StatelessWidget {
  const _QuranOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: QuranPage._goldColor),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      ),
    );
  }
}

class _QuranRangeDropdown<T> extends StatelessWidget {
  const _QuranRangeDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF151515),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70, fontSize: 14.sp),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(10.r),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: QuranPage._goldColor),
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
      style: TextStyle(color: Colors.white, fontSize: 14.sp),
      items: items,
      onChanged: onChanged,
    );
  }
}

int getAyahUQNumber(int surah, int verse) {
  int uq = 0;
  for (int i = 1; i < surah; i++) {
    uq += quran_text.getVerseCount(i);
  }
  return uq + verse;
}
