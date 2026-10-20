import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_storage.dart';

class SecureTokenStore {
  const SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wanikani_api_token';
  static const _fallbackBox = 'token_fallback';
  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      final value = await _storage.read(key: _key);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {}
    return _readFallback();
  }

  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {}
    await _writeFallback(token);
  }

  Future<void> delete() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
    await _openFallback().then((box) => box.delete(_key));
  }

  Future<Box<String>> _openFallback() async {
    await initAppStorage();
    if (!Hive.isBoxOpen(_fallbackBox)) {
      await Hive.openBox<String>(_fallbackBox);
    }
    return Hive.box<String>(_fallbackBox);
  }

  Future<String?> _readFallback() async => (await _openFallback()).get(_key);

  Future<void> _writeFallback(String token) async =>
      (await _openFallback()).put(_key, token);
}
