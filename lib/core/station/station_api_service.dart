import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/auth/auth_recovery_service.dart';
import 'package:metroeye_flutter/core/device/device_token_storage.dart';
import 'package:metroeye_flutter/core/network/api_client.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/network/api_response.dart';
import 'package:metroeye_flutter/core/station/station_model.dart';

class StationApiService {
  StationApiService({
    Dio? dio,
    DeviceTokenStorage? tokenStorage,
    AuthRecoveryService? authRecoveryService,
  }) : this._(
         dio: dio,
         tokenStorage: tokenStorage ?? SecureDeviceTokenStorage(),
         authRecoveryService: authRecoveryService,
       );

  StationApiService._({
    Dio? dio,
    required DeviceTokenStorage tokenStorage,
    AuthRecoveryService? authRecoveryService,
  }) : _dio =
           dio ??
           ApiClient.createProtectedDio(
             apiName: 'Station API',
             tokenStorage: tokenStorage,
             authRecoveryService:
                 authRecoveryService ??
                 AuthRecoveryService(tokenStorage: tokenStorage),
           );

  final Dio _dio;

  Future<List<StationModel>> fetchStations() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/stations');

      final body = response.data;
      if (body == null) {
        throw const ApiException('Station API response is empty.');
      }

      return ApiResponse<List<StationModel>>.fromJson(
        body,
        (data) => asList(data)
            .map((item) => StationModel.fromJson(asMap(item)))
            .toList(),
      ).data;
    } on DioException catch (error) {
      throw ApiException.fromDioException(
        error,
        fallbackMessage: 'Station API request failed.',
      );
    }
  }
}
