Future<void> playLocalAudio(String path) =>
    Future.error(UnsupportedError('Local audio playback is not supported.'));

Future<void> playRemoteAudio(String url) =>
    Future.error(UnsupportedError('Audio playback is not supported.'));

Future<void> disposeAudioPlayback() async {}
