// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran_text;
import 'package:quran_library/quran_library.dart';

import '../controllers/app_controller.dart';
import '../services/audio_service.dart';
import '../services/audio_download_service.dart';
import '../services/quran_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../static/mysnakbar.dart';
import 'quran_memorization_setup_page.dart';
import 'quran_audio_page.dart';

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

  // استماع وقراءة
  late QuranReciterOption _selectedReciter;
  int _selectedAudioSurah = 1;
  int _audioStartVerse = 1;
  int _audioEndVerse = 7;
  final RxInt _audioRepeatCount = 1.obs;
  final RxBool _isCurrentSurahDownloaded = false.obs;

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

    // تهيئة القارئ والسورة والآيات لاستماع وقراءة
    try {
      final lastRead = _quranService.getLastRead();
      _selectedReciter = _quranService.getSelectedReciter();
      _selectedAudioSurah = _quranService.getSelectedAudioSurahOrDefault(lastRead.surah.clamp(1, 114));
      final maxVerses = quran_text.getVerseCount(_selectedAudioSurah);
      _audioStartVerse = _quranService.getSelectedAudioStartVerseOrDefault(lastRead.verse.clamp(1, maxVerses));
      _audioEndVerse = _quranService.getSelectedAudioEndVerseOrDefault(maxVerses);
      _audioRepeatCount.value = _quranService.getSelectedAudioRepeatCount().clamp(1, 10);
    } catch (_) {
      _selectedReciter = QuranService.reciters.first;
      _selectedAudioSurah = 1;
      _audioStartVerse = 1;
      _audioEndVerse = 7;
      _audioRepeatCount.value = 1;
    }

    try {
      final downloadService = Get.find<AudioDownloadService>();
      downloadService.onSurahDownloaded = (surah) {
        if (surah == _selectedAudioSurah) {
          _checkDownloadStatus();
        }
      };
    } catch (_) {}
    _checkDownloadStatus();

    // تعيين خط التجويد الملون (1) فوراً بشكل متزامن قبل بدء البناء لمنع الانهيار
    try {
      final quranCtrl = QuranCtrl.instance;
      quranCtrl.state.fontsSelected.value = 1;
    } catch (e) {
      log('Error forcing default Tajweed font in initState: $e');
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
      if (processing == ProcessingState.completed) {
        if (!_isToolbarVisible) {
          _showBars();
        }
      }
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

      // التأكيد على اختيار خط التجويد الملون المخزن محلياً
      try {
        final quranCtrl = QuranCtrl.instance;
        if (quranCtrl.state.fontsSelected.value != 1) {
          await quranCtrl.switchFontType(fontIndex: 1);
        }
      } catch (e) {
        log('Error forcing Tajweed font: $e');
      }
    });
  }

  @override
  void dispose() {
    _audioIndexSubscription?.cancel();
    _audioStateSubscription?.cancel();
    try {
      final downloadService = Get.find<AudioDownloadService>();
      if (downloadService.onSurahDownloaded != null) {
        downloadService.onSurahDownloaded = null;
      }
    } catch (_) {}
    try {
      final audioService = Get.find<QuranAudioService>();
      audioService.stop();
      QuranCtrl.instance.selectedAyahsByUnequeNumber.clear();
      QuranCtrl.instance.selectedAyahsByUnequeNumber.refresh();
    } catch (_) {}
    // إظهار الـ Bottom Nav Bar عند الخروج من صفحة القرآن
    _appController.setNavBarVisible(true);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
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
      } else {
        Get.find<QuranAudioService>().stop();
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
    final Color activeActionColor = _isNight ? AppTheme.goldNight : AppTheme.primaryLight;
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
            onTap: _handlePageTap,
            child: Stack(
              children: [
                // ── المصحف: بدون أي Obx حوله تمامًا ──
                Positioned.fill(
                  child: Obx(() {
                    final bool isReadingMode = !_isListenAndReadMode.value;
                    final Color borderGoldColor = _isNight
                        ? const Color(0xFF8A6E35) // Elegant muted antique gold for night mode to avoid glare
                        : const Color(0xFFC5A059); // Classic bright gold for light mode
                    final Color mushafBgColor = _isNight ? const Color(0xFF0B120F) : const Color(0xFFFAF6EB);
                    final Color mushafTextColor = _isNight ? AppTheme.textNight : const Color(0xFF2C2518);

                    final double bottomPadding = _isToolbarVisible
                        ? (isReadingMode ? 116.h : 204.h)
                        : 0;

                    return Padding(
                      padding: EdgeInsets.only(
                        top: _isToolbarVisible ? 74.h : 0,
                        bottom: bottomPadding,
                      ),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(_isToolbarVisible ? 1.08 : 1.38),
                        ),
                        child: Container(
                          color: mushafBgColor,
                          padding: EdgeInsets.symmetric(
                            horizontal: _isToolbarVisible ? 10.w : 4.w,
                            vertical: _isToolbarVisible ? 14.h : 6.h,
                          ),
                          child: Stack(
                            children: [
                              // The Medina style multi-layered frame
                              Container(
                                decoration: BoxDecoration(
                                  color: mushafBgColor,
                                  border: Border.all(
                                    color: borderGoldColor, // Dynamic outer gold border
                                    width: 1.5.w,
                                  ),
                                ),
                                padding: EdgeInsets.all(_isToolbarVisible ? 3.r : 1.r),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _isNight
                                          ? const Color(0xFF13231C) // Deep muted forest green for night mode
                                          : const Color(0xFF0F4C3A), // Classic Medina dark green band
                                      width: _isToolbarVisible ? 7.w : 3.w, // Thinner green band in fullscreen to save space
                                    ),
                                  ),
                                  padding: EdgeInsets.all(_isToolbarVisible ? 3.r : 1.r),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: borderGoldColor, // Dynamic inner gold border
                                        width: 1.5.w,
                                      ),
                                    ),
                                    padding: EdgeInsets.all(_isToolbarVisible ? 2.r : 1.r),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _isNight
                                              ? const Color(0xFF13231C)
                                              : const Color(0xFF0F4C3A), // Dynamic thin inner green line
                                          width: 1.w,
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: _isListenAndReadMode.value
                                            ? 14.w
                                            : (_isToolbarVisible ? 4.w : 2.w),
                                        vertical: _isListenAndReadMode.value
                                            ? 12.h
                                            : (_isToolbarVisible ? 6.h : 3.h),
                                      ),
                                      child: GestureDetector(
                                        onDoubleTap: _handlePageDoubleTap,
                                        child: QuranLibraryScreen(
                                          isDark: _isNight,
                                          languageCode: Get.locale?.languageCode ?? 'ar',
                                          backgroundColor: mushafBgColor,
                                          textColor: mushafTextColor,
                                          ayahIconColor: _isNight
                                              ? const Color(0xFFF1C40F) // Bright gold in dark mode
                                              : const Color(0xFFC0392B), // Crimson red in light mode
                                          ayahSelectedBackgroundColor: goldColor.withValues(alpha: 0.22),
                                          ayahSelectedFontColor: mushafTextColor,
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
                                          onPagePress: _handlePageTap,
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
                                ),
                              ),
                              // Corner gold medallions (Medina style ornaments)
                              Positioned(
                                top: _isToolbarVisible ? 4.h : 2.h,
                                left: _isToolbarVisible ? 4.w : 2.w,
                                child: Icon(
                                  Icons.brightness_5_rounded,
                                  color: borderGoldColor,
                                  size: _isToolbarVisible ? 11.r : 6.r,
                                ),
                              ),
                              Positioned(
                                top: _isToolbarVisible ? 4.h : 2.h,
                                right: _isToolbarVisible ? 4.w : 2.w,
                                child: Icon(
                                  Icons.brightness_5_rounded,
                                  color: borderGoldColor,
                                  size: _isToolbarVisible ? 11.r : 6.r,
                                ),
                              ),
                              Positioned(
                                bottom: _isToolbarVisible ? 4.h : 2.h,
                                left: _isToolbarVisible ? 4.w : 2.w,
                                child: Icon(
                                  Icons.brightness_5_rounded,
                                  color: borderGoldColor,
                                  size: _isToolbarVisible ? 11.r : 6.r,
                                ),
                              ),
                              Positioned(
                                bottom: _isToolbarVisible ? 4.h : 2.h,
                                right: _isToolbarVisible ? 4.w : 2.w,
                                child: Icon(
                                  Icons.brightness_5_rounded,
                                  color: borderGoldColor,
                                  size: _isToolbarVisible ? 11.r : 6.r,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                // ── شريط الأدوات العلوي ──
                if (_isToolbarVisible)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border(
                          bottom: BorderSide(
                            color: _isNight
                                ? const Color(0xFF1E2D28)
                                : const Color(0xFFEED2A0).withOpacity(0.5),
                            width: 1.h,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: SizedBox(
                          height: 58.h,
                          child: Obx(() => Row(
                            children: [
                              Expanded(
                                child: _buildAppBarAction(
                                  icon: Icons.menu_book_rounded,
                                  label: 'quran_read_only'.tr,
                                  active: !_isListenAndReadMode.value,
                                  goldColor: activeActionColor,
                                  inactiveColor: inactiveColor,
                                  onTap: () => _setListenAndReadMode(false),
                                ),
                              ),
                              Expanded(
                                child: _buildAppBarAction(
                                  icon: Icons.hearing_rounded,
                                  label: 'quran_listen_read'.tr,
                                  active: _isListenAndReadMode.value,
                                  goldColor: activeActionColor,
                                  inactiveColor: inactiveColor,
                                  onTap: () => _setListenAndReadMode(true),
                                ),
                              ),
                              Expanded(
                                child: Obx(() => _buildAppBarAction(
                                  icon: Icons.volume_up_rounded,
                                  label: 'quran_audio'.tr,
                                  active: audioService.isPlaying.value,
                                  goldColor: activeActionColor,
                                  inactiveColor: inactiveColor,
                                  onTap: () => Get.to(() => const QuranAudioPage()),
                                )),
                              ),
                              Expanded(
                                child: _buildAppBarAction(
                                  icon: Icons.psychology_rounded,
                                  label: 'quran_memorize'.tr,
                                  active: false,
                                  goldColor: activeActionColor,
                                  inactiveColor: inactiveColor,
                                  onTap: () {
                                    final quranService = Get.find<QuranService>();
                                    final page = _currentPage.value;
                                    final pageVerses = quranService.getPageVerses(page);
                                    final lastRead = quranService.getLastRead();
                                    final initialVerse = pageVerses.isEmpty ? lastRead : pageVerses.first;
                                    final surah = initialVerse.surah;
                                    final startVerse = initialVerse.verse;
                                    final endVerse = pageVerses
                                        .where((v) => v.surah == surah)
                                        .map((v) => v.verse)
                                        .fold<int>(startVerse, (prev, v) => v > prev ? v : prev);
                                    Get.to(() => QuranMemorizationSetupPage(
                                      initialSurah: surah,
                                      initialStartVerse: startVerse,
                                      initialEndVerse: endVerse,
                                    ));
                                  },
                                ),
                              ),
                            ],
                          )),
                        ),
                      ),
                    ),
                  ),

                // ── أيقونة العلامة المحفوظة ──
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
                if (_isToolbarVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Obx(() {
                      final bool isReadingMode = !_isListenAndReadMode.value;
                      final Color cardColor = _isNight ? AppTheme.surfaceNight : AppTheme.surfaceLight;
                      final Color textVariantColor = _isNight ? AppTheme.textVariantNight : AppTheme.textVariantLight;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isReadingMode)
                            Container(
                              color: bgColor,
                              child: SafeArea(
                                top: false,
                                bottom: false,
                                child: Container(
                                  height: 52.h,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: _isNight
                                            ? const Color(0xFF1E2D28)
                                            : const Color(0xFFEED2A0).withOpacity(0.5),
                                        width: 1.h,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildBottomAction(
                                        icon: Icons.bookmark_add_outlined,
                                        label: 'quran_save_mark'.tr,
                                        onTap: () => _saveCurrentReadingMark(context),
                                      ),
                                      _buildBottomAction(
                                        icon: Icons.bookmark_rounded,
                                        label: 'quran_go_to_mark'.tr,
                                        onTap: () => _goToReadingMark(context),
                                      ),
                                      _buildBottomAction(
                                        icon: Icons.format_list_bulleted_rounded,
                                        label: 'surah_index'.tr, // "الفهرس"
                                        onTap: () => _showSurahIndex(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            _buildAudioControlPanel(context, cardColor, textColor, goldColor, textVariantColor),
                          const AppBottomNav(currentIndex: 2),
                        ],
                      );
                    }),
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

  void _handlePageTap() {
    if (!_isToolbarVisible) {
      _showBars();
    }
  }

  void _handlePageDoubleTap() {
    _toggleBars();
  }

  Future<void> _stopAudio() async {
    final audioService = Get.find<QuranAudioService>();
    await audioService.stop();
    try {
      QuranCtrl.instance.selectedAyahsByUnequeNumber.clear();
      QuranCtrl.instance.selectedAyahsByUnequeNumber.refresh();
    } catch (_) {}
  }

  Future<void> _checkDownloadStatus() async {
    try {
      final downloadService = Get.find<AudioDownloadService>();
      final downloaded = await downloadService.isSurahDownloaded(_selectedReciter.key, _selectedAudioSurah);
      _isCurrentSurahDownloaded.value = downloaded;
    } catch (_) {}
  }

  Future<void> _playSelectedRange() async {
    final verses = _quranService.getSurahVersesRange(_selectedAudioSurah, _audioStartVerse, _audioEndVerse);
    final urls = verses.map((v) => v.audioUrl).toList();

    // Check offline status
    bool allDownloaded = true;
    final downloadService = Get.find<AudioDownloadService>();
    final reciterKey = _selectedReciter.key;
    for (final verse in verses) {
      final downloaded = await downloadService.isVerseDownloaded(reciterKey, verse.surah, verse.verse);
      if (!downloaded) {
        allDownloaded = false;
        break;
      }
    }

    if (!allDownloaded) {
      final hasInternet = await downloadService.hasInternetConnection();
      if (!hasInternet) {
        MySnackbar.showError(
          title: 'تنبيه',
          message: 'لا يوجد اتصال بالإنترنت والملف غير محمل، يرجى تحميله أو الاتصال بالإنترنت.',
        );
        return;
      }
    }

    final audioService = Get.find<QuranAudioService>();
    await audioService.stop();
    await audioService.playPlaylist(urls, verses: verses, repeatCount: _audioRepeatCount.value);
  }

  Widget _buildAudioControlPanel(BuildContext context, Color cardColor, Color textColor, Color goldColor, Color textVariantColor) {
    final audioService = Get.find<QuranAudioService>();
    final maxVerses = quran_text.getVerseCount(_selectedAudioSurah);
    final versesList = List.generate(maxVerses, (i) => i + 1);

    return Container(
      height: 140.h,
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: _isNight
                ? const Color(0xFF1E2D28)
                : const Color(0xFFEED2A0).withValues(alpha: 0.5),
            width: 1.h,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Column(
        children: [
          // Row 1: Reciter and Surah Selectors with Download status
          Row(
            children: [
              // Reciter Dropdown
              Expanded(
                flex: 5,
                child: Container(
                  height: 34.h,
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  decoration: BoxDecoration(
                    color: _isNight ? const Color(0xFF0F1815) : const Color(0xFFFAF6EB),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: goldColor.withValues(alpha: 0.25)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedReciter.key,
                      isExpanded: true,
                      dropdownColor: cardColor,
                      icon: Icon(Icons.arrow_drop_down_rounded, color: goldColor),
                      items: QuranService.reciters.map((reciter) {
                        return DropdownMenuItem<String>(
                          value: reciter.key,
                          child: Text(
                            reciter.name,
                            style: TextStyle(color: textColor, fontSize: 12.sp, fontFamily: 'sans-serif'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() {
                            _selectedReciter = QuranService.reciters.firstWhere((r) => r.key == val);
                          });
                          await _quranService.setSelectedReciter(val);
                          await _stopAudio();
                          _checkDownloadStatus();
                        }
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              // Surah Dropdown
              Expanded(
                flex: 4,
                child: Container(
                  height: 34.h,
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  decoration: BoxDecoration(
                    color: _isNight ? const Color(0xFF0F1815) : const Color(0xFFFAF6EB),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: goldColor.withValues(alpha: 0.25)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedAudioSurah,
                      isExpanded: true,
                      dropdownColor: cardColor,
                      icon: Icon(Icons.arrow_drop_down_rounded, color: goldColor),
                      items: List.generate(114, (i) => i + 1).map((surahNum) {
                        return DropdownMenuItem<int>(
                          value: surahNum,
                          child: Text(
                            quran_text.getSurahNameArabic(surahNum),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12.sp,
                              fontFamily: 'naskh',
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          final maxV = quran_text.getVerseCount(val);
                          setState(() {
                            _selectedAudioSurah = val;
                            _audioStartVerse = 1;
                            _audioEndVerse = maxV;
                          });
                          await _quranService.setSelectedAudioSurah(val);
                          await _quranService.setSelectedAudioStartVerse(1);
                          await _quranService.setSelectedAudioEndVerse(maxV);
                          await _stopAudio();
                          _checkDownloadStatus();
                          try {
                            final startPage = quran_text.getPageNumber(val, 1);
                            QuranLibrary().jumpToPage(startPage);
                          } catch (_) {}
                        }
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              // Download Status/Trigger Button
              Obx(() {
                final downloadService = Get.find<AudioDownloadService>();
                final isDownloading = downloadService.isDownloading.value;
                final isDownloaded = _isCurrentSurahDownloaded.value;

                if (isDownloading) {
                  return Container(
                    width: 34.h,
                    height: 34.h,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: CircularProgressIndicator(
                        value: downloadService.downloadProgress.value,
                        strokeWidth: 2.5.r,
                        valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (isDownloaded) {
                      MySnackbar.showSuccess(
                        title: 'تنبيه',
                        message: 'هذه السورة محملة بالفعل لجهازك.',
                      );
                      return;
                    }
                    final hasInternet = await downloadService.hasInternetConnection();
                    if (!hasInternet) {
                      MySnackbar.showError(
                        title: 'خطأ في الاتصال',
                        message: 'يرجى التحقق من اتصالك بالإنترنت والتحميل مجدداً.',
                      );
                      return;
                    }
                    try {
                      await downloadService.downloadSurah(
                        _selectedReciter.key,
                        _selectedAudioSurah,
                        _selectedReciter,
                      );
                      await _checkDownloadStatus();
                    } catch (e) {
                      log('Error downloading surah: $e');
                    }
                  },
                  child: Container(
                    width: 34.h,
                    height: 34.h,
                    decoration: BoxDecoration(
                      color: isDownloaded
                          ? Colors.green.withValues(alpha: 0.15)
                          : goldColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDownloaded
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_download_rounded,
                      color: isDownloaded ? Colors.green : goldColor,
                      size: 18.r,
                    ),
                  ),
                );
              }),
            ],
          ),
          SizedBox(height: 8.h),
          // Row 2: Verse Range Selector (من ... إلى ...) AND Repeat Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Verse Range Selector (من ... إلى ...)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('من', style: TextStyle(color: textVariantColor, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4.w),
                  Container(
                    height: 32.h,
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                    decoration: BoxDecoration(
                      color: _isNight ? const Color(0xFF0F1815) : const Color(0xFFFAF6EB),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: goldColor.withValues(alpha: 0.15)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _audioStartVerse,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontSize: 12.sp),
                        icon: const SizedBox.shrink(),
                        items: versesList.map((v) {
                          return DropdownMenuItem<int>(
                            value: v,
                            child: Text('$v', style: TextStyle(color: textColor)),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _audioStartVerse = val;
                              if (_audioEndVerse < _audioStartVerse) {
                                _audioEndVerse = _audioStartVerse;
                              }
                            });
                            await _quranService.setSelectedAudioStartVerse(val);
                            if (_audioEndVerse < _audioStartVerse) {
                              await _quranService.setSelectedAudioEndVerse(_audioStartVerse);
                            }
                            await _stopAudio();
                          }
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text('إلى', style: TextStyle(color: textVariantColor, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4.w),
                  Container(
                    height: 32.h,
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                    decoration: BoxDecoration(
                      color: _isNight ? const Color(0xFF0F1815) : const Color(0xFFFAF6EB),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: goldColor.withValues(alpha: 0.15)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _audioEndVerse,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontSize: 12.sp),
                        icon: const SizedBox.shrink(),
                        items: versesList.where((v) => v >= _audioStartVerse).map((v) {
                          return DropdownMenuItem<int>(
                            value: v,
                            child: Text('$v', style: TextStyle(color: textColor)),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _audioEndVerse = val;
                            });
                            await _quranService.setSelectedAudioEndVerse(val);
                            await _stopAudio();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              // Repeat Selector, Centered
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تكرار:', style: TextStyle(color: textVariantColor, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                  SizedBox(width: 6.w),
                  Container(
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: _isNight ? const Color(0xFF0F1815) : const Color(0xFFFAF6EB),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: goldColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_audioRepeatCount.value > 1) {
                              _audioRepeatCount.value--;
                              _quranService.setSelectedAudioRepeatCount(_audioRepeatCount.value);
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            child: Icon(Icons.remove_rounded, color: goldColor, size: 16.r),
                          ),
                        ),
                        Obx(() => Text(
                          '${_audioRepeatCount.value}',
                          style: TextStyle(color: textColor, fontSize: 12.sp, fontWeight: FontWeight.bold),
                        )),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _audioRepeatCount.value++;
                            _quranService.setSelectedAudioRepeatCount(_audioRepeatCount.value);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            child: Icon(Icons.add_rounded, color: goldColor, size: 16.r),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // Row 3: Centered playback controls (Stop, Pause, Play)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop button
              GestureDetector(
                onTap: _stopAudio,
                child: Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.stop_rounded,
                    color: Colors.red,
                    size: 20.r,
                  ),
                ),
              ),
              SizedBox(width: 28.w),
              // Pause button
              Obx(() {
                final playing = audioService.isPlaying.value;
                final hasPlaylist = audioService.playingVerses.isNotEmpty;
                final canPause = playing && hasPlaylist;
                return GestureDetector(
                  onTap: canPause ? () => audioService.pause() : null,
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: canPause ? goldColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pause_rounded,
                      color: canPause ? goldColor : Colors.grey.withValues(alpha: 0.5),
                      size: 20.r,
                    ),
                  ),
                );
              }),
              SizedBox(width: 28.w),
              // Play/Resume button
              Obx(() {
                final playing = audioService.isPlaying.value;
                return GestureDetector(
                  onTap: playing
                      ? null
                      : () {
                          if (audioService.playingVerses.isNotEmpty) {
                            audioService.resume();
                          } else {
                            _playSelectedRange();
                          }
                        },
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: !playing ? goldColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: !playing ? goldColor : Colors.grey.withValues(alpha: 0.5),
                      size: 20.r,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  void _showBars() {
    if (mounted) {
      setState(() => _isToolbarVisible = true);
    }
    _appController.setNavBarVisible(true);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }

  void _hideBars() {
    if (mounted) {
      setState(() => _isToolbarVisible = false);
    }
    _appController.setNavBarVisible(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool isDark = _isNight;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 100.w,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDark ? AppTheme.goldNight : AppTheme.primaryLight,
              size: 24.r,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                color: isDark ? AppTheme.textNight : AppTheme.textVariantLight,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '') // Remove tashkeel/diacritics
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  void _showSurahIndex(BuildContext context) {
    final quranService = Get.find<QuranService>();
    final surahs = quranService.getSurahs();
    String searchQuery = '';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final double sheetHeight = MediaQuery.of(sheetContext).size.height * 0.75;
            final bool isDarkMode = _isNight;
            final Color sheetBgColor = isDarkMode ? const Color(0xFF0F1715) : const Color(0xFFFAF6EB);
            final Color txtColor = isDarkMode ? AppTheme.textNight : const Color(0xFF2C2518);
            final Color separatorColor = isDarkMode ? const Color(0xFF1E2D28) : const Color(0xFFEED2A0).withOpacity(0.5);

            // Filter surahs based on normalized search query
            final normalizedQuery = _normalizeArabic(searchQuery.trim().toLowerCase());
            final filteredSurahs = surahs.where((surah) {
              if (normalizedQuery.isEmpty) return true;
              final normArabic = _normalizeArabic(surah.nameArabic.toLowerCase());
              final normEnglish = surah.nameEnglish.toLowerCase();
              final normNumber = surah.number.toString();
              return normArabic.contains(normalizedQuery) ||
                  normEnglish.contains(normalizedQuery) ||
                  normNumber == normalizedQuery;
            }).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Container(
                height: sheetHeight,
                decoration: BoxDecoration(
                  color: sheetBgColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode ? const Color(0xFF8A6E35) : const Color(0xFFC5A059),
                      width: 2.w,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 12.h),
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF3A4E47) : const Color(0xFFC5A059).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'surah_index'.tr,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppTheme.goldNight : AppTheme.primaryLight,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Premium Search Text Field
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      child: TextField(
                        style: TextStyle(color: txtColor, fontSize: 14.sp),
                        onChanged: (val) {
                          setSheetState(() {
                            searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: Get.locale?.languageCode == 'ar' ? 'بحث عن سورة...' : 'Search Surah...',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 13.sp,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDarkMode ? AppTheme.goldNight : AppTheme.primaryLight,
                            size: 20.r,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      searchQuery = '';
                                    });
                                  },
                                  child: Icon(
                                    Icons.clear_rounded,
                                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                                    size: 18.r,
                                  ),
                                )
                              : null,
                          filled: true,
                          fillColor: isDarkMode ? const Color(0xFF141F1C) : const Color(0xFFF0EBE0),
                          contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(
                              color: isDarkMode ? AppTheme.goldNight : AppTheme.primaryLight,
                              width: 1.w,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Expanded(
                      child: filteredSurahs.isEmpty
                          ? Center(
                              child: Text(
                                Get.locale?.languageCode == 'ar'
                                    ? 'لا توجد سور مطابقة لبحثك'
                                    : 'No matching surahs found',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredSurahs.length,
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              separatorBuilder: (context, index) => Divider(color: separatorColor, height: 1),
                              itemBuilder: (context, index) {
                                final surah = filteredSurahs[index];
                                final String displayVerses = Get.locale?.languageCode == 'ar'
                                    ? '${surah.verseCount} آية'
                                    : '${surah.verseCount} verses';

                                return ListTile(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  leading: Container(
                                    width: 36.w,
                                    height: 36.h,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDarkMode ? const Color(0xFF8A6E35) : const Color(0xFFC5A059),
                                        width: 1.5.w,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${surah.number}',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? AppTheme.goldNight : AppTheme.primaryLight,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    surah.nameArabic,
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: txtColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    surah.nameEnglish,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        surah.revelationPlace.toLowerCase() == 'makkah'
                                            ? Icons.location_city_rounded
                                            : Icons.mosque_rounded,
                                        size: 16.r,
                                        color: isDarkMode ? const Color(0xFF8A6E35) : const Color(0xFFC5A059),
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        displayVerses,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    QuranLibrary().jumpToSurah(surah.number);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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



int getAyahUQNumber(int surah, int verse) {
  int uq = 0;
  for (int i = 1; i < surah; i++) {
    uq += quran_text.getVerseCount(i);
  }
  return uq + verse;
}
