import 'package:dio/dio.dart';
import 'jellyfin_exception.dart';

/// Exception thrown when API request fails
class ApiException extends JellyfinException {
  /// HTTP status code
  final int? statusCode;

  /// Response data (if available)
  final dynamic responseData;

  const ApiException(
    super.message, {
    this.statusCode,
    this.responseData,
    super.cause,
    super.stackTrace,
  });

  /// Creates an ApiException from a DioError
  factory ApiException.fromDioError(DioException error) {
    String message;
    int? statusCode;
    dynamic responseData = error.response?.data;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Request timeout - please check your connection';
        break;

      case DioExceptionType.badResponse:
        statusCode = error.response?.statusCode;
        message = _getErrorMessage(statusCode, responseData);
        break;

      case DioExceptionType.cancel:
        message = 'Request was cancelled';
        break;

      case DioExceptionType.connectionError:
        message = 'Connection error - unable to reach the server';
        break;

      case DioExceptionType.badCertificate:
        message = 'SSL certificate error - unable to verify server identity';
        break;

      case DioExceptionType.unknown:
      default:
        message = error.message ?? 'Unknown error occurred';
    }

    return ApiException(
      message,
      statusCode: statusCode,
      responseData: responseData,
      cause: error.error ?? error,
    );
  }

  static String _getErrorMessage(int? statusCode, dynamic responseData) {
    if (statusCode == null) {
      return 'Unknown error occurred';
    }

    // Try to extract error message from response
    if (responseData is Map<String, dynamic>) {
      final error = responseData['error'] as Map<String, dynamic>?;
      if (error != null) {
        return error['message'] as String? ?? 'Server error ($statusCode)';
      }
    }

    // Fallback to standard HTTP status messages
    switch (statusCode) {
      case 400:
        return 'Bad request - invalid parameters';
      case 401:
        return 'Unauthorized - authentication required';
      case 403:
        return 'Forbidden - insufficient permissions';
      case 404:
        return 'Not found - resource does not exist';
      case 500:
        return 'Internal server error';
      case 503:
        return 'Service unavailable';
      default:
        return 'Server error ($statusCode)';
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer('ApiException: $message');
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    if (cause != null) {
      buffer.writeln('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}
