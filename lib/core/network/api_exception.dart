import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/network/api_error_logger.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.details,
    this.statusCode,
    this.clientMessage,
    this.serverMessage,
    this.responseBody,
  });

  factory ApiException.fromDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final data = error.response?.data;
    final clientMessage = readClientMessage(data);
    final serverMessage = readServerMessage(data);

    return ApiException(
      clientMessage ?? serverMessage ?? error.message ?? fallbackMessage,
      details: [
        'statusCode=${error.response?.statusCode ?? 'unknown'}',
        'clientMessage=${clientMessage ?? '-'}',
        'serverMessage=${serverMessage ?? '-'}',
      ].join('\n'),
      statusCode: error.response?.statusCode,
      clientMessage: clientMessage,
      serverMessage: serverMessage,
      responseBody: data,
    );
  }

  final String message;
  final String? details;
  final int? statusCode;
  final String? clientMessage;
  final String? serverMessage;
  final Object? responseBody;

  bool get isAuthenticationFailure {
    return matchesAuthenticationFailure(
      statusCode: statusCode,
      clientMessage: clientMessage,
      serverMessage: serverMessage,
    );
  }

  @override
  String toString() => message;
}

bool matchesAuthenticationFailure({
  int? statusCode,
  String? clientMessage,
  String? serverMessage,
}) {
  return statusCode == 401 ||
      clientMessage?.trim() == '인증에 실패했습니다.' ||
      serverMessage?.trim() == 'Authentication failed.';
}
