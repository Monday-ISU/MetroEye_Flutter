import 'package:metroeye_flutter/core/auth/auth_api_service.dart';
import 'package:metroeye_flutter/core/device/device_session.dart';
import 'package:metroeye_flutter/core/device/device_token_storage.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';

class AuthRecoveryService {
  AuthRecoveryService({
    AuthApiService? authApiService,
    DeviceTokenStorage? tokenStorage,
  }) : _authApiService = authApiService ?? AuthApiService(),
       _tokenStorage = tokenStorage ?? SecureDeviceTokenStorage();

  final AuthApiService _authApiService;
  final DeviceTokenStorage _tokenStorage;

  Future<DeviceSession>? _ongoingRecovery;

  Future<DeviceSession> recoverSession() {
    final ongoingRecovery = _ongoingRecovery;
    if (ongoingRecovery != null) {
      return ongoingRecovery;
    }

    final future = _recoverSession();
    _ongoingRecovery = future;

    return future.whenComplete(() {
      if (identical(_ongoingRecovery, future)) {
        _ongoingRecovery = null;
      }
    });
  }

  Future<DeviceSession> _recoverSession() async {
    final session = await _tokenStorage.read();
    if (session == null) {
      throw const ApiException('No stored device session found.');
    }

    try {
      final refreshResponse = await _authApiService.issueWithRefreshToken(
        refreshToken: session.refreshToken,
      );

      final updatedSession = session.copyWith(
        accessToken: refreshResponse.accessToken,
        expiresIn: refreshResponse.expiresIn,
      );

      await _tokenStorage.write(updatedSession);
      return updatedSession;
    } on ApiException catch (error) {
      if (!error.isAuthenticationFailure) {
        rethrow;
      }
    }

    final accessResponse = await _authApiService.issueWithClientCredentials(
      uuid: session.uuid,
      secret: session.secret,
    );
    final recoveredSession = session.copyWith(
      accessToken: accessResponse.accessToken,
      refreshToken: accessResponse.refreshToken,
      expiresIn: accessResponse.expiresIn,
    );

    await _tokenStorage.write(recoveredSession);
    return recoveredSession;
  }
}
