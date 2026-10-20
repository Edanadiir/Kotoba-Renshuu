import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'app_storage_io.dart';

Future<String?> cacheAudioFile(String url, String cacheKey) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    debugPrint('[audio-cache] invalid URL: $url');
    return null;
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    debugPrint('[audio-cache] unsupported URL scheme: ${uri.scheme}');
    return null;
  }
  final directory = await appDataDirectory();
  final safeKey = cacheKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final file = File(
    '${directory.path}${Platform.pathSeparator}audio_$safeKey.mp3',
  );
  print('AUDIO CHECK: Target local cache path: ${file.path}');
  if (await file.exists() && await file.length() > 0) {
    debugPrint('[audio-cache] hit: ${file.path}');
    return _validatedLocalPath(file);
  }
  debugPrint('[audio-cache] download start: $url -> ${file.path}');
  try {
    final response = await Dio().download(url, file.path);
    final localPath = _validatedLocalPath(file);
    final length = file.existsSync() ? file.lengthSync() : 0;
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300 ||
        localPath == null) {
      if (file.existsSync()) await file.delete();
      throw StateError(
        'Invalid audio file: status=${response.statusCode}, '
        'exists=${file.existsSync()}, bytes=$length',
      );
    }
    debugPrint(
      '[audio-cache] download complete: status=${response.statusCode}, bytes=$length',
    );
    return localPath;
  } catch (error, stackTrace) {
    if (await file.exists()) await file.delete();
    debugPrint('[audio-cache] download failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}

String? _validatedLocalPath(File file) {
  final exists = file.existsSync();
  final length = exists ? file.lengthSync() : 0;
  print('AUDIO CHECK: File exists: $exists, File size:$length bytes');
  if (!exists || length <= 0) {
    print(
      'AUDIO LOG ERROR: Local file missing or empty: ${file.path} ($length bytes)',
    );
    return null;
  }
  print('AUDIO LOG: Local file ready: ${file.path}(size:$length bytes)');
  return file.path;
}

Future<void> clearCachedAudioFiles() async {
  await deleteCachedFiles();
}
