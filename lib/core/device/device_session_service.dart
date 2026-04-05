import 'package:metroeye_flutter/core/device/device_api_service.dart';
import 'package:metroeye_flutter/core/device/device_identity_service.dart';
import 'package:metroeye_flutter/core/device/device_session.dart';
import 'package:metroeye_flutter/core/device/device_token_storage.dart';

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
    final storedSession = await _tokenStorage.read();
    if (storedSession != null) {
      return storedSession;
    }

    final identity = await _identityService.load();
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
    return session;
  }
}
