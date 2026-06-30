import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import 'quran_service.dart';

class QuranAudioService {
  QuranAudioService() {
    _player.playingStream.listen((playing) {
      isPlaying.value = playing;
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final RxList<QuranVerse> playingVerses = <QuranVerse>[].obs;
  final RxBool isPlaying = false.obs;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  int? get currentIndex => _player.currentIndex;

  Future<void> play(String url) async {
    playingVerses.clear();
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> playPlaylist(List<String> urls, [List<QuranVerse> verses = const []]) async {
    if (urls.isEmpty) return;

    playingVerses.assignAll(verses);
    await _player.setAudioSources(
      urls.map((url) => AudioSource.uri(Uri.parse(url))).toList(),
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
