import 'package:dio/dio.dart';

import 'config.dart';
import 'token_store.dart';

final class ApiClient {
  ApiClient(this._tokenStore, {Dio? dio})
    : dio = dio ?? Dio(BaseOptions(baseUrl: AppConfig.apiBaseUri.toString())) {
    _refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUri.toString()));
    this.dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: _authorize,
        onError: _refreshAfterUnauthorized,
      ),
    );
  }

  final TokenStore _tokenStore;
  final Dio dio;
  late final Dio _refreshDio;

  Future<void> _authorize(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await _tokenStore.readAccessToken();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  Future<void> _refreshAfterUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    if (error.response?.statusCode != 401 || request.extra['retried'] == true) {
      handler.next(error);
      return;
    }
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      handler.next(error);
      return;
    }
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        'auth/refresh/',
        data: {'refresh': refresh},
      );
      final newAccess = response.data?['access'] as String?;
      final newRefresh = response.data?['refresh'] as String?;
      if (newAccess == null || newRefresh == null) {
        throw const FormatException(
          'Refresh response did not contain both tokens.',
        );
      }
      // Persist both rotated values before retrying. The previous refresh
      // token is already blacklisted by the backend at this point.
      await _tokenStore.saveTokens(access: newAccess, refresh: newRefresh);
      final retried = await dio.fetch<dynamic>(
        request.copyWith(
          headers: {...request.headers, 'Authorization': 'Bearer $newAccess'},
          extra: {...request.extra, 'retried': true},
        ),
      );
      handler.resolve(retried);
    } catch (_) {
      await _tokenStore.clear();
      handler.next(error);
    }
  }
}
