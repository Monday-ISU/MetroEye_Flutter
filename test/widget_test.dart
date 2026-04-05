import 'package:flutter_test/flutter_test.dart';
import 'package:metroeye_flutter/core/device/device_api_service.dart';
import 'package:metroeye_flutter/core/device/device_identity.dart';
import 'package:metroeye_flutter/core/device/device_identity_service.dart';
import 'package:metroeye_flutter/core/device/device_session.dart';
import 'package:metroeye_flutter/core/device/device_session_service.dart';
import 'package:metroeye_flutter/core/device/device_token_storage.dart';
import 'package:metroeye_flutter/core/line/line_api_service.dart';
import 'package:metroeye_flutter/core/line/line_cache_storage.dart';
import 'package:metroeye_flutter/core/line/line_model.dart';
import 'package:metroeye_flutter/core/line/line_service.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';

void main() {
  group('DeviceIdentityService', () {
    test('returns stored uuid when it already exists', () async {
      final store = _FakeDeviceIdentityStore(initialUuid: 'stored-uuid');
      final service = DeviceIdentityService(
        store: store,
        osTypeResolver: () => 'ANDROID',
        uuidGenerator: () => 'generated-uuid',
      );

      final identity = await service.load();

      expect(identity.osType, 'ANDROID');
      expect(identity.uuid, 'stored-uuid');
      expect(store.writeCalls, 0);
    });

    test('generates and persists uuid when no stored uuid exists', () async {
      final store = _FakeDeviceIdentityStore();
      final service = DeviceIdentityService(
        store: store,
        osTypeResolver: () => 'IOS',
        uuidGenerator: () => 'generated-uuid',
      );

      final identity = await service.load();

      expect(identity.osType, 'IOS');
      expect(identity.uuid, 'generated-uuid');
      expect(store.storedUuid, 'generated-uuid');
      expect(store.writeCalls, 1);
    });
  });

  group('DeviceSessionService', () {
    test('creates a session from Device API on first launch', () async {
      final identityService = _FakeDeviceIdentityService(
        const DeviceIdentity(osType: 'ANDROID', uuid: 'device-uuid'),
      );
      final apiService = _FakeDeviceApiService(
        const CreateDeviceResponse(
          secret: 'secret',
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresIn: 180,
        ),
      );
      final tokenStorage = _FakeDeviceTokenStorage();
      final service = DeviceSessionService(
        identityService: identityService,
        deviceApiService: apiService,
        tokenStorage: tokenStorage,
      );

      final session = await service.loadOrCreateSession();

      expect(identityService.loadCalls, 1);
      expect(apiService.createCalls, 1);
      expect(tokenStorage.writeCalls, 1);
      expect(session.uuid, 'device-uuid');
      expect(session.accessToken, 'access-token');
      expect(session.refreshToken, 'refresh-token');
    });

    test('reuses stored session on later launches', () async {
      const storedSession = DeviceSession(
        osType: 'ANDROID',
        uuid: 'stored-uuid',
        secret: 'stored-secret',
        accessToken: 'stored-access',
        refreshToken: 'stored-refresh',
        expiresIn: 180,
      );
      final identityService = _FakeDeviceIdentityService(
        const DeviceIdentity(osType: 'ANDROID', uuid: 'ignored'),
      );
      final apiService = _FakeDeviceApiService(
        const CreateDeviceResponse(
          secret: 'new-secret',
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          expiresIn: 180,
        ),
      );
      final tokenStorage = _FakeDeviceTokenStorage(initialSession: storedSession);
      final service = DeviceSessionService(
        identityService: identityService,
        deviceApiService: apiService,
        tokenStorage: tokenStorage,
      );

      final session = await service.loadOrCreateSession();

      expect(session.accessToken, 'stored-access');
      expect(session.refreshToken, 'stored-refresh');
      expect(identityService.loadCalls, 0);
      expect(apiService.createCalls, 0);
      expect(tokenStorage.writeCalls, 0);
    });
  });

  group('LineService', () {
    test('fetches from api and caches the latest line data', () async {
      final apiService = _FakeLineApiService(
        const [
          LineModel(
            id: 1,
            name: '1호선',
            code: 'LINE_1',
            color: '#0033A0',
          ),
        ],
      );
      final cacheStorage = _FakeLineCacheStorage();
      final service = LineService(
        apiService: apiService,
        cacheStorage: cacheStorage,
      );

      final lines = await service.loadForHome(accessToken: 'access-token');

      expect(apiService.fetchCalls, 1);
      expect(apiService.lastAccessToken, 'access-token');
      expect(cacheStorage.writeCalls, 1);
      expect(lines, hasLength(1));
      expect(lines.first.name, '1호선');
    });

    test('uses cached lines when api request fails', () async {
      final apiService = _FakeLineApiService(
        const [],
        error: const ApiException('Line API request failed.'),
      );
      final cacheStorage = _FakeLineCacheStorage(
        cachedLines: const [
          LineModel(
            id: 2,
            name: '2호선',
            code: 'LINE_2',
            color: '#00B140',
          ),
        ],
      );
      final service = LineService(
        apiService: apiService,
        cacheStorage: cacheStorage,
      );

      final lines = await service.loadForHome(accessToken: 'access-token');

      expect(apiService.fetchCalls, 1);
      expect(cacheStorage.readCalls, 1);
      expect(lines, hasLength(1));
      expect(lines.first.name, '2호선');
    });
  });
}

class _FakeDeviceIdentityStore implements DeviceIdentityStore {
  _FakeDeviceIdentityStore({this.initialUuid}) : storedUuid = initialUuid;

  final String? initialUuid;
  String? storedUuid;
  int writeCalls = 0;

  @override
  Future<String?> readUuid() async => storedUuid;

  @override
  Future<void> writeUuid(String uuid) async {
    storedUuid = uuid;
    writeCalls += 1;
  }
}

class _FakeDeviceIdentityService extends DeviceIdentityService {
  _FakeDeviceIdentityService(this.identity)
    : super(
        store: _FakeDeviceIdentityStore(initialUuid: identity.uuid),
        osTypeResolver: () => identity.osType,
        uuidGenerator: () => identity.uuid,
      );

  final DeviceIdentity identity;
  int loadCalls = 0;

  @override
  Future<DeviceIdentity> load() async {
    loadCalls += 1;
    return identity;
  }
}

class _FakeDeviceApiService extends DeviceApiService {
  _FakeDeviceApiService(this.response);

  final CreateDeviceResponse response;
  int createCalls = 0;

  @override
  Future<CreateDeviceResponse> createDevice(DeviceIdentity identity) async {
    createCalls += 1;
    return response;
  }
}

class _FakeDeviceTokenStorage implements DeviceTokenStorage {
  _FakeDeviceTokenStorage({this.initialSession}) : session = initialSession;

  final DeviceSession? initialSession;
  DeviceSession? session;
  int writeCalls = 0;

  @override
  Future<DeviceSession?> read() async => session;

  @override
  Future<void> write(DeviceSession session) async {
    this.session = session;
    writeCalls += 1;
  }
}

class _FakeLineApiService extends LineApiService {
  _FakeLineApiService(this.lines, {this.error});

  final List<LineModel> lines;
  final ApiException? error;
  int fetchCalls = 0;
  String? lastAccessToken;

  @override
  Future<List<LineModel>> fetchLines({required String accessToken}) async {
    fetchCalls += 1;
    lastAccessToken = accessToken;

    if (error != null) {
      throw error!;
    }

    return lines;
  }
}

class _FakeLineCacheStorage implements LineCacheStorage {
  _FakeLineCacheStorage({this.cachedLines = const []});

  final List<LineModel> cachedLines;
  int writeCalls = 0;
  int readCalls = 0;
  String? rawJson;

  @override
  Future<String?> readRawJson() async => rawJson;

  @override
  Future<List<LineModel>> readLines() async {
    readCalls += 1;
    return cachedLines;
  }

  @override
  Future<void> writeRawJson(String json) async {
    rawJson = json;
    writeCalls += 1;
  }
}
