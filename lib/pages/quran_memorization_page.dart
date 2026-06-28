import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran_text;

import '../services/audio_service.dart';
import '../services/memorization_speech_service.dart';
import '../services/quran_service.dart';

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
  static const _goldColor = Color(0xFFD4AF37);

  late final QuranService _quranService;
  late final QuranAudioService _audioService;
  late final MemorizationSpeechService _speechService;

  late int _selectedSurah;
  late int _startVerse;
  late int _endVerse;
  late List<_MemorizationWord> _words;
  late _MemorizationMatcher _matcher;

  int _currentWordIndex = 0;
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
  String _message = 'اضغط على الميكروفون وابدأ التلاوة.';

  @override
  void initState() {
    super.initState();
    _quranService = Get.find<QuranService>();
    _audioService = Get.find<QuranAudioService>();
    _speechService = Get.find<MemorizationSpeechService>();
    _selectedSurah = widget.initialSurah;
    _startVerse = widget.initialStartVerse;
    _endVerse = widget.initialEndVerse;
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
    for (final verse in verses) {
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
      _message = 'اضغط على الميكروفون وابدأ التلاوة.';
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      _restartListenTimer?.cancel();
      _errorTimer?.cancel();
      setState(() {
        _isListening = false;
        _soundLevel = 0;
        _message = 'تم إيقاف الاستماع.';
      });
      await _speechService.stop();
      return;
    }

    setState(() {
      _isListening = true;
      _hasPossibleError = false;
      _lastUnexpectedWord = null;
      _showHint = false;
      _message = 'أستمع الآن...';
    });

    await _startListeningSession();
  }

  Future<void> _startListeningSession() async {
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
              ? 'اسمح للتطبيق باستخدام الميكروفون لتشغيل مساعد الحفظ.'
              : 'تعذر الاستماع الآن. تحقق من الاتصال أو حاول مرة أخرى.';
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
            ? 'أحسنت، اكتمل النطاق المحدد.'
            : 'تابع التلاوة من الكلمة المظللة.';
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
            : ' سمعته: $_lastUnexpectedWord.';
        _message = 'راجع الكلمة الحالية: $expectedWord.$heardPart';
      });
    });
  }

  Future<void> _playSelectedRange() async {
    final verses = _quranService.getSurahVersesRange(
      _selectedSurah,
      _startVerse,
      _endVerse,
    );
    final urls = verses
        .map((verse) => verse.audioUrl)
        .where((url) => url.trim().isNotEmpty)
        .toList();
    if (urls.isEmpty) return;
    await _audioService.playPlaylist(urls);
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
      _message = 'تمت إعادة المحاولة. ابدأ حين تكون جاهزاً.';
    });
  }

  double get _progress =>
      _words.isEmpty ? 0 : _currentWordIndex / _words.length;

  @override
  Widget build(BuildContext context) {
    final surahName = quran_text.getSurahNameArabic(_selectedSurah);

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: _goldColor,
          secondary: _goldColor,
          surface: Colors.black,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('مساعد الحفظ'),
          actions: [
            IconButton(
              tooltip: 'اختيار النطاق',
              onPressed: _showRangeSheet,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    surahName: surahName,
                    startVerse: _startVerse,
                    endVerse: _endVerse,
                    progress: _progress,
                    completedWords: _currentWordIndex,
                    totalWords: _words.length,
                    errorCount: _errorCount,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _MemorizationText(
                        words: _words,
                        revealedCount: _currentWordIndex,
                        currentIndex: _currentWordIndex,
                        showFullText: _showFullText,
                        showHint: _showHint,
                        hasError: _hasPossibleError,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_lastHeardText.trim().isNotEmpty)
                    Text(
                      'آخر ما سمعته: $_lastHeardText',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Controls(
                    isListening: _isListening,
                    soundLevel: _soundLevel,
                    onMicPressed: _toggleListening,
                    onReplayPressed: _playSelectedRange,
                    onRetryPressed: _resetAttempt,
                    onHintPressed: () => setState(() => _showHint = true),
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
  }

  void _showRangeSheet() {
    var selectedSurah = _selectedSurah;
    var selectedStart = _startVerse;
    var selectedEnd = _endVerse;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
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
                          const Icon(Icons.psychology, color: _goldColor),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'اختيار نطاق الحفظ',
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
                        label: 'بداية الحفظ',
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
                        label: 'نهاية الحفظ',
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
                          backgroundColor: _goldColor,
                          foregroundColor: Colors.black,
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
                        label: const Text('بدء هذا النطاق'),
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
}

class _Header extends StatelessWidget {
  const _Header({
    required this.surahName,
    required this.startVerse,
    required this.endVerse,
    required this.progress,
    required this.completedWords,
    required this.totalWords,
    required this.errorCount,
  });

  final String surahName;
  final int startVerse;
  final int endVerse;
  final double progress;
  final int completedWords;
  final int totalWords;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$surahName، الآيات $startVerse - $endVerse',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: Colors.white12,
              color: _QuranMemorizationPageState._goldColor,
            ),
            const SizedBox(height: 10),
            Text(
              '$completedWords / $totalWords كلمة • المراجعات $errorCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
          ],
        ),
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
  });

  final List<_MemorizationWord> words;
  final int revealedCount;
  final int currentIndex;
  final bool showFullText;
  final bool showHint;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد كلمات في النطاق المحدد.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Wrap(
      textDirection: TextDirection.rtl,
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 10,
      children: List.generate(words.length, (index) {
        final word = words[index];
        final revealed = index < revealedCount || showFullText;
        final isCurrent = index == currentIndex && !showFullText;
        final hinted = showHint && isCurrent;
        final text = revealed
            ? word.text
            : hinted
                ? '${word.text.characters.first}…'
                : '••••';
        final borderColor = hasError && isCurrent
            ? Colors.redAccent
            : isCurrent
                ? _QuranMemorizationPageState._goldColor
                : Colors.white.withValues(alpha: 0.10);
        final backgroundColor = revealed
            ? _QuranMemorizationPageState._goldColor.withValues(alpha: 0.18)
            : isCurrent
                ? _QuranMemorizationPageState._goldColor.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.06);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: hasError && isCurrent
                ? Colors.redAccent.withValues(alpha: 0.16)
                : backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: isCurrent ? 1.6 : 1),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: revealed || hinted || isCurrent
                  ? Colors.white
                  : Colors.white38,
              fontSize: 22,
              height: 1.4,
              fontWeight: revealed || isCurrent
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        );
      }),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isListening,
    required this.soundLevel,
    required this.onMicPressed,
    required this.onReplayPressed,
    required this.onRetryPressed,
    required this.onHintPressed,
    required this.onRevealPressed,
    required this.showFullText,
  });

  final bool isListening;
  final double soundLevel;
  final VoidCallback onMicPressed;
  final VoidCallback onReplayPressed;
  final VoidCallback onRetryPressed;
  final VoidCallback onHintPressed;
  final VoidCallback onRevealPressed;
  final bool showFullText;

  @override
  Widget build(BuildContext context) {
    final normalizedLevel = ((soundLevel + 2) / 12).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isListening) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalizedLevel,
              minHeight: 5,
              backgroundColor: Colors.white12,
              color: _QuranMemorizationPageState._goldColor,
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _QuranMemorizationPageState._goldColor,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          onPressed: onMicPressed,
          icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_rounded),
          label: Text(isListening ? 'إيقاف الاستماع' : 'ابدأ التلاوة'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: IconButton.filledTonal(
                tooltip: 'تكرار بصوت قارئ',
                onPressed: onReplayPressed,
                icon: const Icon(Icons.volume_up_rounded),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IconButton.filledTonal(
                tooltip: 'إعادة المحاولة',
                onPressed: onRetryPressed,
                icon: const Icon(Icons.replay_rounded),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IconButton.filledTonal(
                tooltip: 'تلميح',
                onPressed: onHintPressed,
                icon: const Icon(Icons.lightbulb_outline_rounded),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IconButton.filledTonal(
                tooltip: showFullText ? 'إخفاء الآية' : 'إظهار الآية',
                onPressed: onRevealPressed,
                icon: Icon(
                  showFullText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
          ],
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
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF151515),
      decoration: _dropdownDecoration('السورة'),
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
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF151515),
      decoration: _dropdownDecoration(label),
      style: const TextStyle(color: Colors.white),
      items: List.generate(end - start + 1, (index) {
        final verse = start + index;
        return DropdownMenuItem<int>(
          value: verse,
          child: Text('الآية $verse'),
        );
      }),
      onChanged: onChanged,
    );
  }
}

InputDecoration _dropdownDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.white24),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _QuranMemorizationPageState._goldColor),
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
    required String recognizedText,
  }) {
    final heardCompact = _compactArabic(recognizedText);
    final heardWords = _splitHeardWords(recognizedText);
    if (heardCompact.isEmpty || heardWords.isEmpty) {
      return const _MemorizationMatchResult(
        nextIndex: 0,
        hasPossibleError: false,
      );
    }

    final matchedFromStart = _matchForward(
      startWordIndex: 0,
      heardCompact: heardCompact,
    );
    final matchedFromCurrent = _matchForward(
      startWordIndex: currentIndex,
      heardCompact: heardCompact,
    );
    final nextIndex = [
      currentIndex,
      matchedFromStart,
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

  int _matchForward({
    required int startWordIndex,
    required String heardCompact,
  }) {
    if (startWordIndex >= words.length) return 0;

    var searchOffset = 0;
    var matchedCount = 0;

    for (var index = startWordIndex; index < words.length; index++) {
      final expected = _compactArabic(words[index].normalized);
      final match = _findExpectedWord(
        heardCompact: heardCompact,
        expectedCompact: expected,
        start: searchOffset,
      );

      if (match == null) break;

      matchedCount++;
      searchOffset = match.index + match.length;
    }

    return matchedCount;
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

  _CompactMatch? _findExpectedWord({
    required String heardCompact,
    required String expectedCompact,
    required int start,
  }) {
    for (final variant in _wordVariants(expectedCompact)) {
      final index = heardCompact.indexOf(variant, start);
      if (index >= 0) {
        return _CompactMatch(index: index, length: variant.length);
      }
    }

    return null;
  }

  Set<String> _wordVariants(String expectedCompact) {
    final variants = <String>{expectedCompact};

    variants.addAll(_disconnectedLetterVariants(expectedCompact));
    if (expectedCompact.startsWith('ال') && expectedCompact.length > 4) {
      variants.add(expectedCompact.substring(2));
    }
    if (expectedCompact == 'بسم') variants.add('باسم');
    if (expectedCompact == 'الرحمن') variants.add('الرحمان');
    if (expectedCompact == 'ملك') variants.add('مالك');
    if (expectedCompact == 'مالك') variants.add('ملك');

    variants.removeWhere((variant) => variant.length < 2);
    return variants;
  }

  Set<String> _disconnectedLetterVariants(String expectedCompact) {
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

    if (expectedCompact.length < 2 || expectedCompact.length > 5) {
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
    }.map(_compactArabic).toSet();
  }
}

class _CompactMatch {
  const _CompactMatch({required this.index, required this.length});

  final int index;
  final int length;
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
  return _normalizeArabic(value)
      .replaceAll('باسم', 'بسم')
      .replaceAll('الرحمان', 'الرحمن')
      .replaceAll('رحمان', 'رحمن')
      .replaceAll('مالكيوم', 'ملكيوم')
      .replaceAll('ذالك', 'ذلك')
      .replaceAll('هاذا', 'هذا')
      .replaceAll('لاكن', 'لكن')
      .replaceAll(' ', '');
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
