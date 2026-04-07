import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/auth/auth_recovery_service.dart';
import 'package:metroeye_flutter/core/device/device_token_storage.dart';
import 'package:metroeye_flutter/core/line/line_model.dart';
import 'package:metroeye_flutter/core/network/api_client.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/network/api_response.dart';

class LineApiService {
  LineApiService({
    Dio? dio,
    DeviceTokenStorage? tokenStorage,
    AuthRecoveryService? authRecoveryService,
  }) : this._(
         dio: dio,
         tokenStorage: tokenStorage ?? SecureDeviceTokenStorage(),
         authRecoveryService: authRecoveryService,
       );

  LineApiService._({
    Dio? dio,
    required DeviceTokenStorage tokenStorage,
    AuthRecoveryService? authRecoveryService,
  }) : _dio =
           dio ??
           ApiClient.createProtectedDio(
             apiName: 'Line API',
             tokenStorage: tokenStorage,
             authRecoveryService:
                 authRecoveryService ??
                 AuthRecoveryService(tokenStorage: tokenStorage),
           );

  final Dio _dio;

  Future<List<LineModel>> fetchLines() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/lines');

      final body = response.data;
      if (body == null) {
        throw const ApiException('Line API response is empty.');
      }

      return ApiResponse<List<LineModel>>.fromJson(
        body,
        (data) => asList(data)
            .map((item) => LineModel.fromJson(asMap(item)))
            .toList(),
      ).data;
    } on DioException catch (error) {
      throw ApiException.fromDioException(
        error,
        fallbackMessage: 'Line API request failed.',
      );
    }
  }
}
