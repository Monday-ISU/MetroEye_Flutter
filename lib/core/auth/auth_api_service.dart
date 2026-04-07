import 'package:dio/dio.dart';
import 'package:metroeye_flutter/core/auth/auth_grant_type.dart';
import 'package:metroeye_flutter/core/network/api_client.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/network/api_response.dart';

class ClientCredentialsTokenResponse {
  const ClientCredentialsTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.clientMessage = '',
    this.serverMessage = '',
  });

  factory ClientCredentialsTokenResponse.fromJson(
    Map<String, dynamic> json, {
    String clientMessage = '',
    String serverMessage = '',
  }) {
    return ClientCredentialsTokenResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      clientMessage: clientMessage,
      serverMessage: serverMessage,
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String clientMessage;
  final String serverMessage;
}

class RefreshTokenResponse {
  const RefreshTokenResponse({
    required this.accessToken,
    required this.expiresIn,
    this.clientMessage = '',
    this.serverMessage = '',
  });

  factory RefreshTokenResponse.fromJson(
    Map<String, dynamic> json, {
    String clientMessage = '',
    String serverMessage = '',
  }) {
    return RefreshTokenResponse(
      accessToken: json['accessToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      clientMessage: clientMessage,
      serverMessage: serverMessage,
    );
  }

  final String accessToken;
  final int expiresIn;
  final String clientMessage;
  final String serverMessage;
}

class AuthApiService {
  AuthApiService([Dio? dio])
    : _dio = dio ?? ApiClient.createPublicDio(apiName: 'Auth API');

  final Dio _dio;

  Future<ClientCredentialsTokenResponse> issueWithClientCredentials({
    required String uuid,
    required String secret,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/token',
        data: {
          'grantType': AuthGrantType.clientCredentials.value,
          'uuid': uuid,
          'secret': secret,
        },
      );

      final body = response.data;
      if (body == null) {
        throw const ApiException('Auth API response is empty.');
      }

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        body,
        (data) => asMap(data),
      );

      return ClientCredentialsTokenResponse.fromJson(
        apiResponse.data,
        clientMessage: apiResponse.clientMessage,
        serverMessage: apiResponse.serverMessage,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(
        error,
        fallbackMessage: 'Auth API request failed.',
      );
    }
  }

  Future<RefreshTokenResponse> issueWithRefreshToken({
    required String refreshToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/token',
        data: {
          'grantType': AuthGrantType.refreshToken.value,
          'refreshToken': refreshToken,
        },
      );

      final body = response.data;
      if (body == null) {
        throw const ApiException('Auth API response is empty.');
      }

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        body,
        (data) => asMap(data),
      );

      return RefreshTokenResponse.fromJson(
        apiResponse.data,
        clientMessage: apiResponse.clientMessage,
        serverMessage: apiResponse.serverMessage,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(
        error,
        fallbackMessage: 'Auth API request failed.',
      );
    }
  }
}
