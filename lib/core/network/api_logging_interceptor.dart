import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/network/api_error_logger.dart';

class ApiLoggingInterceptor extends Interceptor {
  ApiLoggingInterceptor({required this.apiName});

  final String apiName;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    logApiResponse(
      apiName: apiName,
      response: response,
    );
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    logApiErrorResponse(
      apiName: apiName,
      error: err,
    );
    handler.next(err);
  }
}
