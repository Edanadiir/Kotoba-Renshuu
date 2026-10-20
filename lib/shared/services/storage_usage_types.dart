class StorageUsage {
  const StorageUsage({this.databaseBytes = 0, this.cacheBytes = 0});

  final int databaseBytes;
  final int cacheBytes;

  int get totalBytes => databaseBytes + cacheBytes;
}

String formatBytes(int bytes) {
  const mb = 1024 * 1024;
  if (bytes < mb) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / mb).toStringAsFixed(1)} MB';
}
