import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quran/quran.dart' as quran;

import 'storage_service.dart';

class TafsirEdition {
  const TafsirEdition({required this.key, required this.name});

  final String key;
  final String name;
}

class QuranReciterOption {
  const QuranReciterOption({
    required this.key,
    required this.name,
    this.reciter,
    this.everyAyahFolder,
  });

  final String key;
  final String name;
  final quran.Reciter? reciter;
  final String? everyAyahFolder;
}

class SurahSummary {
  const SurahSummary({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.verseCount,
    required this.revelationPlace,
  });

  final int number;
  final String nameArabic;
  final String nameEnglish;
  final int verseCount;
  final String revelationPlace;
}

class QuranVerse {
  const QuranVerse({
    required this.surah,
    required this.verse,
    required this.text,
    required this.translation,
    required this.audioUrl,
    required this.page,
    required this.juz,
    required this.isSajdah,
  });

  final int surah;
  final int verse;
  final String text;
  final String translation;
  final String audioUrl;
  final int page;
  final int juz;
  final bool isSajdah;

  String get id => '$surah:$verse';
}

class DailyAyah {
  const DailyAyah({required this.verse, required this.reference});

  final QuranVerse verse;
  final String reference;
}

class QuranService {
  QuranService(this._storage);

  final StorageService _storage;
  final Map<String, QuranVerse> _verseCache = {};
  final Map<int, List<QuranVerse>> _pageCache = {};
  List<SurahSummary> _surahCache = const [];
  bool _isPreloaded = false;
  bool _isPreloading = false;
  Future<void>? _preloadFuture;

  static const _lastSurahKey = 'quran_last_surah';
  static const _lastVerseKey = 'quran_last_verse';
  static const _readingMarkSurahKey = 'quran_reading_mark_surah';
  static const _readingMarkVerseKey = 'quran_reading_mark_verse';
  static const _favoritesKey = 'quran_favorites';
  static const _bookmarksKey = 'quran_bookmarks';
  static const _fontScaleKey = 'quran_font_scale';
  static const _selectedTafsirKey = 'quran_selected_tafsir';
  static const _selectedReciterKey = 'quran_selected_reciter';
  static const _tafsirPrefix = 'tafsir_';

  static const List<TafsirEdition> tafsirEditions = [
    TafsirEdition(key: 'ar.muyassar', name: 'التفسير الميسر'),
    TafsirEdition(key: 'ar.jalalayn', name: 'تفسير الجلالين'),
    TafsirEdition(key: 'en.asad', name: 'Muhammad Asad'),
  ];

  static const List<QuranReciterOption> reciters = [
    QuranReciterOption(
      key: 'ar.alafasy',
      name: 'مشاري راشد العفاسي',
      reciter: quran.Reciter.arAlafasy,
    ),
    QuranReciterOption(
      key: 'ar.husary',
      name: 'محمود خليل الحصري',
      reciter: quran.Reciter.arHusary,
    ),
    QuranReciterOption(
      key: 'ar.ahmedajamy',
      name: 'أحمد بن علي العجمي',
      reciter: quran.Reciter.arAhmedAjamy,
    ),
    QuranReciterOption(
      key: 'ar.hudhaify',
      name: 'علي بن عبد الرحمن الحذيفي',
      reciter: quran.Reciter.arHudhaify,
    ),
    QuranReciterOption(
      key: 'ar.mahermuaiqly',
      name: 'ماهر المعيقلي',
      reciter: quran.Reciter.arMaherMuaiqly,
    ),
    QuranReciterOption(
      key: 'ar.muhammadayyoub',
      name: 'محمد أيوب',
      reciter: quran.Reciter.arMuhammadAyyoub,
    ),
    QuranReciterOption(
      key: 'ar.muhammadjibreel',
      name: 'محمد جبريل',
      reciter: quran.Reciter.arMuhammadJibreel,
    ),
    QuranReciterOption(
      key: 'ar.minshawi',
      name: 'محمد صديق المنشاوي',
      reciter: quran.Reciter.arMinshawi,
    ),
    QuranReciterOption(
      key: 'ar.shaatree',
      name: 'أبو بكر الشاطري',
      reciter: quran.Reciter.arShaatree,
    ),
    // القراء الجدد المضافين من EveryAyah
    QuranReciterOption(
      key: 'ar.sudais',
      name: 'عبد الرحمن السديس',
      everyAyahFolder: 'Abdurrahmaan_As-Sudais_192kbps',
    ),
    QuranReciterOption(
      key: 'ar.shuraym',
      name: 'سعود الشريم',
      everyAyahFolder: 'Saood_ash-Shuraym_128kbps',
    ),
    QuranReciterOption(
      key: 'ar.bukhatir',
      name: 'صلاح بو خاطر',
      everyAyahFolder: 'Salaah_AbdulRahman_Bukhatir_128kbps',
    ),
    QuranReciterOption(
      key: 'ar.basitmurattal',
      name: 'عبد الباسط عبد الصمد (مرتل)',
      everyAyahFolder: 'Abdul_Basit_Murattal_192kbps',
    ),
    QuranReciterOption(
      key: 'ar.basitmujawwad',
      name: 'عبد الباسط عبد الصمد (مجود)',
      everyAyahFolder: 'Abdul_Basit_Mujawwad_128kbps',
    ),
    QuranReciterOption(
      key: 'ar.saadghamidi',
      name: 'سعد الغامدي',
      everyAyahFolder: 'Saad_Al_Ghamidi_128kbps',
    ),
    QuranReciterOption(
      key: 'ar.yasseraddussari',
      name: 'ياسر الدوسري',
      everyAyahFolder: 'Yasser_Ad-Dussary_128kbps',
    ),
    QuranReciterOption(
      key: 'ar.nasserqatami',
      name: 'ناصر القطامي',
      everyAyahFolder: 'Nasser_Alqatami_128kbps',
    ),
    QuranReciterOption(
      key: 'ar.faresabbad',
      name: 'فارس عباد',
      everyAyahFolder: 'Fares_Abbad_64kbps',
    ),
    QuranReciterOption(
      key: 'ar.hanirifai',
      name: 'هاني الرفاعي',
      everyAyahFolder: 'Hani_Rifai_192kbps',
    ),
  ];

  void preloadQuran({bool force = false}) {
    if (_isPreloading && !force) return;
    if (_isPreloaded && !force) return;

    _verseCache.clear();
    _pageCache.clear();
    _surahCache = _buildSurahs();
    final reciterOption = getSelectedReciter();

    for (var page = 1; page <= quran.totalPagesCount; page++) {
      final pageVerses = <QuranVerse>[];
      final pageData = quran.getPageData(page);
      for (final entry in pageData) {
        final surah = int.parse(entry['surah'].toString());
        final start = int.parse(entry['start'].toString());
        final end = int.parse(entry['end'].toString());
        for (var verse = start; verse <= end; verse++) {
          final quranVerse = _buildVerse(
            surah,
            verse,
            page: page,
            reciterOption: reciterOption,
          );
          _verseCache[quranVerse.id] = quranVerse;
          pageVerses.add(quranVerse);
        }
      }
      _pageCache[page] = pageVerses;
    }

    _isPreloaded = true;
    _isPreloading = false;
  }

  Future<void> preloadQuranAsync({bool force = false}) {
    if (_isPreloading && !force) {
      return _preloadFuture ?? Future<void>.value();
    }
    if (_isPreloaded && !force) return Future<void>.value();

    _preloadFuture = _preloadQuranAsync();
    return _preloadFuture!;
  }

  Future<void> _preloadQuranAsync() async {
    _isPreloading = true;
    _isPreloaded = false;
    try {
      _verseCache.clear();
      _pageCache.clear();
      _surahCache = _buildSurahs();
      final reciterOption = getSelectedReciter();

      for (var page = 1; page <= quran.totalPagesCount; page++) {
        _pageCache[page] = _buildPageVerses(page, reciterOption: reciterOption);
        for (final verse in _pageCache[page]!) {
          _verseCache[verse.id] = verse;
        }

        if (page % 12 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      _isPreloaded = true;
    } finally {
      _isPreloading = false;
      _preloadFuture = null;
    }
  }

  List<SurahSummary> getSurahs() {
    if (_surahCache.isEmpty) {
      _surahCache = _buildSurahs();
    }
    return List.unmodifiable(_surahCache);
  }

  List<SurahSummary> _buildSurahs() {
    return List.generate(quran.totalSurahCount, (index) {
      final number = index + 1;
      return SurahSummary(
        number: number,
        nameArabic: quran.getSurahNameArabic(number),
        nameEnglish: quran.getSurahNameEnglish(number),
        verseCount: quran.getVerseCount(number),
        revelationPlace: quran.getPlaceOfRevelation(number),
      );
    });
  }

  List<QuranVerse> getVerses(int surah) {
    final count = quran.getVerseCount(surah);
    return List.generate(count, (index) => getVerse(surah, index + 1));
  }

  List<QuranVerse> getSurahVersesFrom(int surah, int startVerse) {
    final safeSurah = surah.clamp(1, quran.totalSurahCount).toInt();
    final verseCount = quran.getVerseCount(safeSurah);
    final safeStart = startVerse.clamp(1, verseCount).toInt();

    return List.generate(
      verseCount - safeStart + 1,
      (index) => getVerse(safeSurah, safeStart + index),
    );
  }

  List<QuranVerse> getSurahVersesRange(
    int surah,
    int startVerse,
    int endVerse,
  ) {
    final safeSurah = surah.clamp(1, quran.totalSurahCount).toInt();
    final verseCount = quran.getVerseCount(safeSurah);
    final safeStart = startVerse.clamp(1, verseCount).toInt();
    final safeEnd = endVerse.clamp(safeStart, verseCount).toInt();

    return List.generate(
      safeEnd - safeStart + 1,
      (index) => getVerse(safeSurah, safeStart + index),
    );
  }

  QuranVerse getVerse(int surah, int verse) {
    if (_isPreloaded) {
      final cached = _verseCache['$surah:$verse'];
      if (cached != null) return cached;
    }
    return _buildVerse(surah, verse);
  }

  DailyAyah getAyahOfDay(DateTime date, {required bool arabicReference}) {
    final daysSinceEpoch = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(2024)).inDays;
    final globalVerseIndex =
        ((daysSinceEpoch * 37) % quran.totalVerseCount) + 1;
    var cursor = globalVerseIndex;

    for (var surah = 1; surah <= quran.totalSurahCount; surah++) {
      final verseCount = quran.getVerseCount(surah);
      if (cursor <= verseCount) {
        final verse = getVerse(surah, cursor);
        final surahName = arabicReference
            ? quran.getSurahNameArabic(surah)
            : quran.getSurahNameEnglish(surah);
        return DailyAyah(
          verse: verse,
          reference: '$surahName - $surah:$cursor',
        );
      }
      cursor -= verseCount;
    }

    final verse = getVerse(1, 1);
    return DailyAyah(
      verse: verse,
      reference: arabicReference ? 'الفاتحة - 1:1' : 'Al-Faatiha - 1:1',
    );
  }

  QuranVerse _buildVerse(
    int surah,
    int verse, {
    int? page,
    QuranReciterOption? reciterOption,
  }) {
    final selectedOption = reciterOption ?? getSelectedReciter();
    final String audioUrl;

    if (selectedOption.everyAyahFolder != null) {
      final sStr = surah.toString().padLeft(3, '0');
      final vStr = verse.toString().padLeft(3, '0');
      audioUrl = 'https://everyayah.com/data/${selectedOption.everyAyahFolder}/$sStr$vStr.mp3';
    } else {
      audioUrl = quran.getAudioURLByVerse(
        surah,
        verse,
        reciter: selectedOption.reciter ?? quran.Reciter.arAlafasy,
      );
    }

    return QuranVerse(
      surah: surah,
      verse: verse,
      text: quran.getVerse(surah, verse, verseEndSymbol: true),
      translation: quran.getVerseTranslation(surah, verse),
      audioUrl: audioUrl,
      page: page ?? quran.getPageNumber(surah, verse),
      juz: quran.getJuzNumber(surah, verse),
      isSajdah: quran.isSajdahVerse(surah, verse),
    );
  }

  List<QuranVerse> getPageVerses(int page) {
    final cached = _pageCache[page];
    if (cached != null) return List.unmodifiable(cached);

    final verses = _buildPageVerses(page);
    _pageCache[page] = verses;
    for (final verse in verses) {
      _verseCache[verse.id] = verse;
    }
    return List.unmodifiable(verses);
  }

  List<QuranVerse> _buildPageVerses(int page, {QuranReciterOption? reciterOption}) {
    final pageData = quran.getPageData(page);
    final verses = <QuranVerse>[];
    for (final entry in pageData) {
      final surah = int.parse(entry['surah'].toString());
      final start = int.parse(entry['start'].toString());
      final end = int.parse(entry['end'].toString());
      for (var verse = start; verse <= end; verse++) {
        verses.add(_buildVerse(surah, verse, page: page, reciterOption: reciterOption));
      }
    }
    return verses;
  }

  String getMushafPageImageUrl(int page) {
    final safePage = page.clamp(1, quran.totalPagesCount).toInt();
    return 'https://quran.ksu.edu.sa/png_big/$safePage.png';
  }

  List<QuranVerse> search(String query) {
    if (!_isPreloaded && !_isPreloading) {
      preloadQuran();
    }
    final normalizedQuery = _normalizeArabicSearch(query);
    if (normalizedQuery.isEmpty) return <QuranVerse>[];
    final results = <QuranVerse>[];

    for (final verse in _verseCache.values) {
      final normalizedText = _normalizeArabicSearch(verse.text);
      if (normalizedText.contains(normalizedQuery)) {
        results.add(verse);
      }
    }
    return results;
  }

  Future<List<QuranVerse>> searchAsync(String query) async {
    if (!_isPreloaded) {
      await preloadQuranAsync();
    }

    final normalizedQuery = _normalizeArabicSearch(query);
    if (normalizedQuery.isEmpty) return <QuranVerse>[];

    final results = <QuranVerse>[];
    var index = 0;
    for (final verse in _verseCache.values) {
      final normalizedText = _normalizeArabicSearch(verse.text);
      if (normalizedText.contains(normalizedQuery)) {
        results.add(verse);
      }

      index++;
      if (index % 350 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return results;
  }

  String _normalizeArabicSearch(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll(RegExp('[\u0625\u0623\u0622\u0671]'), '\u0627')
        .replaceAll('\u0649', '\u064A')
        .replaceAll('\u0624', '\u0648')
        .replaceAll('\u0626', '\u064A')
        .replaceAll('\u0629', '\u0647')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  QuranVerse getLastRead() {
    return getVerse(
      _storage.read<int>(_lastSurahKey, 1),
      _storage.read<int>(_lastVerseKey, 1),
    );
  }

  Future<void> saveLastRead(int surah, int verse) async {
    await _storage.write(_lastSurahKey, surah);
    await _storage.write(_lastVerseKey, verse);
  }

  Future<void> saveLastReadPage(int page) async {
    final verses = getPageVerses(page);
    if (verses.isEmpty) return;
    await saveLastRead(verses.first.surah, verses.first.verse);
  }

  QuranVerse? getReadingMark() {
    if (!_storage.contains(_readingMarkSurahKey) ||
        !_storage.contains(_readingMarkVerseKey)) {
      return null;
    }
    return getVerse(
      _storage.read<int>(_readingMarkSurahKey, 1),
      _storage.read<int>(_readingMarkVerseKey, 1),
    );
  }

  Future<void> saveReadingMark(int surah, int verse) async {
    final safeSurah = surah.clamp(1, quran.totalSurahCount).toInt();
    final safeVerse = verse.clamp(1, quran.getVerseCount(safeSurah)).toInt();
    await _storage.write(_readingMarkSurahKey, safeSurah);
    await _storage.write(_readingMarkVerseKey, safeVerse);
  }

  Future<void> saveReadingMarkPage(int page) async {
    final verses = getPageVerses(page);
    if (verses.isEmpty) return;
    await saveReadingMark(verses.first.surah, verses.first.verse);
  }

  double getFontScale() => _storage.read<double>(_fontScaleKey, 1.0);

  Future<void> setFontScale(double value) =>
      _storage.write(_fontScaleKey, value.clamp(0.8, 1.6).toDouble());

  TafsirEdition getSelectedTafsir() {
    final key = _storage.read<String>(
      _selectedTafsirKey,
      tafsirEditions.first.key,
    );
    return tafsirEditions.firstWhere(
      (edition) => edition.key == key,
      orElse: () => tafsirEditions.first,
    );
  }

  Future<void> setSelectedTafsir(String key) =>
      _storage.write(_selectedTafsirKey, key);

  QuranReciterOption getSelectedReciter() {
    final key = _storage.read<String>(_selectedReciterKey, reciters.first.key);
    return reciters.firstWhere(
      (reciter) => reciter.key == key,
      orElse: () => reciters.first,
    );
  }

  Future<void> setSelectedReciter(String key) async {
    await _storage.write(_selectedReciterKey, key);
    await preloadQuranAsync(force: true);
  }

  int getSelectedAudioSurahOrDefault(int fallback) => _storage.read<int>('quran_selected_audio_surah', fallback);
  Future<void> setSelectedAudioSurah(int surah) => _storage.write('quran_selected_audio_surah', surah);

  int getSelectedAudioStartVerseOrDefault(int fallback) => _storage.read<int>('quran_selected_audio_start_verse', fallback);
  Future<void> setSelectedAudioStartVerse(int verse) => _storage.write('quran_selected_audio_start_verse', verse);

  int getSelectedAudioEndVerseOrDefault(int fallback) => _storage.read<int>('quran_selected_audio_end_verse', fallback);
  Future<void> setSelectedAudioEndVerse(int verse) => _storage.write('quran_selected_audio_end_verse', verse);

  int getSelectedAudioRepeatCount() => _storage.read<int>('quran_selected_audio_repeat_count', 1);
  Future<void> setSelectedAudioRepeatCount(int count) => _storage.write('quran_selected_audio_repeat_count', count);

  bool isFavorite(String id) =>
      _storage.readStringList(_favoritesKey).contains(id);

  bool isBookmarked(String id) =>
      _storage.readStringList(_bookmarksKey).contains(id);

  Future<void> toggleFavorite(String id) =>
      _toggleStringListValue(_favoritesKey, id);

  Future<void> toggleBookmark(String id) =>
      _toggleStringListValue(_bookmarksKey, id);

  List<String> getFavorites() => _storage.readStringList(_favoritesKey);

  List<String> getBookmarks() => _storage.readStringList(_bookmarksKey);

  Future<String> getTafsir(int surah, int verse) async {
    final edition = getSelectedTafsir();
    return getTafsirForEdition(surah, verse, edition.key);
  }

  Future<String> getTafsirForEdition(
    int surah,
    int verse,
    String editionKey,
  ) async {
    final key = '$_tafsirPrefix$editionKey:$surah:$verse';
    final cached = _storage.read<String>(key, '');
    if (cached.isNotEmpty) return cached;

    final url = Uri.parse(
      'https://api.alquran.cloud/v1/ayah/$surah:$verse/$editionKey',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Tafsir service unavailable');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final tafsir = data?['text']?.toString() ?? '';
    if (tafsir.isEmpty) throw Exception('No tafsir found');
    await _storage.write(key, tafsir);
    return tafsir;
  }

  Future<void> _toggleStringListValue(String key, String value) async {
    final values = _storage.readStringList(key);
    if (values.contains(value)) {
      values.remove(value);
    } else {
      values.add(value);
    }
    await _storage.writeStringList(key, values);
  }
}
