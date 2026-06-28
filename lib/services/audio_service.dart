import 'package:just_audio/just_audio.dart';

class QuranAudioService {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  bool get isPlaying => _player.playing;

  Future<void> play(String url) async {
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> playPlaylist(List<String> urls) async {
    if (urls.isEmpty) return;

    await _player.setAudioSources(
      urls.map((url) => AudioSource.uri(Uri.parse(url))).toList(),
      preload: true,
    );
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.play();

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
