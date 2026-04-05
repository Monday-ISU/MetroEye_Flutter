import 'package:metroeye_flutter/core/network/api_exception.dart';

class ApiResponse<T> {
  const ApiResponse({
    required this.clientMessage,
    required this.serverMessage,
    required this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? data) parser,
  ) {
    return ApiResponse<T>(
      clientMessage: json['clientMessage'] as String? ?? '',
      serverMessage: json['serverMessage'] as String? ?? '',
      data: parser(json['data']),
    );
  }

  final String clientMessage;
  final String serverMessage;
  final T data;
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  throw const ApiException('응답 데이터 형식이 올바르지 않습니다.');
}
