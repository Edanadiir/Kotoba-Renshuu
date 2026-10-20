import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

const appFolderName = 'Wanikani Renshuu';

Directory? _directory;

/// `Documents\Wanikani Renshuu`; every file the app persists lives here.
Future<Directory> appDataDirectory() async {
  final cached = _directory;
  if (cached != null) return cached;
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory(
    '${documents.path}${Platform.pathSeparator}$appFolderName',
  );
  await directory.create(recursive: true);
  return _directory = directory;
}

Future<void> initAppStorage() async {
  if (Hive.isBoxOpen('sync_meta')) return;
  final directory = await appDataDirectory();
  await _migrateLegacyFiles(directory);
  Hive.init(directory.path);
}

/// Earlier versions stored the Hive files directly in Documents.
Future<void> _migrateLegacyFiles(Directory target) async {
  final documents = await getApplicationDocumentsDirectory();
  for (final name in const [
    'subjects',
    'assignments',
    'sync_meta',
    'token_fallback',
  ]) {
    final old = File('${documents.path}${Platform.pathSeparator}$name.hive');
    final next = File('${target.path}${Platform.pathSeparator}$name.hive');
    if (!await old.exists() || await next.exists()) continue;
    try {
      await old.rename(next.path);
      final lock = File('${documents.path}${Platform.pathSeparator}$name.lock');
      if (await lock.exists()) await lock.delete();
    } on FileSystemException {
      // Leave the legacy file in place; the app just starts with fresh data.
    }
  }
}

final _audioFile = RegExp(r'^audio_.*\.[a-zA-Z0-9]+$');

Future<void> deleteCachedFiles() async {
  final directory = await appDataDirectory();
  await for (final entry in directory.list(followLinks: false)) {
    if (entry is File && _audioFile.hasMatch(entry.uri.pathSegments.last)) {
      try {
        await entry.delete();
      } on FileSystemException {
        // Ignore files that are in use.
      }
    }
  }
}
