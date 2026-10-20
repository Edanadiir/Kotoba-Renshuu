import 'storage_usage_stub.dart'
    if (dart.library.io) 'storage_usage_io.dart'
    as implementation;
import 'storage_usage_types.dart';

export 'storage_usage_types.dart';

Future<StorageUsage> measureStorageUsage() =>
    implementation.measureStorageUsage();
