import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/line/line_model.dart';
import 'package:metroeye_flutter/core/network/api_error_logger.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/network/api_response.dart';

class LineApiService {
  LineApiService([Dio? dio])
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

  Future<List<LineModel>> fetchLines({required String accessToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/lines',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

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
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final clientMessage = data['clientMessage'] as String?;
        final serverMessage = data['serverMessage'] as String?;
        logApiError(
          apiName: 'Line API',
          error: error,
          clientMessage: clientMessage,
          serverMessage: serverMessage,
        );
        throw ApiException(
          clientMessage ?? serverMessage ?? 'Line API request failed.',
          details: 'statusCode=${error.response?.statusCode ?? 'unknown'}\n'
              'clientMessage=${clientMessage ?? '-'}\n'
              'serverMessage=${serverMessage ?? '-'}',
        );
      }

      logApiError(
        apiName: 'Line API',
        error: error,
      );
      throw ApiException(
        error.message ?? 'Line API request failed.',
        details: 'statusCode=${error.response?.statusCode ?? 'unknown'}',
      );
    }
  }
}
