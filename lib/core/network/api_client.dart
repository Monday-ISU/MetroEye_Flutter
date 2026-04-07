import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/auth/auth_recovery_service.dart';
import 'package:metroeye_flutter/core/device/device_token_storage.dart';
import 'package:metroeye_flutter/core/network/api_logging_interceptor.dart';
import 'package:metroeye_flutter/core/network/auth_recovery_interceptor.dart';

class ApiClient {
  static const String baseUrl = 'https://dev-api.metroeye.click';

  static BaseOptions _baseOptions() {
    return BaseOptions(
      baseUrl: baseUrl,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
  }

  static Dio createPublicDio({
    required String apiName,
  }) {
    final dio = Dio(_baseOptions());
    dio.interceptors.add(ApiLoggingInterceptor(apiName: apiName));
    return dio;
  }

  static Dio createProtectedDio({
    required String apiName,
    required DeviceTokenStorage tokenStorage,
    required AuthRecoveryService authRecoveryService,
  }) {
    final dio = Dio(_baseOptions());
    dio.interceptors.add(
      AuthRecoveryInterceptor(
        apiName: apiName,
        dio: dio,
        tokenStorage: tokenStorage,
        authRecoveryService: authRecoveryService,
      ),
    );
    dio.interceptors.add(ApiLoggingInterceptor(apiName: apiName));
    return dio;
  }
}
