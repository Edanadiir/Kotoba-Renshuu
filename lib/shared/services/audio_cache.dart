import 'audio_cache_stub.dart'
    if (dart.library.io) 'audio_cache_io.dart'
    as implementation;

Future<String?> cacheAudioFile(String url, String cacheKey) =>
    implementation.cacheAudioFile(url, cacheKey);

Future<void> clearCachedAudioFiles() => implementation.clearCachedAudioFiles();
