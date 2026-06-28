// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran_text;
import 'package:quran_library/quran_library.dart';

import '../controllers/app_controller.dart';
import '../services/audio_service.dart';
import '../services/quran_service.dart';
import 'quran_memorization_page.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  static const _goldColor = Color(0xFFD4AF37);

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  late final QuranService _quranService;
  Timer? _toolbarTimer;
  bool _isToolbarVisible = false;

  @override
  void initState() {
    super.initState();
    _quranService = Get.find<QuranService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lastRead = _quranService.getLastRead();
      QuranLibrary().jumpToPage(lastRead.page);
    });
  }

  @override
  void dispose() {
    _toolbarTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();

    return Theme(
      data: ThemeData(
        useMaterial3: false,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: QuranPage._goldColor,
          secondary: QuranPage._goldColor,
          surface: Colors.black,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
        ),
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, _) => appController.navigateToPage(0),
        child: Stack(
          children: [
            QuranLibraryScreen(
              isDark: true,
              languageCode: Get.locale?.languageCode ?? 'ar',
              backgroundColor: Colors.black,
              textColor: Colors.white,
              ayahIconColor: QuranPage._goldColor,
              ayahSelectedBackgroundColor: QuranPage._goldColor.withValues(
                alpha: 0.22,
              ),
              ayahSelectedFontColor: Colors.white,
              bookmarksColor: QuranPage._goldColor,
              withPageView: true,
              optimizeScrolling: false,
              useDefaultAppBar: true,
              showAyahBookmarkedIcon: true,
              onPageChanged: (pageIndex) =>
                  _quranService.saveLastReadPage(pageIndex + 1),
              onPagePress: _toggleToolbar,
              onAyahLongPress: (_, ayah) =>
                  _showAyahMoreOptions(context: context, ayah: ayah),
              anotherMenuChild: const Icon(
                Icons.more_horiz,
                color: Colors.grey,
              ),
              anotherMenuChildOnTap: (ayah) =>
                  _showAyahMoreOptions(context: context, ayah: ayah),
            ),
            PositionedDirectional(
              start: 12,
              end: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 8,
              child: AnimatedOpacity(
                opacity: _isToolbarVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_isToolbarVisible,
                  child: _QuranFloatingToolbar(
                    onHome: () => appController.navigateToPage(0),
                    onMemorize: () => _showQuranMemorizationSheet(context),
                    onAudio: () => _showQuranAudioSheet(context),
                    onSaveMark: () => _saveCurrentReadingMark(context),
                    onOpenMark: () => _openReadingMarkSheet(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleToolbar() {
    if (_isToolbarVisible) {
      _hideToolbar();
    } else {
      _showToolbar();
    }
  }

  void _showToolbar() {
    _toolbarTimer?.cancel();
    if (mounted) {
      setState(() => _isToolbarVisible = true);
    }
    _toolbarTimer = Timer(const Duration(seconds: 5), _hideToolbar);
  }

  void _hideToolbar() {
    _toolbarTimer?.cancel();
    _toolbarTimer = null;
    if (mounted && _isToolbarVisible) {
      setState(() => _isToolbarVisible = false);
    }
  }

  Future<void> _saveCurrentReadingMark(BuildContext context) async {
    final page = _currentMushafPage();
    await _quranService.saveReadingMarkPage(page);
    await _quranService.saveLastReadPage(page);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ العلامة في الموضع الحالي')),
    );
  }
}

class _QuranFloatingToolbar extends StatelessWidget {
  const _QuranFloatingToolbar({
    required this.onHome,
    required this.onMemorize,
    required this.onAudio,
    required this.onSaveMark,
    required this.onOpenMark,
  });

  final VoidCallback onHome;
  final VoidCallback onMemorize;
  final VoidCallback onAudio;
  final VoidCallback onSaveMark;
  final VoidCallback onOpenMark;

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: AlignmentDirectional.bottomCenter,
        child: Material(
          color: Colors.black.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(24),
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: QuranPage._goldColor.withValues(alpha: 0.34),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuranToolbarButton(
                  tooltip: 'رجوع',
                  icon: Icons.home_rounded,
                  onPressed: onHome,
                ),
                _QuranToolbarButton(
                  tooltip: 'حفظ موضع القراءة',
                  icon: Icons.bookmark_add_rounded,
                  onPressed: onSaveMark,
                ),
                _QuranToolbarButton(
                  tooltip: 'الذهاب إلى العلامة',
                  icon: Icons.flag_rounded,
                  onPressed: onOpenMark,
                ),
                _QuranToolbarButton(
                  tooltip: 'تشغيل التلاوة',
                  icon: Icons.volume_up_rounded,
                  onPressed: onAudio,
                ),
                _QuranToolbarButton(
                  tooltip: 'مساعد الحفظ',
                  icon: Icons.psychology_rounded,
                  onPressed: onMemorize,
                ),
              ],
            ),
          ),
      ),
    );
  }
}

class _QuranToolbarButton extends StatelessWidget {
  const _QuranToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: QuranPage._goldColor),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

void _openReadingMarkSheet(BuildContext context) {
  final quranService = Get.find<QuranService>();
  final currentPageVerses = quranService.getPageVerses(_currentMushafPage());
  final savedMark = quranService.getReadingMark();
  final initialVerse = savedMark ??
      (currentPageVerses.isEmpty
          ? quranService.getLastRead()
          : currentPageVerses.first);
  var selectedSurah = initialVerse.surah;
  var selectedVerse = initialVerse.verse;

  Future<void> saveSelectedAndGo(BuildContext sheetContext) async {
    await quranService.saveReadingMark(selectedSurah, selectedVerse);
    await quranService.saveLastRead(selectedSurah, selectedVerse);
    final page = quran_text.getPageNumber(selectedSurah, selectedVerse);
    QuranLibrary().jumpToPage(page);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final verseCount = quran_text.getVerseCount(selectedSurah);
          selectedVerse = selectedVerse.clamp(1, verseCount).toInt();

          return SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  MediaQuery.viewInsetsOf(context).bottom + 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.flag_rounded,
                          color: QuranPage._goldColor,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'علامة القراءة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
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
                    if (savedMark != null) ...[
                      const SizedBox(height: 8),
                      _ReadingMarkSummary(verse: savedMark),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: QuranPage._goldColor,
                          side: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          QuranLibrary().jumpToPage(savedMark.page);
                          quranService.saveLastRead(
                            savedMark.surah,
                            savedMark.verse,
                          );
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.near_me_rounded),
                        label: const Text('الذهاب إلى العلامة المحفوظة'),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'لم تحفظ علامة بعد. اختر موضعاً أو احفظ الصفحة الحالية من شريط الأدوات.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
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
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _QuranRangeDropdown<int>(
                      value: selectedVerse,
                      label: 'الآية',
                      items: List.generate(verseCount, (index) {
                        final verse = index + 1;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedVerse = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: QuranPage._goldColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => saveSelectedAndGo(sheetContext),
                      icon: const Icon(Icons.bookmark_added_rounded),
                      label: const Text('حفظ هذا الموضع والذهاب إليه'),
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

class _ReadingMarkSummary extends StatelessWidget {
  const _ReadingMarkSummary({required this.verse});

  final QuranVerse verse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        'المحفوظ الآن: ${quran_text.getSurahNameArabic(verse.surah)} - الآية ${verse.verse} - الصفحة ${verse.page}',
        textAlign: TextAlign.right,
        style: const TextStyle(color: Colors.white, height: 1.5),
      ),
    );
  }
}

void _showQuranMemorizationSheet(BuildContext context) {
  final quranService = Get.find<QuranService>();
  final initialPageVerses = quranService.getPageVerses(_currentMushafPage());
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
                  18,
                  14,
                  18,
                  MediaQuery.viewInsetsOf(context).bottom + 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.psychology_rounded,
                          color: QuranPage._goldColor,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'مساعد الحفظ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
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
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: QuranPage._goldColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('بدء الحفظ'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سيتم إخفاء الكلمات ثم إظهارها تدريجياً أثناء التلاوة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
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

void _showQuranAudioSheet(BuildContext context) {
  final quranService = Get.find<QuranService>();
  final audioService = Get.find<QuranAudioService>();
  final initialPageVerses = quranService.getPageVerses(_currentMushafPage());
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
          final currentPage = _currentMushafPage();
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
                  18,
                  14,
                  18,
                  MediaQuery.viewInsetsOf(context).bottom + 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_up_rounded,
                          color: QuranPage._goldColor,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'تشغيل التلاوة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
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
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedReciterKey,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'القارئ',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedSurah,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'السورة',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedVerse,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'بدء التشغيل من الآية',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedEndVerse,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'انتهاء التشغيل عند الآية',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'الصفحة الحالية: $currentPage',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (firstVerse != null && lastVerse != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'سيتم التشغيل من ${quran_text.getSurahNameArabic(firstVerse.surah)} '
                              'آية ${firstVerse.verse} إلى آية ${lastVerse.verse}',
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder(
                      stream: audioService.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying =
                            snapshot.data?.playing ?? audioService.isPlaying;

                        return Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: QuranPage._goldColor,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                ),
                                onPressed: isLoading
                                    ? null
                                    : playSelectedVerses,
                                icon: isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Icon(
                                        isPlaying
                                            ? Icons.replay_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                label: Text(
                                  isPlaying
                                      ? 'إعادة التشغيل'
                                      : 'تشغيل النطاق المحدد',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white12,
                                foregroundColor: Colors.white,
                                fixedSize: const Size(48, 48),
                              ),
                              onPressed: () => audioService.stop(),
                              icon: const Icon(Icons.stop_rounded),
                              tooltip: 'إيقاف',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سيتم تشغيل الآيات المختارة بالتتابع حسب القارئ المحدد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
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

int _currentMushafPage() {
  try {
    return QuranLibrary().currentPageNumber
        .clamp(1, quran_text.totalPagesCount)
        .toInt();
  } catch (_) {
    return 1;
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
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: QuranPage._goldColor),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: const TextStyle(color: Colors.white),
      items: items,
      onChanged: onChanged,
    );
  }
}
