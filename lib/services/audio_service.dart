import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:quran/quran.dart' as quran;
import 'package:get/get.dart';
import 'quran_service.dart';
import 'audio_download_service.dart';

class QuranAudioService {
  QuranAudioService() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        isPlaying.value = false;
        playingVerses.clear();
        _player.seek(Duration.zero, index: 0);
        _player.pause();
      } else {
        isPlaying.value = state.playing;
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final RxList<QuranVerse> playingVerses = <QuranVerse>[].obs;
  final RxBool isPlaying = false.obs;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  int? get currentIndex => _player.currentIndex;

  Future<void> play(String url, {QuranVerse? verse}) async {
    playingVerses.clear();
    final reciter = Get.find<QuranService>().getSelectedReciter();
    final reciterKey = reciter.key;
    final reciterName = reciter.name;

    final mediaItem = MediaItem(
      id: url,
      album: 'القرآن الكريم',
      title: verse != null
          ? 'سورة ${quran.getSurahNameArabic(verse.surah)} - آية ${verse.verse}'
          : 'تلاوة عذبة',
      artist: reciterName,
      artUri: Uri.parse('https://hayah.app/assets/icon.png'),
    );

    if (verse != null) {
      final downloadService = Get.find<AudioDownloadService>();
      final localFile = await downloadService.getLocalAudioFile(reciterKey, verse.surah, verse.verse);
      if (await localFile.exists() && (await localFile.length()) > 100) {
        await _player.setAudioSource(AudioSource.file(localFile.path, tag: mediaItem));
        await _player.play();
        return;
      }
    }
    await _player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: mediaItem));
    await _player.play();
  }

  Future<void> playPlaylist(List<String> urls, {List<QuranVerse> verses = const [], int repeatCount = 1}) async {
    if (urls.isEmpty) return;

    final downloadService = Get.find<AudioDownloadService>();
    final reciter = Get.find<QuranService>().getSelectedReciter();
    final reciterKey = reciter.key;
    final reciterName = reciter.name;

    final List<AudioSource> repeatedSources = [];
    final List<QuranVerse> repeatedVerses = [];

    final safeRepeatCount = repeatCount < 1 ? 1 : repeatCount;
    for (int r = 0; r < safeRepeatCount; r++) {
      for (int i = 0; i < urls.length; i++) {
        final url = urls[i];
        final verse = i < verses.length ? verses[i] : null;
        
        final mediaId = verse != null 
            ? '${verse.surah}_${verse.verse}_r${r}_$i'
            : 'verse_${r}_$i';

        final mediaItem = MediaItem(
          id: mediaId,
          album: 'القرآن الكريم',
          title: verse != null
              ? 'سورة ${quran.getSurahNameArabic(verse.surah)} - آية ${verse.verse}'
              : 'تلاوة عذبة',
          artist: reciterName,
          artUri: Uri.parse('https://hayah.app/assets/icon.png'),
        );

        if (verse != null) {
          final localFile = await downloadService.getLocalAudioFile(reciterKey, verse.surah, verse.verse);
          if (await localFile.exists() && (await localFile.length()) > 100) {
            repeatedSources.add(AudioSource.file(localFile.path, tag: mediaItem));
            continue;
          }
        }
        repeatedSources.add(AudioSource.uri(Uri.parse(url), tag: mediaItem));
      }
      repeatedVerses.addAll(verses);
    }

    playingVerses.assignAll(repeatedVerses);
    await _player.setAudioSources(
      repeatedSources,
      preload: true,
    );
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.play();

  Future<void> stop() {
    playingVerses.clear();
    return _player.stop();
  }

  Future<void> dispose() {
    playingVerses.clear();
    return _player.dispose();
  }
}
