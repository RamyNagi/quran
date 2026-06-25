import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quran/quran.dart' as quran;

import 'storage_service.dart';

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

class QuranService {
  QuranService(this._storage);

  final StorageService _storage;

  static const _lastSurahKey = 'quran_last_surah';
  static const _lastVerseKey = 'quran_last_verse';
  static const _favoritesKey = 'quran_favorites';
  static const _bookmarksKey = 'quran_bookmarks';
  static const _fontScaleKey = 'quran_font_scale';
  static const _tafsirPrefix = 'tafsir_';

  List<SurahSummary> getSurahs() {
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

  QuranVerse getVerse(int surah, int verse) {
    return QuranVerse(
      surah: surah,
      verse: verse,
      text: quran.getVerse(surah, verse, verseEndSymbol: true),
      translation: quran.getVerseTranslation(surah, verse),
      audioUrl: quran.getAudioURLByVerse(surah, verse),
      page: quran.getPageNumber(surah, verse),
      juz: quran.getJuzNumber(surah, verse),
      isSajdah: quran.isSajdahVerse(surah, verse),
    );
  }

  List<QuranVerse> search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return <QuranVerse>[];
    final arabicResults = quran.searchWords([trimmed])['result'] as List;
    final translationResults =
        quran.searchWordsInTranslation([trimmed])['result'] as List;
    final seen = <String>{};
    final results = <QuranVerse>[];

    for (final item in [...arabicResults, ...translationResults]) {
      final surah = int.parse(item['surah'].toString());
      final verse = int.parse(item['verse'].toString());
      final id = '$surah:$verse';
      if (seen.add(id)) {
        results.add(getVerse(surah, verse));
      }
      if (results.length >= 80) break;
    }
    return results;
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

  double getFontScale() => _storage.read<double>(_fontScaleKey, 1.0);

  Future<void> setFontScale(double value) =>
      _storage.write(_fontScaleKey, value.clamp(0.8, 1.6).toDouble());

  bool isFavorite(String id) => _storage.readStringList(_favoritesKey).contains(id);

  bool isBookmarked(String id) =>
      _storage.readStringList(_bookmarksKey).contains(id);

  Future<void> toggleFavorite(String id) =>
      _toggleStringListValue(_favoritesKey, id);

  Future<void> toggleBookmark(String id) =>
      _toggleStringListValue(_bookmarksKey, id);

  List<String> getFavorites() => _storage.readStringList(_favoritesKey);

  List<String> getBookmarks() => _storage.readStringList(_bookmarksKey);

  Future<String> getTafsir(int surah, int verse) async {
    final key = '$_tafsirPrefix$surah:$verse';
    final cached = _storage.read<String>(key, '');
    if (cached.isNotEmpty) return cached;

    final url = Uri.parse('https://api.alquran.cloud/v1/ayah/$surah:$verse/en.asad');
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
