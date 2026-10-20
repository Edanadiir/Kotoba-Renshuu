import 'app_storage_stub.dart'
    if (dart.library.io) 'app_storage_io.dart'
    as implementation;

/// Initialises Hive inside `Documents\Wanikani Renshuu` (IO platforms).
Future<void> initAppStorage() => implementation.initAppStorage();
