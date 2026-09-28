import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<bool> readOnboardingRequired();
  Future<void> saveTokens({required String access, required String refresh});
  Future<void> setOnboardingRequired(bool required);
  Future<void> clear();
}

final class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'jwt_access';
  static const _refreshKey = 'jwt_refresh';
  static const _onboardingRequiredKey = 'onboarding_required';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);
  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<bool> readOnboardingRequired() async =>
      await _storage.read(key: _onboardingRequiredKey) == 'true';

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  @override
  Future<void> setOnboardingRequired(bool required) => required
      ? _storage.write(key: _onboardingRequiredKey, value: 'true')
      : _storage.delete(key: _onboardingRequiredKey);

  @override
  Future<void> clear() => _storage.deleteAll();
}
