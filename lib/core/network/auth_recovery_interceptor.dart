import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/auth/auth_recovery_service.dart';
import 'package:metroeye_flutter/core/device/device_token_storage.dart';
import 'package:metroeye_flutter/core/network/api_error_logger.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';

class AuthRecoveryInterceptor extends QueuedInterceptor {
  AuthRecoveryInterceptor({
    required this.apiName,
    required Dio dio,
    required DeviceTokenStorage tokenStorage,
    required AuthRecoveryService authRecoveryService,
  }) : _dio = dio,
       _tokenStorage = tokenStorage,
       _authRecoveryService = authRecoveryService;

  static const String retriedKey = 'authRecoveryRetried';

  final String apiName;
  final Dio _dio;
  final DeviceTokenStorage _tokenStorage;
  final AuthRecoveryService _authRecoveryService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }

    final session = await _tokenStorage.read();
    if (session != null && session.accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRecover(err) || err.requestOptions.extra[retriedKey] == true) {
      handler.next(err);
      return;
    }

    logApiErrorResponse(
      apiName: apiName,
      error: err,
    );

    try {
      final session = await _authRecoveryService.recoverSession();
      final headers = Map<String, dynamic>.from(err.requestOptions.headers)
        ..['Authorization'] = 'Bearer ${session.accessToken}';
      final extra = Map<String, dynamic>.from(err.requestOptions.extra)
        ..[retriedKey] = true;

      final retriedRequest = err.requestOptions.copyWith(
        headers: headers,
        extra: extra,
      );

      final response = await _dio.fetch<dynamic>(retriedRequest);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } on ApiException {
      handler.next(err);
    } catch (_) {
      handler.next(err);
    }
  }

  bool _shouldRecover(DioException error) {
    final data = error.response?.data;
    return matchesAuthenticationFailure(
      statusCode: error.response?.statusCode,
      clientMessage: readClientMessage(data),
      serverMessage: readServerMessage(data),
    );
  }
}
