import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageHelper {
  static const _versionKey = 'secure_storage_version';
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static AndroidOptions _androidOptions() => AndroidOptions();

  static Future<void> write(String key, String value) async {
    await _storage.write(
      key: key,
      value: value,
      aOptions: _androidOptions(),
    );
  }

  static Future<String?> read(String key) async {
    return await _storage.read(
      key: key,
      aOptions: _androidOptions(),
    );
  }

  static Future<void> delete(String key) async {
    await _storage.delete(
      key: key,
      aOptions: _androidOptions(),
    );
  }

  static Future<void> deleteAll() async {
    await _storage.deleteAll(
      aOptions: _androidOptions(),
    );
  }

  // Simple versioning helpers to support key rotation policies
  static Future<String> getVersion() async {
    final v = await read(_versionKey);
    return v ?? 'v1';
  }

  static Future<void> setVersion(String v) async {
    await write(_versionKey, v);
  }

  // Placeholder rotate method: sets new version flag. Full re-encryption
  // would require reading all known keys and re-writing, which is application
  // specific; this provides a safe flag for coordinated rotations.
  static Future<void> rotateVersion(String newVersion) async {
    await setVersion(newVersion);
  }
}
