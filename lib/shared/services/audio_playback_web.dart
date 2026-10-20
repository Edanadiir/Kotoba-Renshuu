import 'package:just_audio/just_audio.dart';

final AudioPlayer _player = AudioPlayer();

Future<void> playLocalAudio(String path) async {
  throw UnsupportedError('Local file playback is not available on web.');
}

Future<void> playRemoteAudio(String url) async {
  await _player.stop();
  await _player.setVolume(1.0);
  await _player.setUrl(url);
  await _player.play();
}

Future<void> disposeAudioPlayback() => _player.dispose();
