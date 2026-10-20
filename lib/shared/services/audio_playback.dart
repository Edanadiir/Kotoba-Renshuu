import 'audio_playback_stub.dart'
    if (dart.library.io) 'audio_playback_io.dart'
    if (dart.library.js_interop) 'audio_playback_web.dart'
    as implementation;

Future<void> playLocalAudio(String path) => implementation.playLocalAudio(path);

Future<void> playRemoteAudio(String url) => implementation.playRemoteAudio(url);

Future<void> disposeAudioPlayback() => implementation.disposeAudioPlayback();
