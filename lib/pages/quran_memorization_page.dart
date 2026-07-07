import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran_text;

import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../controllers/app_controller.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/memorization_speech_service.dart';
import '../services/quran_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../static/mysnakbar.dart';

class QuranMemorizationPage extends StatefulWidget {
  const QuranMemorizationPage({
    super.key,
    required this.initialSurah,
    required this.initialStartVerse,
    required this.initialEndVerse,
  });

  final int initialSurah;
  final int initialStartVerse;
  final int initialEndVerse;

  @override
  State<QuranMemorizationPage> createState() => _QuranMemorizationPageState();
}
class _QuranMemorizationPageState extends State<QuranMemorizationPage> {
  final GlobalKey _currentWordKey = GlobalKey();

  void _scrollToCurrentWord() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentWordKey.currentContext != null) {
        Scrollable.ensureVisible(
          _currentWordKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    });
  }

  late final QuranService _quranService;
  late final QuranAudioService _audioService;
  late final MemorizationSpeechService _speechService;

  late int _selectedSurah;
  late int _startVerse;
  late int _endVerse;
  late List<_MemorizationWord> _words;
  late _MemorizationMatcher _matcher;

  int _currentWordIndex = 0;
  int _sessionStartWordIndex = 0;
  int _errorCount = 0;
  bool _isListening = false;
  bool _hasPossibleError = false;
  bool _showFullText = false;
  bool _showHint = false;
  double _soundLevel = 0;
  Timer? _restartListenTimer;
  Timer? _errorTimer;
  String _lastHeardText = '';
  String? _lastUnexpectedWord;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _quranService = Get.find<QuranService>();
    _audioService = Get.find<QuranAudioService>();
    _speechService = Get.find<MemorizationSpeechService>();
    _selectedSurah = widget.initialSurah;
    _startVerse = widget.initialStartVerse;
    _endVerse = widget.initialEndVerse;
    _message = 'tashmee_tap_mic'.tr;
    _rebuildWords(resetProgress: true);
  }

  @override
  void dispose() {
    _restartListenTimer?.cancel();
    _errorTimer?.cancel();
    _speechService.cancel();
    super.dispose();
  }

  void _rebuildWords({required bool resetProgress}) {
    final verseCount = quran_text.getVerseCount(_selectedSurah);
    _startVerse = _startVerse.clamp(1, verseCount).toInt();
    _endVerse = _endVerse.clamp(_startVerse, verseCount).toInt();

    final verses = _quranService.getSurahVersesRange(
      _selectedSurah,
      _startVerse,
      _endVerse,
    );

    _words = <_MemorizationWord>[];
    // البسملة المنقحة (بدون تشكيل) للمقارنة
    final normalizedBasmala = _normalizeArabic('بسم الله الرحمن الرحيم');
    for (final verse in verses) {
      final normalizedText = _normalizeArabic(verse.text);
      // تجاهل البسملة في غير الفاتحة
      if (_selectedSurah != 1 && verse.verse == 1) {
        if (normalizedText == normalizedBasmala) continue; // آية بسملة وحدها
        if (normalizedText.startsWith(normalizedBasmala)) {
          // بسملة + باقي الآية: احذف كلمات البسملة من التوكنز
          final basmalaWordCount = 4;
          final tokens = _splitQuranWords(verse.text);
          for (var i = basmalaWordCount; i < tokens.length; i++) {
            _words.add(
              _MemorizationWord(
                text: tokens[i],
                normalized: _normalizeArabic(tokens[i]),
                verse: verse.verse,
              ),
            );
          }
          continue;
        }
      }
      final tokens = _splitQuranWords(verse.text);
      for (final token in tokens) {
        _words.add(
          _MemorizationWord(
            text: token,
            normalized: _normalizeArabic(token),
            verse: verse.verse,
          ),
        );
      }
    }
    _words.removeWhere((word) => word.normalized.isEmpty);
    _matcher = _MemorizationMatcher(_words);

    if (resetProgress) {
      _currentWordIndex = 0;
      _errorCount = 0;
      _hasPossibleError = false;
      _soundLevel = 0;
      _lastHeardText = '';
      _lastUnexpectedWord = null;
      _showFullText = false;
      _showHint = false;
      _message = 'tashmee_tap_mic'.tr;
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      _restartListenTimer?.cancel();
      _errorTimer?.cancel();
      setState(() {
        _isListening = false;
        _soundLevel = 0;
        _message = 'tashmee_listening_stopped'.tr;
      });
      await _speechService.stop();
      return;
    }

    // Check internet connection
    bool hasConnection = true;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
      hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      hasConnection = false;
    }

    if (!hasConnection) {
      MySnackbar.showError(
        title: 'no_internet_title'.tr,
        message: 'speech_no_internet_alert'.tr,
      );
      return;
    }

    if (_audioService.isPlaying.value) {
      await _audioService.stop();
    }

    setState(() {
      _isListening = true;
      _hasPossibleError = false;
      _lastUnexpectedWord = null;
      _showHint = false;
      _message = 'tashmee_listening'.tr;
    });

    await _startListeningSession();
  }

  Future<void> _startListeningSession() async {
    _sessionStartWordIndex = _currentWordIndex;
    await _speechService.listen(
      onResult: _handleRecognizedText,
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          _restartListeningIfNeeded();
        }
      },
      onError: (error) {
        if (!mounted) return;
        if (error != 'permission_denied' && _isListening) {
          _restartListeningIfNeeded();
          return;
        }
        setState(() {
          _isListening = false;
          _soundLevel = 0;
          _message = error == 'permission_denied'
              ? 'tashmee_mic_permission'.tr
              : 'tashmee_listen_error'.tr;
        });
      },
      onSoundLevel: (level) {
        if (!mounted || !_isListening) return;
        setState(() => _soundLevel = level);
      },
    );
  }

  void _restartListeningIfNeeded() {
    if (!_isListening || _currentWordIndex >= _words.length) return;
    _restartListenTimer?.cancel();
    _restartListenTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _isListening) {
        _startListeningSession();
      }
    });
  }

  void _handleRecognizedText(String recognizedText, bool _) {
    if (!mounted || recognizedText.trim().isEmpty || _words.isEmpty) return;

    final result = _matcher.match(
      currentIndex: _currentWordIndex,
      sessionStartWordIndex: _sessionStartWordIndex,
      recognizedText: recognizedText,
    );
    if (result.isEmpty) {
      setState(() => _lastHeardText = recognizedText);
      return;
    }

    final nextWordIndex = result.nextIndex
        .clamp(_currentWordIndex, _words.length)
        .toInt();
    final madeProgress = nextWordIndex > _currentWordIndex;

    setState(() {
      _lastHeardText = recognizedText;
      if (madeProgress) {
        _errorTimer?.cancel();
        _currentWordIndex = nextWordIndex;
        _hasPossibleError = false;
        _lastUnexpectedWord = null;
        _showHint = false;
        _message = _currentWordIndex >= _words.length
            ? 'tashmee_success'.tr
            : 'tashmee_continue'.tr;
        _scrollToCurrentWord();
      } else if (result.hasPossibleError) {
        _lastUnexpectedWord = result.unexpectedWord;
      }
    });

    if (_currentWordIndex >= _words.length) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isListening = false;
        _soundLevel = 0;
      });
      _speechService.stop();
      return;
    }

    if (!madeProgress && result.hasPossibleError) {
      _scheduleErrorAlert();
    }
  }

  void _scheduleErrorAlert() {
    _errorTimer?.cancel();
    final wordIndexAtSchedule = _currentWordIndex;
    _errorTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted ||
          !_isListening ||
          _currentWordIndex != wordIndexAtSchedule ||
          _currentWordIndex >= _words.length) {
        return;
      }

      HapticFeedback.lightImpact();
      setState(() {
        _hasPossibleError = true;
        _errorCount++;
        _showHint = true;
        final expectedWord = _words[_currentWordIndex].text;
        final heardPart = _lastUnexpectedWord == null
            ? ''
            : 'tashmee_heard_word'.trParams({'word': _lastUnexpectedWord!});
        _message = 'tashmee_review_word'.trParams({
          'word': expectedWord,
          'heard': heardPart,
        });
      });
    });
  }


  void _resetAttempt() {
    _restartListenTimer?.cancel();
    _errorTimer?.cancel();
    _speechService.cancel();
    setState(() {
      _currentWordIndex = 0;
      _lastHeardText = '';
      _lastUnexpectedWord = null;
      _hasPossibleError = false;
      _showHint = false;
      _showFullText = false;
      _isListening = false;
      _soundLevel = 0;
      _message = 'tashmee_reset'.tr;
    });
    _scrollToCurrentWord();
  }

  double get _progress =>
      _words.isEmpty ? 0 : _currentWordIndex / _words.length;

  @override
  Widget build(BuildContext context) {
    final surahName = quran_text.getSurahNameArabic(_selectedSurah);
    final appController = Get.find<AppController>();

    return Obx(() {
      final isNight = appController.isNightMode.value;

      final screenBgColor = isNight ? Colors.black : const Color(0xFFEFECE5);
      final pageBgColor = isNight ? const Color(0xFF0F1B17) : const Color(0xFFFDFBF7);
      final pageOuterBorderColor = isNight ? const Color(0xFF1B3D31) : const Color(0xFF003527);
      final pageInnerBorderColor = isNight ? AppTheme.textVariantNight.withValues(alpha: 0.4) : AppTheme.primaryLight.withValues(alpha: 0.4);
      final bannerBgColor = isNight ? const Color(0xFF152A22) : AppTheme.primaryLight.withValues(alpha: 0.08);
      final bannerTextColor = isNight ? AppTheme.textVariantNight : AppTheme.primaryLight;
      final starColor = isNight ? AppTheme.textVariantNight : AppTheme.primaryLight;
      final goldColor = isNight ? AppTheme.textVariantNight : AppTheme.primaryLight;
      final textColor = isNight ? Colors.white : AppTheme.textLight;

      return Theme(
        data: ThemeData(
          brightness: isNight ? Brightness.dark : Brightness.light,
          useMaterial3: true,
        ).copyWith(
          scaffoldBackgroundColor: screenBgColor,
          colorScheme: isNight
              ? ColorScheme.dark(
                  primary: goldColor,
                  secondary: goldColor,
                  surface: screenBgColor,
                )
              : ColorScheme.light(
                  primary: const Color(0xFF003527),
                  secondary: goldColor,
                  surface: screenBgColor,
                ),
        ),
        child: Scaffold(
          backgroundColor: screenBgColor,
          appBar: AppBar(
            backgroundColor: screenBgColor,
            foregroundColor: isNight ? Colors.white : const Color(0xFF112E24),
            elevation: 0,
            titleSpacing: 0,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${'surah'.tr} $surahName',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Hafs',
                  ),
                ),
                Text(
                  'tashmee_stats'.trParams({
                    'start': '$_startVerse',
                    'end': '$_endVerse',
                    'current': '$_currentWordIndex',
                    'total': '${_words.length}',
                    'errors': '$_errorCount',
                  }),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.normal,
                    color: textColor.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'tashmee_select_range'.tr,
                onPressed: _showRangeSheet,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(3.h),
              child: SizedBox(
                height: 3.h,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: isNight ? Colors.white10 : Colors.black12,
                  color: goldColor,
                ),
              ),
            ),
          ),
          bottomNavigationBar: const AppBottomNav(currentIndex: 2),
          body: SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: pageBgColor,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: pageOuterBorderColor,
                            width: 4.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isNight ? 0.45 : 0.15),
                              blurRadius: 12.r,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            margin: EdgeInsets.all(4.r),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: pageInnerBorderColor,
                                width: 1.5.w,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildMushafSurahBanner(surahName, bannerBgColor, bannerTextColor, starColor, pageBgColor),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                    child: _MemorizationText(
                                      words: _words,
                                      revealedCount: _currentWordIndex,
                                      currentIndex: _currentWordIndex,
                                      showFullText: _showFullText,
                                      showHint: _showHint,
                                      hasError: _hasPossibleError,
                                      currentWordKey: _currentWordKey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _isListening
                          ? (_lastHeardText.trim().isNotEmpty ? '${'tashmee_heard'.tr}: $_lastHeardText' : 'tashmee_listening'.tr)
                          : _message,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isListening ? goldColor : textColor.withValues(alpha: 0.7),
                        fontSize: 13.sp,
                        fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _Controls(
                      isListening: _isListening,
                      soundLevel: _soundLevel,
                      onMicPressed: _toggleListening,
                      onRetryPressed: _resetAttempt,
                      onRevealPressed: () =>
                          setState(() => _showFullText = !_showFullText),
                      showFullText: _showFullText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  void _showRangeSheet() {
    var selectedSurah = _selectedSurah;
    var selectedStart = _startVerse;
    var selectedEnd = _endVerse;
    final isNight = Get.find<AppController>().isNightMode.value;
    final sheetBgColor = isNight ? AppTheme.backgroundNight : AppTheme.backgroundLight;
    final textColor = isNight ? Colors.white : AppTheme.textLight;
    final goldColor = isNight ? AppTheme.textVariantNight : AppTheme.primaryLight;
    final closeIconColor = isNight ? Colors.white70 : AppTheme.textVariantLight;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBgColor,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final verseCount = quran_text.getVerseCount(selectedSurah);
            selectedStart = selectedStart.clamp(1, verseCount).toInt();
            selectedEnd = selectedEnd.clamp(selectedStart, verseCount).toInt();

            return SafeArea(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    16,
                    18,
                    MediaQuery.viewInsetsOf(context).bottom + 22,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology, color: goldColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'tashmee_choose_range'.tr,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: Icon(Icons.close, color: closeIconColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SurahDropdown(
                        value: selectedSurah,
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            selectedSurah = value;
                            selectedStart = 1;
                            selectedEnd = quran_text.getVerseCount(value);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _VerseDropdown(
                        label: 'tashmee_start_label'.tr,
                        value: selectedStart,
                        start: 1,
                        end: verseCount,
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            selectedStart = value;
                            if (selectedEnd < value) selectedEnd = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _VerseDropdown(
                        label: 'tashmee_end_label'.tr,
                        value: selectedEnd,
                        start: selectedStart,
                        end: verseCount,
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => selectedEnd = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: goldColor,
                          foregroundColor: isNight ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedSurah = selectedSurah;
                            _startVerse = selectedStart;
                            _endVerse = selectedEnd;
                            _rebuildWords(resetProgress: true);
                          });
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: Text('tashmee_start_range'.tr),
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

  Widget _buildMushafSurahBanner(
    String surahName,
    Color bannerBgColor,
    Color bannerTextColor,
    Color starColor,
    Color pageBgColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bannerBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: starColor,
          width: 1.6,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.star_rounded, color: starColor, size: 12),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 1,
                    color: starColor.withValues(alpha: 0.4),
                  ),
                ),
                Icon(Icons.star_rounded, color: starColor, size: 12),
              ],
            ),
          ),
          Container(
            color: pageBgColor,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${'surah'.tr} $surahName',
              style: TextStyle(
                color: bannerTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Hafs',
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _MemorizationText extends StatelessWidget {
  const _MemorizationText({
    required this.words,
    required this.revealedCount,
    required this.currentIndex,
    required this.showFullText,
    required this.showHint,
    required this.hasError,
    required this.currentWordKey,
  });

  final List<_MemorizationWord> words;
  final int revealedCount;
  final int currentIndex;
  final bool showFullText;
  final bool showHint;
  final bool hasError;
  final GlobalKey currentWordKey;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Center(
        child: Text(
          'tashmee_no_words'.tr,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final appController = Get.find<AppController>();
    final isNight = appController.isNightMode.value;

    // تجميع مؤشرات نهاية كل آية (آخر index لكل verse)
    final Map<int, int> verseLastIndex = {};
    for (var i = 0; i < words.length; i++) {
      verseLastIndex[words[i].verse] = i;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 6,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var idx = 0; idx < words.length; idx++) ...[
              _buildWordWidget(idx, isNight),
              if (verseLastIndex[words[idx].verse] == idx) ...[
                const SizedBox(width: 6),
                _VerseCircle(verseNum: words[idx].verse),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWordWidget(int idx, bool isNight) {
    final word = words[idx];
    final revealed = idx < revealedCount || showFullText;
    final isCurrent = idx == currentIndex && !showFullText;
    final hinted = showHint && isCurrent;

    final inkColor = isNight ? const Color(0xFFD3E2DC) : const Color(0xFF112E24);
    final bronzeGold = isNight ? const Color(0xFFFFD57A) : const Color(0xFFC5A059);

    if (revealed) {
      return AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 250),
        style: TextStyle(
          color: inkColor,
          fontSize: 24,
          height: 1.8,
          fontWeight: FontWeight.w500,
          fontFamily: 'Hafs',
        ),
        child: Text(word.text),
      );
    } else if (isCurrent) {
      return Container(
        key: currentWordKey,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: hasError ? Colors.redAccent : bronzeGold,
              width: 2,
            ),
          ),
        ),
        child: Text(
          hinted
              ? '${word.text.characters.first}${' ' * (word.text.length - 1)}'
              : word.text,
          style: TextStyle(
            color: hinted
                ? (hasError
                      ? Colors.redAccent.withValues(alpha: 0.8)
                      : bronzeGold)
                : Colors.transparent,
            fontSize: 24,
            height: 1.8,
            fontWeight: FontWeight.w500,
            fontFamily: 'Hafs',
          ),
        ),
      );
    } else {
      return Text(
        word.text,
        style: const TextStyle(
          color: Colors.transparent,
          fontSize: 24,
          height: 1.8,
          fontWeight: FontWeight.w500,
          fontFamily: 'Hafs',
        ),
      );
    }
  }
}

/// دائرة رقم الآية البسيطة
class _VerseCircle extends StatelessWidget {
  const _VerseCircle({required this.verseNum});
  final int verseNum;

  static String _toArabicIndic(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((d) => digits[int.parse(d)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final isNight = appController.isNightMode.value;
    final bronzeGold = isNight ? const Color(0xFFEED2A0) : const Color(0xFFC5A059);
    final arabicNum = _toArabicIndic(verseNum);

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: bronzeGold.withValues(alpha: 0.6),
          width: 1.4,
        ),
        color: bronzeGold.withValues(alpha: 0.10),
      ),
      child: Text(
        arabicNum,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: bronzeGold,
          fontSize: arabicNum.length > 2 ? 9 : 11,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isListening,
    required this.soundLevel,
    required this.onMicPressed,
    required this.onRetryPressed,
    required this.onRevealPressed,
    required this.showFullText,
  });

  final bool isListening;
  final double soundLevel;
  final VoidCallback onMicPressed;
  final VoidCallback onRetryPressed;
  final VoidCallback onRevealPressed;
  final bool showFullText;

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final isNight = appController.isNightMode.value;

    final goldColor = isNight ? AppTheme.textVariantNight : AppTheme.primaryLight;
    final textColor = isNight ? Colors.white : AppTheme.textLight;

    // Normalize sound level from -2 to 10 to a scale of 0.0 to 1.0
    final normalizedLevel = ((soundLevel + 2) / 12).clamp(0.0, 1.0).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Retry Button
        IconButton(
          tooltip: 'tashmee_retry'.tr,
          onPressed: onRetryPressed,
          icon: Icon(
            Icons.replay_rounded,
            color: textColor.withValues(alpha: 0.85),
            size: 24.r,
          ),
        ),

        // Glow Mic Button
        GestureDetector(
          onTap: onMicPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 58.r,
            height: 58.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening ? Colors.redAccent : goldColor,
              boxShadow: [
                BoxShadow(
                  color: (isListening ? Colors.redAccent : goldColor).withValues(
                    alpha: isListening ? (0.2 + normalizedLevel * 0.4) : 0.25,
                  ),
                  blurRadius: isListening ? (8.r + normalizedLevel * 10.r) : 8.r,
                  spreadRadius: isListening ? (1.r + normalizedLevel * 6.r) : 2.r,
                ),
              ],
              border: Border.all(
                color: isNight ? Colors.black : Colors.white,
                width: 2.5.r,
              ),
            ),
            child: Icon(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: isListening || !isNight ? Colors.white : Colors.black,
              size: 28.r,
            ),
          ),
        ),

        // Reveal Button
        IconButton(
          tooltip: showFullText ? 'tashmee_hide_ayah'.tr : 'tashmee_show_ayah'.tr,
          onPressed: onRevealPressed,
          icon: Icon(
            showFullText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: textColor.withValues(alpha: 0.85),
            size: 24.r,
          ),
        ),
      ],
    );
  }
}

class _SurahDropdown extends StatelessWidget {
  const _SurahDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final isNight = appController.isNightMode.value;
    final textColor = isNight ? Colors.white : AppTheme.textLight;
    final dropdownColor = isNight ? const Color(0xFF151515) : Colors.white;

    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: dropdownColor,
      decoration: _dropdownDecoration('surah'.tr, isNight),
      style: TextStyle(color: textColor),
      items: List.generate(quran_text.totalSurahCount, (index) {
        final surah = index + 1;
        return DropdownMenuItem<int>(
          value: surah,
          child: Text(
            '$surah. ${quran_text.getSurahNameArabic(surah)}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor),
          ),
        );
      }),
      onChanged: onChanged,
    );
  }
}

class _VerseDropdown extends StatelessWidget {
  const _VerseDropdown({
    required this.label,
    required this.value,
    required this.start,
    required this.end,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int start;
  final int end;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final isNight = appController.isNightMode.value;
    final textColor = isNight ? Colors.white : AppTheme.textLight;
    final dropdownColor = isNight ? const Color(0xFF151515) : Colors.white;

    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: dropdownColor,
      decoration: _dropdownDecoration(label, isNight),
      style: TextStyle(color: textColor),
      items: List.generate(end - start + 1, (index) {
        final verse = start + index;
        return DropdownMenuItem<int>(
          value: verse,
          child: Text(
            '${'ayah'.tr} $verse',
            style: TextStyle(color: textColor),
          ),
        );
      }),
      onChanged: onChanged,
    );
  }
}

InputDecoration _dropdownDecoration(String label, bool isNight) {
  final goldColor = isNight ? AppTheme.textVariantNight : AppTheme.primaryLight;
  final borderColor = isNight ? Colors.white24 : Colors.black26;
  final labelColor = isNight ? Colors.white70 : AppTheme.textVariantLight;

  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: labelColor),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: borderColor),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: goldColor),
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

class _MemorizationWord {
  const _MemorizationWord({
    required this.text,
    required this.normalized,
    required this.verse,
  });

  final String text;
  final String normalized;
  final int verse;
}

class _MemorizationMatchResult {
  const _MemorizationMatchResult({
    required this.nextIndex,
    required this.hasPossibleError,
    this.unexpectedWord,
  });

  final int nextIndex;
  final bool hasPossibleError;
  final String? unexpectedWord;

  bool get isEmpty => nextIndex == 0 && !hasPossibleError;
}

class _MemorizationMatcher {
  const _MemorizationMatcher(this.words);

  final List<_MemorizationWord> words;

  _MemorizationMatchResult match({
    required int currentIndex,
    required int sessionStartWordIndex,
    required String recognizedText,
  }) {
    final heardWords = _splitHeardWords(recognizedText);
    if (heardWords.isEmpty) {
      return const _MemorizationMatchResult(
        nextIndex: 0,
        hasPossibleError: false,
      );
    }

    final matchedFromStart = _matchWordSequence(
      startWordIndex: 0,
      heard: heardWords,
    );
    final matchedFromSessionStart = _matchWordSequence(
      startWordIndex: sessionStartWordIndex,
      heard: heardWords,
    );
    final matchedFromCurrent = _matchWordSequence(
      startWordIndex: currentIndex,
      heard: heardWords,
    );
    final heardCompact = _compactArabic(recognizedText);
    final nextIndex = [
      currentIndex,
      matchedFromStart,
      sessionStartWordIndex + matchedFromSessionStart,
      currentIndex + matchedFromCurrent,
      _matchBasmalaPrefix(heardCompact),
    ].reduce((a, b) => a > b ? a : b);

    if (nextIndex > currentIndex) {
      return _MemorizationMatchResult(
        nextIndex: nextIndex,
        hasPossibleError: false,
      );
    }

    final revealedCompact = _compactArabic(
      words.take(currentIndex).map((word) => word.normalized).join(' '),
    );
    final repeatedOldSpeech =
        revealedCompact.isNotEmpty &&
        (revealedCompact.contains(heardCompact) ||
            heardCompact.contains(revealedCompact));

    return _MemorizationMatchResult(
      nextIndex: currentIndex,
      hasPossibleError: !repeatedOldSpeech,
      unexpectedWord: heardWords.isEmpty ? null : heardWords.last,
    );
  }

  int _matchWordSequence({
    required int startWordIndex,
    required List<String> heard,
  }) {
    if (startWordIndex >= words.length || heard.isEmpty) return 0;

    int expectedIdx = startWordIndex;
    int heardIdx = 0;
    int matchedCount = 0;

    while (expectedIdx < words.length && heardIdx < heard.length) {
      final expectedWord = words[expectedIdx].normalized;
      final heardWord = heard[heardIdx];

      // 1. Direct or phonetic similarity match (>= 75%)
      final sim = _wordSimilarity(expectedWord, heardWord);
      if (sim >= 0.75) {
        matchedCount = (expectedIdx - startWordIndex) + 1;
        expectedIdx++;
        heardIdx++;
        continue;
      }

      // 1b. Context-assisted: if next word also matches >= 75%, accept this word at >= 65%
      //     يعديها حتى لو نسبتها 65%+ لو اللى بعدها صح
      if (sim >= 0.65 &&
          heardIdx + 1 < heard.length &&
          expectedIdx + 1 < words.length) {
        final nextSim = _wordSimilarity(
          words[expectedIdx + 1].normalized,
          heard[heardIdx + 1],
        );
        if (nextSim >= 0.75) {
          matchedCount = (expectedIdx - startWordIndex) + 1;
          expectedIdx++;
          heardIdx++;
          continue;
        }
      }

      // 1c. Multi-word hear: single expected word heard as multiple heard words
      //     e.g. الم → [الف, لام, ميم] — mainly for disconnected letters
      final multiCount = _tryMultiWordHear(expectedWord, heard, heardIdx);
      if (multiCount > 0) {
        matchedCount = (expectedIdx - startWordIndex) + 1;
        expectedIdx++;
        heardIdx += multiCount;
        continue;
      }

      // 1d. Fast speech: 1 heard word covers 2+ expected words concatenated
      //     e.g. user says "بسمالله" as one word → matches [بسم, الله]
      final multiExpected = _tryMultiExpectedMatch(expectedIdx, heardWord);
      if (multiExpected > 0) {
        matchedCount = (expectedIdx - startWordIndex) + multiExpected;
        expectedIdx += multiExpected;
        heardIdx++;
        continue;
      }

      // 2. Try to recover by looking ahead up to 3 positions in expected and heard words.
      //    Handles all skips (deletions), extra words (insertions), and wrong words (substitutions).
      //    This allows bypassing 1-2 wrong words in the middle or even at the very start of the session!
      bool foundRecovery = false;
      // We prioritize smaller offsets (k + m) to find the closest match first
      for (int sum = 1; sum <= 5; sum++) {
        for (int k = 0; k <= 3; k++) {
          final m = sum - k;
          if (m < 0 || m > 3) continue;
          if (k == 0 && m == 0) continue;

          if (expectedIdx + k < words.length && heardIdx + m < heard.length) {
            final recoveryExpected = words[expectedIdx + k].normalized;
            final recoveryHeard = heard[heardIdx + m];
            if (_wordSimilarity(recoveryExpected, recoveryHeard) >= 0.75) {
              // Confirm anchor: the next word after the recovery point should also match reasonably
              bool confirm = true;
              if (expectedIdx + k + 1 < words.length && heardIdx + m + 1 < heard.length) {
                confirm = _wordSimilarity(
                  words[expectedIdx + k + 1].normalized,
                  heard[heardIdx + m + 1],
                ) >= 0.6;
              }
              if (confirm) {
                expectedIdx += k + 1;
                heardIdx += m + 1;
                matchedCount = (expectedIdx - startWordIndex);
                foundRecovery = true;
                break;
              }
            }
          }
        }
        if (foundRecovery) break;
      }
      if (foundRecovery) continue;

      break;
    }

    return matchedCount;
  }

  // 1 heard word covers 2+ expected words joined (fast speech concatenation)
  // e.g. heard "بسمالله" → matches expected [بسم, الله]
  int _tryMultiExpectedMatch(int expectedIdx, String heardWord) {
    for (int n = 2; n <= 3; n++) {
      if (expectedIdx + n > words.length) break;
      final joined = words
          .sublist(expectedIdx, expectedIdx + n)
          .map((w) => w.normalized)
          .join();
      if (_wordSimilarity(joined, heardWord) >= 0.75) return n;
      // Also try with _compactArabic for phonetic match
      final joinedCompact = _compactArabic(joined);
      final heardCompact = _compactArabic(heardWord);
      if (joinedCompact == heardCompact) return n;
      final dist = _levenshtein(joinedCompact, heardCompact);
      final maxLen = joinedCompact.length > heardCompact.length
          ? joinedCompact.length
          : heardCompact.length;
      if (maxLen > 0 && (1.0 - dist / maxLen) >= 0.75) return n;
    }
    return 0;
  }

  // Try matching a single expected word against 2-5 consecutive heard words joined together.
  // Handles cases like الم → [الف, لام, ميم], كهيعص → [كاف, ها, يا, عين, صاد]
  int _tryMultiWordHear(String expectedWord, List<String> heard, int startIdx) {
    for (int n = 2; n <= 5; n++) {
      if (startIdx + n > heard.length) break;
      final joined = heard.sublist(startIdx, startIdx + n).join();
      final joinedSpaced = heard.sublist(startIdx, startIdx + n).join(' ');
      if (_wordSimilarity(expectedWord, joined) >= 0.75) return n;
      if (_wordSimilarity(expectedWord, joinedSpaced) >= 0.75) return n;
    }
    return 0;
  }

  double _wordSimilarity(String expected, String heard) {
    if (expected == heard) return 1.0;

    // Apply recitation glitch normalizations
    final normExpected = _normalizeRecitationGlitch(expected);
    final normHeard = _normalizeRecitationGlitch(heard);
    if (normExpected == normHeard) return 1.0;

    // Special check for 2-letter expected words with lengthened heard vowels (e.g. من -> مان)
    if (normExpected.length == 2 && normHeard.length == 3 && normHeard[1] == 'ا') {
      final collapsedHeard = normHeard[0] + normHeard[2];
      if (normExpected == collapsedHeard) return 1.0;
    }

    final ph = _phoneticArabic(normHeard);
    final expectedVariants = _wordVariants(normExpected);

    for (final variant in expectedVariants) {
      final pv = _phoneticArabic(variant);
      if (pv == ph) return 1.0;

      // Check if variant and ph match after collapsing middle alif for 2-letter expected words
      if (pv.length == 2 && ph.length == 3 && ph[1] == 'ا') {
        final collapsedPh = ph[0] + ph[2];
        if (pv == collapsedPh) return 1.0;
      }

      final dist = _levenshtein(pv, ph);
      final maxLen = pv.length > ph.length ? pv.length : ph.length;
      if (maxLen > 0) {
        final sim = 1.0 - (dist / maxLen);
        if (sim >= 0.75) return sim;
      }
    }

    return 0.0;
  }

  // Normalizes common recitation errors like adding trailing vowel letters (e.g., الناسِ -> الناسي)
  // and missing/adding leading particles (e.g., والذين -> الذين, ويقول -> يقولو)
  String _normalizeRecitationGlitch(String word) {
    if (word.length <= 3) return word;

    String normalized = word;
    // Strip trailing 'وا'
    if (normalized.endsWith('وا')) {
      normalized = normalized.substring(0, normalized.length - 2);
    } else if (normalized.endsWith('ي') || normalized.endsWith('و') || normalized.endsWith('ا') || normalized.endsWith('ه')) {
      // Strip trailing 'ي', 'و', 'ا', 'ه'
      normalized = normalized.substring(0, normalized.length - 1);
    }

    // Strip leading particles (و, ف, ب, ل) if word length stays > 3
    if (normalized.length > 3) {
      for (final particle in ['و', 'f', 'ب', 'ل', 'ف']) {
        if (normalized.startsWith(particle)) {
          normalized = normalized.substring(1);
          break;
        }
      }
    }

    return normalized;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }

  int _matchBasmalaPrefix(String heardCompact) {
    if (!heardCompact.contains('بسمالله')) return 0;

    final expectedPrefix = words
        .take(4)
        .map((word) => _compactArabic(word.normalized))
        .join();
    if (expectedPrefix == 'بسماللهالرحمنالرحيم' &&
        heardCompact.contains('بسماللهالرحمنالرحيم')) {
      return 4;
    }

    final firstTwo = words
        .take(2)
        .map((word) => _compactArabic(word.normalized))
        .join();
    return firstTwo == 'بسمالله' ? 2 : 0;
  }

  Set<String> _wordVariants(String expectedCompact) {
    final variants = <String>{expectedCompact};

    // Check known Quranic disconnected letter combinations first
    final knownVariants = _knownDisconnectedLetterVariants(expectedCompact);
    if (knownVariants.isNotEmpty) {
      variants.addAll(knownVariants);
    } else {
      variants.addAll(_disconnectedLetterVariants(expectedCompact));
    }

    if (expectedCompact.startsWith('ال') && expectedCompact.length > 4) {
      variants.add(expectedCompact.substring(2));
    }
    // Strip leading Arabic particles (و ف ب ل) so مش لازم الـ recognizer يسمعهم
    if (expectedCompact.length > 2) {
      for (final particle in ['و', 'ف', 'ب', 'ل']) {
        if (expectedCompact.startsWith(particle)) {
          variants.add(expectedCompact.substring(1));
          break;
        }
      }
    }
    if (expectedCompact == 'بسم') variants.add('باسم');
    if (expectedCompact == 'الرحمن') variants.add('الرحمان');
    if (expectedCompact == 'ملك') variants.add('مالك');
    if (expectedCompact == 'مالك') variants.add('ملك');

    variants.removeWhere((variant) => variant.length < 2);
    return variants;
  }

  // Known Quranic disconnected letter sequences (الحروف المقطعة)
  // Keyed by normalized compact form -> list of possible heard pronunciations
  static const Map<String, List<String>> _knownSurahOpenings = {
    // Single letters
    'ص': ['صاد'],
    'ق': ['قاف'],
    'ن': ['نون'],
    'س': ['سين'],
    'ع': ['عين'],
    'م': ['ميم'],
    'ر': ['را', 'را'],
    // Two letters
    'طه': ['طاها', 'طا ها'],
    'طس': ['طاسين', 'طا سين'],
    'يس': ['يسين', 'يا سين', 'يا سن'],
    'حم': ['حاميم', 'حا ميم'],
    'الم': ['الف لام ميم', 'الف لام ميم'],
    'الر': ['الف لام را', 'الف لام را'],
    'المر': ['الف لام ميم را', 'الف لام ميم را'],
    'المص': ['الف لام ميم صاد', 'الف لام ميم صاد'],
    // Three letters
    'طسم': ['طاسينميم', 'طا سين ميم'],
    'عسق': ['عين سين قاف', 'عسق'],
    // Full combinations
    'كهيعص': ['كاف ها يا عين صاد', 'كاف هايا عين صاد', 'كهيعص'],
    'حمعسق': ['حاميم عين سين قاف', 'حا ميم عين سين قاف'],
  };

  Set<String> _knownDisconnectedLetterVariants(String expectedCompact) {
    final result = <String>{};
    // Try exact match
    final exact = _knownSurahOpenings[expectedCompact];
    if (exact != null) {
      for (final v in exact) {
        result.add(_compactArabic(v));
        // Also add the compact Arabic (no spaces)
        result.add(_compactArabic(v.replaceAll(' ', '')));
        // Also add individual phonetic variants
        result.add(_phoneticArabic(_compactArabic(v)));
      }
      return result;
    }
    return result;
  }

  Set<String> _disconnectedLetterVariants(String expectedCompact) {
    // All 14 letters that appear in Quranic disconnected openings
    const letters = {
      'ا': 'الف',
      'ل': 'لام',
      'م': 'ميم',
      'ص': 'صاد',
      'ر': 'را',
      'ك': 'كاف',
      'ه': 'ها',
      'ي': 'يا',
      'ع': 'عين',
      'ط': 'طا',
      'س': 'سين',
      'ح': 'حا',
      'ق': 'قاف',
      'ن': 'نون',
    };

    // Allow up to 6 chars (كهيعص has 5 letters)
    if (expectedCompact.isEmpty || expectedCompact.length > 6) {
      return const <String>{};
    }

    final names = <String>[];
    for (final char in expectedCompact.characters) {
      final name = letters[char];
      if (name == null) return const <String>{};
      names.add(name);
    }

    return {
      names.join(),
      names.join(' '),
      _phoneticArabic(names.join()),
      _phoneticArabic(names.join(' ')),
    }.map(_compactArabic).toSet();
  }
}

List<String> _splitQuranWords(String value) {
  return value
      .replaceAll(RegExp(r'[\u06DD۝۞﴾﴿٠-٩0-9]+'), ' ')
      .split(RegExp(r'\s+'))
      .map((word) => word.trim())
      .where((word) => word.isNotEmpty)
      .toList();
}

List<String> _splitHeardWords(String value) {
  final normalized = _normalizeArabic(value);
  if (normalized.isEmpty) return const <String>[];
  return normalized
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
}

String _compactArabic(String value) {
  final normalized = _normalizeArabic(value)
      .replaceAll('باسم', 'بسم')
      .replaceAll('الرحمان', 'الرحمن')
      .replaceAll('رحمان', 'رحمن')
      .replaceAll('مالكيوم', 'ملكيوم')
      .replaceAll('ذالك', 'ذلك')
      .replaceAll('هاذا', 'هذا')
      .replaceAll('لاكن', 'لكن')
      .replaceAll(' ', '');
  return _phoneticArabic(normalized);
}

String _phoneticArabic(String value) {
  return _normalizeArabic(value)
      .replaceAll('ط', 'ت')
      .replaceAll('ذ', 'ز')
      .replaceAll('ظ', 'ز')
      .replaceAll('ث', 'س')
      .replaceAll('ص', 'س')
      .replaceAll('ض', 'د')
      .replaceAll('ق', 'ك')
      .replaceAll('ء', 'ا');
}

String _normalizeArabic(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
      .replaceAll('\u0640', '')
      .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^\u0621-\u064A\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
