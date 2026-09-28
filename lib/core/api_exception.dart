import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final message = _messageFrom(body) ?? error.message ?? 'Request failed.';
    if (status == 429) return ThrottledException(message);
    if (status == 401) return UnauthorizedException(message);
    return RequestException(message, statusCode: status);
  }

  static String? _messageFrom(Object? body) {
    if (body is Map) {
      for (final key in const ['detail', 'message', 'error']) {
        final value = body[key];
        if (value is String && value.isNotEmpty) return value;
      }
      for (final value in body.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
      }
    }
    return null;
  }

  @override
  String toString() => message;
}

final class ThrottledException extends ApiException {
  const ThrottledException(super.message) : super(statusCode: 429);
}

final class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message) : super(statusCode: 401);
}

final class RequestException extends ApiException {
  const RequestException(super.message, {super.statusCode});
}

/// A compact, defensively-parsed error string for inline use (a single line
/// within a larger screen) where the full `ApiErrorView` card would be too
/// heavy — e.g. one metric tile failing inside an otherwise-fine dashboard.
String apiErrorMessage(Object error) =>
    error is ApiException ? error.message : error.toString();
