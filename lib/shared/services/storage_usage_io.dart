import 'dart:io';

import 'app_storage_io.dart';
import 'storage_usage_types.dart';

final _hiveFile = RegExp(r'\.(hive|hivec|lock)$', caseSensitive: false);
final _audioFile = RegExp(r'^audio_.*\.[a-zA-Z0-9]+$');

/// Sums the sizes of files in [directory] whose names match [pattern].
/// Only the top level is scanned, so the user's other documents are never
/// walked or counted.
Future<int> getDirectorySize(Directory directory, RegExp pattern) async {
  if (!await directory.exists()) return 0;
  var total = 0;
  try {
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (!pattern.hasMatch(name)) continue;
      try {
        total += await entry.length();
      } on FileSystemException {
        // File removed while scanning.
      }
    }
  } on FileSystemException {
    // Unreadable directory counts as empty.
  }
  return total;
}

Future<StorageUsage> measureStorageUsage() async {
  final directory = await appDataDirectory();
  return StorageUsage(
    databaseBytes: await getDirectorySize(directory, _hiveFile),
    cacheBytes: await getDirectorySize(directory, _audioFile),
  );
}
