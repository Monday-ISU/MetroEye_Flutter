import 'package:metroeye_flutter/core/device/device_api_service.dart';
import 'package:metroeye_flutter/core/device/device_identity_service.dart';
import 'package:metroeye_flutter/core/device/device_session.dart';
import 'package:metroeye_flutter/core/device/device_token_storage.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';

class DeviceSessionLoadResult {
  const DeviceSessionLoadResult({
    required this.session,
    required this.debugText,
  });

  final DeviceSession session;
  final String debugText;
}

class DeviceSessionService {
  DeviceSessionService({
    DeviceIdentityService? identityService,
    DeviceApiService? deviceApiService,
    DeviceTokenStorage? tokenStorage,
  }) : _identityService = identityService ?? DeviceIdentityService(),
       _deviceApiService = deviceApiService ?? DeviceApiService(),
       _tokenStorage = tokenStorage ?? SecureDeviceTokenStorage();

  final DeviceIdentityService _identityService;
  final DeviceApiService _deviceApiService;
  final DeviceTokenStorage _tokenStorage;

  Future<DeviceSession> loadOrCreateSession() async {
    final result = await loadOrCreateSessionWithDebug();
    return result.session;
  }

  Future<DeviceSessionLoadResult> loadOrCreateSessionWithDebug() async {
    final storedSession = await _tokenStorage.read();
    if (storedSession != null) {
      return DeviceSessionLoadResult(
        session: storedSession,
        debugText: [
          'Device session source: storage',
          'uuid=${storedSession.uuid}',
          'accessTokenStored=${storedSession.accessToken.isNotEmpty}',
          'refreshTokenStored=${storedSession.refreshToken.isNotEmpty}',
          'expiresIn=${storedSession.expiresIn}',
        ].join('\n'),
      );
    }

    final identity = await _identityService.load();

    try {
      final response = await _deviceApiService.createDevice(identity);
      final session = DeviceSession(
        osType: identity.osType,
        uuid: identity.uuid,
        secret: response.secret,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        expiresIn: response.expiresIn,
      );

      await _tokenStorage.write(session);

      return DeviceSessionLoadResult(
        session: session,
        debugText: [
          'Device session source: device_api',
          'uuid=${identity.uuid}',
          'osType=${identity.osType}',
          'clientMessage=${response.clientMessage.isEmpty ? '-' : response.clientMessage}',
          'serverMessage=${response.serverMessage.isEmpty ? '-' : response.serverMessage}',
          'accessTokenStored=${session.accessToken.isNotEmpty}',
          'refreshTokenStored=${session.refreshToken.isNotEmpty}',
          'expiresIn=${session.expiresIn}',
        ].join('\n'),
      );
    } on ApiException catch (error) {
      throw ApiException(
        'Device session initialization failed.',
        details: [
          'Device session source: device_api',
          'uuid=${identity.uuid}',
          'osType=${identity.osType}',
          'error=${error.message}',
          if (error.details != null && error.details!.isNotEmpty) error.details!,
        ].join('\n'),
      );
    }
  }
}
