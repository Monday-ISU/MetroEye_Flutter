import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

void logApiError({
  required String apiName,
  required DioException error,
  String? clientMessage,
  String? serverMessage,
}) {
  final buffer = StringBuffer()
    ..writeln('[$apiName] request failed')
    ..writeln('statusCode=${error.response?.statusCode ?? 'unknown'}');

  if (clientMessage != null && clientMessage.isNotEmpty) {
    buffer.writeln('clientMessage=$clientMessage');
  }

  if (serverMessage != null && serverMessage.isNotEmpty) {
    buffer.writeln('serverMessage=$serverMessage');
  }

  if ((clientMessage == null || clientMessage.isEmpty) &&
      (serverMessage == null || serverMessage.isEmpty)) {
    buffer.writeln('message=${error.message ?? 'unknown'}');
  }

  debugPrint(buffer.toString().trimRight());
}
