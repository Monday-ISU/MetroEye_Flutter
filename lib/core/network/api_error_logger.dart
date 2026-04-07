import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

void logApiResponse({
  required String apiName,
  required Response<dynamic> response,
}) {
  final buffer = StringBuffer()
    ..writeln('[$apiName] response')
    ..writeln('method=${response.requestOptions.method}')
    ..writeln('path=${response.requestOptions.uri}')
    ..writeln('statusCode=${response.statusCode ?? 'unknown'}')
    ..writeln('responseBody=${stringifyResponseBody(response.data)}');

  final clientMessage = readClientMessage(response.data);
  final serverMessage = readServerMessage(response.data);

  if (clientMessage != null && clientMessage.isNotEmpty) {
    buffer.writeln('clientMessage=$clientMessage');
  }

  if (serverMessage != null && serverMessage.isNotEmpty) {
    buffer.writeln('serverMessage=$serverMessage');
  }

  debugPrint(buffer.toString().trimRight());
}

void logApiErrorResponse({
  required String apiName,
  required DioException error,
}) {
  final data = error.response?.data;
  final clientMessage = readClientMessage(data);
  final serverMessage = readServerMessage(data);
  final buffer = StringBuffer()
    ..writeln('[$apiName] response')
    ..writeln('method=${error.requestOptions.method}')
    ..writeln('path=${error.requestOptions.uri}')
    ..writeln('statusCode=${error.response?.statusCode ?? 'unknown'}')
    ..writeln('responseBody=${stringifyResponseBody(data)}');

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

String? readClientMessage(Object? data) {
  if (data is! Map<String, dynamic>) {
    return null;
  }

  final value = data['clientMessage'];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  return null;
}

String? readServerMessage(Object? data) {
  if (data is! Map<String, dynamic>) {
    return null;
  }

  final value = data['serverMessage'];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  return null;
}

String stringifyResponseBody(Object? data) {
  if (data == null) {
    return 'null';
  }

  if (data is String) {
    return data;
  }

  try {
    return jsonEncode(data);
  } catch (_) {
    return data.toString();
  }
}
