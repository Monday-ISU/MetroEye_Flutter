import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/device/device_identity.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/network/api_response.dart';

class CreateDeviceResponse {
  const CreateDeviceResponse({
    required this.secret,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory CreateDeviceResponse.fromJson(Map<String, dynamic> json) {
    return CreateDeviceResponse(
      secret: json['secret'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
    );
  }

  final String secret;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
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
        throw const ApiException('서버 응답이 비어 있습니다.');
      }

      return ApiResponse<CreateDeviceResponse>.fromJson(
        body,
        (data) => CreateDeviceResponse.fromJson(asMap(data)),
      ).data;
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final clientMessage = data['clientMessage'] as String?;
        final serverMessage = data['serverMessage'] as String?;
        throw ApiException(clientMessage ?? serverMessage ?? 'Device API 호출에 실패했습니다.');
      }

      throw ApiException(error.message ?? 'Device API 호출에 실패했습니다.');
    }
  }
}
