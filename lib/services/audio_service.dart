import 'package:just_audio/just_audio.dart';
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
    if (verse != null) {
      final downloadService = Get.find<AudioDownloadService>();
      final reciterKey = Get.find<QuranService>().getSelectedReciter().key;
      final localFile = await downloadService.getLocalAudioFile(reciterKey, verse.surah, verse.verse);
      if (await localFile.exists() && (await localFile.length()) > 100) {
        await _player.setAudioSource(AudioSource.file(localFile.path));
        await _player.play();
        return;
      }
    }
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> playPlaylist(List<String> urls, {List<QuranVerse> verses = const [], int repeatCount = 1}) async {
    if (urls.isEmpty) return;

    final downloadService = Get.find<AudioDownloadService>();
    final reciterKey = Get.find<QuranService>().getSelectedReciter().key;

    final List<AudioSource> singlePlaylistSources = [];
    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      if (i < verses.length) {
        final verse = verses[i];
        final localFile = await downloadService.getLocalAudioFile(reciterKey, verse.surah, verse.verse);
        if (await localFile.exists() && (await localFile.length()) > 100) {
          singlePlaylistSources.add(AudioSource.file(localFile.path));
          continue;
        }
      }
      singlePlaylistSources.add(AudioSource.uri(Uri.parse(url)));
    }

    final List<AudioSource> repeatedSources = [];
    final List<QuranVerse> repeatedVerses = [];

    final safeRepeatCount = repeatCount < 1 ? 1 : repeatCount;
    for (int r = 0; r < safeRepeatCount; r++) {
      repeatedSources.addAll(singlePlaylistSources);
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
