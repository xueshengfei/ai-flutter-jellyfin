import 'package:dio/dio.dart';
import 'jellyfin_exception.dart';

/// 认证异常
///
/// 当认证失败时抛出此异常
class AuthenticationException extends JellyfinException {
  /// 错误代码（如果可用）
  final String? errorCode;

  const AuthenticationException(
    super.message, {
    super.cause,
    super.stackTrace,
    this.errorCode,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AuthenticationException: $message');
    if (errorCode != null) {
      buffer.write(' (code: $errorCode)');
    }
    if (cause != null) {
      buffer.writeln('\nCaused by: $cause');
    }
    return buffer.toString();
  }

  /// 创建无效凭据的异常
  factory AuthenticationException.invalidCredentials({Object? cause}) {
    return AuthenticationException(
      'Invalid username or password',
      cause: cause,
      errorCode: 'INVALID_CREDENTIALS',
    );
  }

  /// 创建缺少凭据的异常
  factory AuthenticationException.missingCredentials() {
    return const AuthenticationException(
      'Username and password are required',
      errorCode: 'MISSING_CREDENTIALS',
    );
  }

  /// 创建未授权访问的异常
  factory AuthenticationException.unauthorized({Object? cause}) {
    return AuthenticationException(
      'Unauthorized access - please login again',
      cause: cause,
      errorCode: 'UNAUTHORIZED',
    );
  }

  /// 创建服务器未找到的异常
  factory AuthenticationException.serverNotFound({Object? cause}) {
    return AuthenticationException(
      'Jellyfin server not found - check the server URL',
      cause: cause,
      errorCode: 'SERVER_NOT_FOUND',
    );
  }

  /// 从DioError创建认证异常
  factory AuthenticationException.fromDioError(DioException error) {
    String message;
    String? errorCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout - unable to reach the server';
        errorCode = 'TIMEOUT';
        break;

      case DioExceptionType.connectionError:
        message = 'Connection error - unable to reach the server';
        errorCode = 'CONNECTION_ERROR';
        break;

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          message = 'Invalid username or password';
          errorCode = 'INVALID_CREDENTIALS';
        } else if (statusCode == 403) {
          message = 'Access forbidden - insufficient permissions';
          errorCode = 'FORBIDDEN';
        } else if (statusCode == 404) {
          message = 'Server not found';
          errorCode = 'SERVER_NOT_FOUND';
        } else {
          message = 'Authentication failed (HTTP $statusCode)';
          errorCode = 'HTTP_ERROR';
        }
        break;

      case DioExceptionType.badCertificate:
        message = 'SSL certificate error - unable to verify server';
        errorCode = 'CERTIFICATE_ERROR';
        break;

      case DioExceptionType.cancel:
        message = 'Request was cancelled';
        errorCode = 'CANCELLED';
        break;

      case DioExceptionType.unknown:
      default:
        message = error.message ?? 'Unknown authentication error';
        errorCode = 'UNKNOWN_ERROR';
    }

    return AuthenticationException(
      message,
      errorCode: errorCode,
      cause: error.error ?? error,
    );
  }
}
