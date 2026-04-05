import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/device/device_identity.dart';
import 'package:metroeye_flutter/core/network/api_error_logger.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/network/api_response.dart';

class CreateDeviceResponse {
  const CreateDeviceResponse({
    required this.secret,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.clientMessage = '',
    this.serverMessage = '',
  });

  factory CreateDeviceResponse.fromJson(
    Map<String, dynamic> json, {
    String clientMessage = '',
    String serverMessage = '',
  }) {
    return CreateDeviceResponse(
      secret: json['secret'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      clientMessage: clientMessage,
      serverMessage: serverMessage,
    );
  }

  final String secret;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String clientMessage;
  final String serverMessage;
}

class DeviceApiService {
  DeviceApiService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://dev-api.metroeye.click',
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  Future<CreateDeviceResponse> createDevice(DeviceIdentity identity) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/devices',
        data: {
          'uuid': identity.uuid,
          'osType': identity.osType,
        },
      );

      final body = response.data;
      if (body == null) {
        throw const ApiException('Device API response is empty.');
      }

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        body,
        (data) => asMap(data),
      );

      return CreateDeviceResponse.fromJson(
        apiResponse.data,
        clientMessage: apiResponse.clientMessage,
        serverMessage: apiResponse.serverMessage,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final clientMessage = data['clientMessage'] as String?;
        final serverMessage = data['serverMessage'] as String?;
        logApiError(
          apiName: 'Device API',
          error: error,
          clientMessage: clientMessage,
          serverMessage: serverMessage,
        );
        throw ApiException(
          clientMessage ?? serverMessage ?? 'Device API request failed.',
          details: 'statusCode=${error.response?.statusCode ?? 'unknown'}\n'
              'clientMessage=${clientMessage ?? '-'}\n'
              'serverMessage=${serverMessage ?? '-'}',
        );
      }

      logApiError(
        apiName: 'Device API',
        error: error,
      );
      throw ApiException(
        error.message ?? 'Device API request failed.',
        details: 'statusCode=${error.response?.statusCode ?? 'unknown'}',
      );
    }
  }
}
