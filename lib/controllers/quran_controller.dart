import 'package:get/get.dart';

import '../services/audio_service.dart';
import '../services/quran_service.dart';

class QuranController extends GetxController {
  QuranController(this._quranService, this._audioService);

  final QuranService _quranService;
  final QuranAudioService _audioService;

  final RxList<SurahSummary> surahs = <SurahSummary>[].obs;
  final RxList<QuranVerse> verses = <QuranVerse>[].obs;
  final RxList<QuranVerse> searchResults = <QuranVerse>[].obs;
  final Rxn<QuranVerse> selectedVerse = Rxn<QuranVerse>();
  final RxInt selectedSurah = 1.obs;
  final RxDouble fontScale = 1.0.obs;
  final RxString query = ''.obs;
  final RxString tafsir = ''.obs;
  final RxBool isLoadingTafsir = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    surahs.assignAll(_quranService.getSurahs());
    fontScale.value = _quranService.getFontScale();
    final last = _quranService.getLastRead();
    openSurah(last.surah, initialVerse: last.verse);
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
    }
    tafsir.value = '';
  }

  void selectVerse(QuranVerse verse) {
    selectedVerse.value = verse;
    _quranService.saveLastRead(verse.surah, verse.verse);
    tafsir.value = '';
  }

  void updateSearch(String value) {
    query.value = value;
    if (value.trim().isEmpty) {
      searchResults.clear();
    } else {
      searchResults.assignAll(_quranService.search(value));
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
