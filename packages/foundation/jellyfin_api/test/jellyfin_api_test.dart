import 'package:test/test.dart';
import 'package:dio/dio.dart';
import 'package:jellyfin_api/jellyfin_api.dart';

void main() {
  group('ApiException', () {
    test('应正确存储状态码和消息', () {
      const exception = ApiException(
        'Not found',
        statusCode: 404,
      );
      expect(exception.message, 'Not found');
      expect(exception.statusCode, 404);
      expect(exception.toString(), contains('404'));
    });

    test('fromDioError 应转换连接超时', () {
      final dioError = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final apiException = ApiException.fromDioError(dioError);
      expect(apiException.message, contains('timeout'));
    });

    test('fromDioError 应转换 401 响应', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );
      final apiException = ApiException.fromDioError(dioError);
      expect(apiException.statusCode, 401);
      expect(apiException.message, contains('Unauthorized'));
    });
  });

  group('AuthenticationException', () {
    test('invalidCredentials 应有正确错误码', () {
      final exception = AuthenticationException.invalidCredentials();
      expect(exception.errorCode, 'INVALID_CREDENTIALS');
      expect(exception.message, contains('Invalid'));
    });

    test('serverNotFound 应有正确错误码', () {
      final exception = AuthenticationException.serverNotFound();
      expect(exception.errorCode, 'SERVER_NOT_FOUND');
    });

    test('fromDioError 应转换连接错误', () {
      final dioError = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: '/test'),
      );
      final exception = AuthenticationException.fromDioError(dioError);
      expect(exception.errorCode, 'CONNECTION_ERROR');
    });
  });

  group('JellyfinException', () {
    test('ApiException 是 JellyfinException 子类', () {
      const exception = ApiException('test');
      expect(exception, isA<JellyfinException>());
    });

    test('AuthenticationException 是 JellyfinException 子类', () {
      final exception = AuthenticationException.invalidCredentials();
      expect(exception, isA<JellyfinException>());
    });
  });
}
