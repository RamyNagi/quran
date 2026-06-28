import 'dart:async';

import 'package:get/get.dart';

import '../services/audio_service.dart';
import '../services/quran_service.dart';

class QuranController extends GetxController {
  QuranController(this._quranService, this._audioService);

  final QuranService _quranService;
  final QuranAudioService _audioService;

  final RxList<SurahSummary> surahs = <SurahSummary>[].obs;
  final RxList<QuranVerse> verses = <QuranVerse>[].obs;
  final RxList<QuranVerse> pageVerses = <QuranVerse>[].obs;
  final RxList<QuranVerse> searchResults = <QuranVerse>[].obs;
  final Rxn<QuranVerse> selectedVerse = Rxn<QuranVerse>();
  final RxInt selectedSurah = 1.obs;
  final RxInt selectedPage = 1.obs;
  final RxDouble fontScale = 1.0.obs;
  final RxString query = ''.obs;
  final RxString tafsir = ''.obs;
  final RxString meaning = ''.obs;
  final RxString selectedTafsirKey = ''.obs;
  final RxString selectedReciterKey = ''.obs;
  final RxBool isLoadingTafsir = false.obs;
  final RxBool isSearching = false.obs;
  final RxString errorMessage = ''.obs;
  int _searchToken = 0;

  @override
  void onInit() {
    super.onInit();
    surahs.assignAll(_quranService.getSurahs());
    fontScale.value = _quranService.getFontScale();
    selectedTafsirKey.value = _quranService.getSelectedTafsir().key;
    selectedReciterKey.value = _quranService.getSelectedReciter().key;
    final last = _quranService.getLastRead();
    openPage(last.page, initialVerse: last);
    unawaited(_quranService.preloadQuranAsync());
  }

  @override
  void onClose() {
    _audioService.dispose();
    super.onClose();
  }

  void openSurah(int surah, {int initialVerse = 1}) {
    selectedSurah.value = surah;
    verses.assignAll(_quranService.getVerses(surah));
    selectedVerse.value = null;
    for (final verse in verses) {
      if (verse.verse == initialVerse) {
        selectedVerse.value = verse;
        break;
      }
    }
    selectedVerse.value ??= verses.isNotEmpty ? verses.first : null;
    if (selectedVerse.value != null) {
      _quranService.saveLastRead(surah, selectedVerse.value!.verse);
      openPage(selectedVerse.value!.page, initialVerse: selectedVerse.value);
    }
    tafsir.value = '';
  }

  void selectVerse(QuranVerse verse) {
    selectedVerse.value = verse;
    selectedSurah.value = verse.surah;
    selectedPage.value = verse.page;
    _quranService.saveLastRead(verse.surah, verse.verse);
    tafsir.value = '';
    meaning.value = '';
  }

  void openPage(int page, {QuranVerse? initialVerse}) {
    selectedPage.value = page.clamp(1, 604).toInt();
    pageVerses.assignAll(_quranService.getPageVerses(selectedPage.value));
    if (pageVerses.isEmpty) return;
    selectedVerse.value = initialVerse ?? pageVerses.first;
    selectedSurah.value = selectedVerse.value!.surah;
    _quranService.saveLastRead(
      selectedVerse.value!.surah,
      selectedVerse.value!.verse,
    );
    tafsir.value = '';
    meaning.value = '';
  }

  void nextPage() => openPage(selectedPage.value + 1);

  void previousPage() => openPage(selectedPage.value - 1);

  String get currentMushafImageUrl =>
      _quranService.getMushafPageImageUrl(selectedPage.value);

  void showMeaning(QuranVerse verse) {
    selectVerse(verse);
    meaning.value = verse.translation;
  }

  Future<void> updateSearch(String value) async {
    final token = ++_searchToken;
    query.value = value;
    if (value.trim().isEmpty) {
      searchResults.clear();
      isSearching.value = false;
    } else {
      isSearching.value = true;
      final results = await _quranService.searchAsync(value);
      if (token == _searchToken) {
        searchResults.assignAll(results);
        isSearching.value = false;
      }
    }
  }

  Future<void> loadTafsir(QuranVerse verse) async {
    isLoadingTafsir.value = true;
    errorMessage.value = '';
    try {
      tafsir.value = await _quranService.getTafsir(verse.surah, verse.verse);
    } catch (_) {
      errorMessage.value = 'tafsir_unavailable'.tr;
    } finally {
      isLoadingTafsir.value = false;
    }
  }

  Future<void> playVerse(QuranVerse verse) async {
    errorMessage.value = '';
    try {
      await _audioService.play(verse.audioUrl);
    } catch (_) {
      errorMessage.value = 'audio_unavailable'.tr;
    }
  }

  Future<void> setTafsirEdition(String key) async {
    selectedTafsirKey.value = key;
    tafsir.value = '';
    await _quranService.setSelectedTafsir(key);
  }

  Future<void> setReciter(String key) async {
    selectedReciterKey.value = key;
    await _quranService.setSelectedReciter(key);
    openPage(selectedPage.value, initialVerse: selectedVerse.value);
  }

  List<TafsirEdition> get tafsirEditions => QuranService.tafsirEditions;

  List<QuranReciterOption> get reciters => QuranService.reciters;

  Future<void> toggleFavorite(QuranVerse verse) async {
    await _quranService.toggleFavorite(verse.id);
    selectedVerse.refresh();
  }

  Future<void> toggleBookmark(QuranVerse verse) async {
    await _quranService.toggleBookmark(verse.id);
    selectedVerse.refresh();
  }

  bool isFavorite(QuranVerse verse) => _quranService.isFavorite(verse.id);

  bool isBookmarked(QuranVerse verse) => _quranService.isBookmarked(verse.id);

  Future<void> setFontScale(double value) async {
    fontScale.value = value;
    await _quranService.setFontScale(value);
  }
}
