import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metroeye_flutter/core/auth/auth_api_service.dart';
import 'package:metroeye_flutter/core/auth/auth_recovery_service.dart';
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
import 'package:metroeye_flutter/core/network/api_logging_interceptor.dart';
import 'package:metroeye_flutter/core/network/auth_recovery_interceptor.dart';
import 'package:metroeye_flutter/core/network/client_version_interceptor.dart';
import 'package:metroeye_flutter/core/station/adjacent_station_model.dart';
import 'package:metroeye_flutter/core/station/station_api_service.dart';
import 'package:metroeye_flutter/core/station/station_cache_storage.dart';
import 'package:metroeye_flutter/core/station/station_model.dart';
import 'package:metroeye_flutter/core/station/station_search_storage.dart';
import 'package:metroeye_flutter/core/station/station_service.dart';
import 'package:metroeye_flutter/core/station/train_arrival_model.dart';
import 'package:metroeye_flutter/ui/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DebugPrintCallback originalDebugPrint;
  late List<String> logs;

  setUp(() {
    originalDebugPrint = debugPrint;
    logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        logs.add(message);
      }
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

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
      final tokenStorage = _FakeDeviceTokenStorage(
        initialSession: storedSession,
      );
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

  group('AuthRecoveryService', () {
    test('updates access token with refresh token first', () async {
      const initialSession = DeviceSession(
        osType: 'ANDROID',
        uuid: 'device-uuid',
        secret: 'secret',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        expiresIn: 180,
      );
      final tokenStorage = _FakeDeviceTokenStorage(
        initialSession: initialSession,
      );
      final authApiService = _FakeAuthApiService(
        refreshTokenResults: const [
          RefreshTokenResponse(accessToken: 'new-access', expiresIn: 180),
        ],
      );
      final service = AuthRecoveryService(
        authApiService: authApiService,
        tokenStorage: tokenStorage,
      );

      final session = await service.recoverSession();

      expect(authApiService.clientCredentialCalls, 0);
      expect(authApiService.refreshTokenCalls, 1);
      expect(tokenStorage.writeCalls, 1);
      expect(session.accessToken, 'new-access');
      expect(session.refreshToken, 'old-refresh');
    });

    test('falls back to client credentials when refresh token fails', () async {
      const initialSession = DeviceSession(
        osType: 'ANDROID',
        uuid: 'device-uuid',
        secret: 'secret',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        expiresIn: 180,
      );
      final tokenStorage = _FakeDeviceTokenStorage(
        initialSession: initialSession,
      );
      final authApiService = _FakeAuthApiService(
        refreshTokenResults: const [
          ApiException(
            'Auth failed.',
            statusCode: 401,
            clientMessage: '',
            serverMessage: 'Authentication failed.',
          ),
        ],
        clientCredentialsResults: const [
          ClientCredentialsTokenResponse(
            accessToken: 'new-access',
            refreshToken: 'new-refresh',
            expiresIn: 180,
          ),
        ],
      );
      final service = AuthRecoveryService(
        authApiService: authApiService,
        tokenStorage: tokenStorage,
      );

      final session = await service.recoverSession();

      expect(authApiService.clientCredentialCalls, 1);
      expect(authApiService.refreshTokenCalls, 1);
      expect(tokenStorage.writeCalls, 1);
      expect(session.accessToken, 'new-access');
      expect(session.refreshToken, 'new-refresh');
    });

    test(
      'does not fall back when refresh token fails for a non-auth reason',
      () async {
        const initialSession = DeviceSession(
          osType: 'ANDROID',
          uuid: 'device-uuid',
          secret: 'secret',
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          expiresIn: 180,
        );
        final tokenStorage = _FakeDeviceTokenStorage(
          initialSession: initialSession,
        );
        final authApiService = _FakeAuthApiService(
          refreshTokenResults: const [
            ApiException('Temporary server failure.', statusCode: 500),
          ],
        );
        final service = AuthRecoveryService(
          authApiService: authApiService,
          tokenStorage: tokenStorage,
        );

        await expectLater(
          service.recoverSession(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              'Temporary server failure.',
            ),
          ),
        );
        expect(authApiService.refreshTokenCalls, 1);
        expect(authApiService.clientCredentialCalls, 0);
        expect(tokenStorage.writeCalls, 0);
      },
    );
  });

  group('LineService', () {
    test(
      'fetches from api and caches the latest line data when cache is empty',
      () async {
        final apiService = _FakeLineApiService(const [
          LineModel(lineId: 1, lineName: 'Line 1', color: '#0033A0'),
        ]);
        final cacheStorage = _FakeLineCacheStorage();
        final service = LineService(
          apiService: apiService,
          cacheStorage: cacheStorage,
        );

        final lines = await service.loadForHome();

        expect(apiService.fetchCalls, 1);
        expect(cacheStorage.readCalls, 1);
        expect(cacheStorage.writeCalls, 1);
        expect(lines, hasLength(1));
        expect(lines.first.lineName, 'Line 1');
      },
    );

    test('uses cached lines without calling api when cache exists', () async {
      final apiService = _FakeLineApiService(
        const [],
        error: const ApiException('Line API request failed.'),
      );
      final cacheStorage = _FakeLineCacheStorage(
        cachedLines: const [
          LineModel(lineId: 2, lineName: 'Line 2', color: '#00B140'),
        ],
      );
      final service = LineService(
        apiService: apiService,
        cacheStorage: cacheStorage,
      );

      final lines = await service.loadForHome();

      expect(apiService.fetchCalls, 0);
      expect(cacheStorage.readCalls, 1);
      expect(lines, hasLength(1));
      expect(lines.first.lineName, 'Line 2');
    });
  });

  group('StationService', () {
    test(
      'fetches from api and caches the latest station data when cache is empty',
      () async {
        final apiService = _FakeStationApiService(const [
          StationModel(
            stationId: 1,
            stationName: 'City Hall',
            stationCode: '1001',
            lineId: 1,
          ),
        ]);
        final cacheStorage = _FakeStationCacheStorage();
        final service = StationService(
          apiService: apiService,
          cacheStorage: cacheStorage,
        );

        final stations = await service.loadForHome();

        expect(apiService.fetchCalls, 1);
        expect(cacheStorage.readCalls, 1);
        expect(cacheStorage.writeCalls, 1);
        expect(stations, hasLength(1));
        expect(stations.first.stationName, 'City Hall');
      },
    );

    test(
      'uses cached stations without calling api when cache exists',
      () async {
        final apiService = _FakeStationApiService(const []);
        final cacheStorage = _FakeStationCacheStorage(
          cachedStations: const [
            StationModel(
              stationId: 2,
              stationName: 'Gangnam',
              stationCode: '222',
              lineId: 2,
            ),
          ],
        );
        final service = StationService(
          apiService: apiService,
          cacheStorage: cacheStorage,
        );

        final stations = await service.loadForHome();

        expect(apiService.fetchCalls, 0);
        expect(cacheStorage.readCalls, 1);
        expect(stations, hasLength(1));
        expect(stations.first.stationName, 'Gangnam');
      },
    );
  });

  group('StationApiService', () {
    test(
      'fetches adjacent stations with station id, line id, and size',
      () async {
        final adapter = _ScriptedHttpClientAdapter((options, callCount) {
          expect(options.path, '/v1/stations/141/adjacent-stations');
          expect(options.queryParameters['lineId'], 1);
          expect(options.queryParameters['size'], 3);
          return _jsonResponse({
            'clientMessage': '조회되었습니다.',
            'serverMessage': 'Success',
            'data': [
              {
                'directionType': 'PREV',
                'directionIndex': 1,
                'stationCodes': [
                  '1001080144',
                  '1001080143',
                  '1001080142',
                  '1001000141',
                ],
              },
            ],
          }, 200);
        });
        final dio = Dio(BaseOptions(baseUrl: 'https://dev-api.metroeye.click'))
          ..httpClientAdapter = adapter;
        final service = StationApiService(dio: dio);

        final tracks = await service.fetchAdjacentStations(
          stationId: 141,
          lineId: 1,
        );

        expect(tracks, hasLength(1));
        expect(tracks.first.directionType, AdjacentStationDirectionType.prev);
        expect(tracks.first.directionIndex, 1);
        expect(tracks.first.stationCodes.last, '1001000141');
      },
    );

    test('fetches train arrivals with station id', () async {
      final adapter = _ScriptedHttpClientAdapter((options, callCount) {
        expect(options.path, '/v1/stations/141/trains');
        expect(options.queryParameters['lineId'], 4);
        return _jsonResponse({
          'clientMessage': '조회되었습니다.',
          'serverMessage': 'Success',
          'data': [
            {
              'subwayId': '1004',
              'updnLine': '상행',
              'statnFid': '1001000140',
              'statnTid': '1001000142',
              'statnId': '1001000141',
              'btrainSttus': '일반',
              'btrainNo': '1234',
              'barvlDt': '180',
              'bstatnNm': '당고개',
              'arvlMsg2': '3분 후',
              'arvlMsg3': '사당',
              'arvlCd': '1',
              'lstcarAt': '0',
            },
          ],
        }, 200);
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://dev-api.metroeye.click'))
        ..httpClientAdapter = adapter;
      final service = StationApiService(dio: dio);

      final trains = await service.fetchTrains(stationId: 141, lineId: 4);

      expect(trains, hasLength(1));
      expect(trains.first, isA<TrainArrivalModel>());
      expect(trains.first.directionType, AdjacentStationDirectionType.prev);
      expect(trains.first.subwayId, '1004');
      expect(trains.first.btrainNo, '1234');
      expect(trains.first.arrivalSeconds, 180);
      expect(trains.first.bstatnNm, '당고개');
      expect(trains.first.arvlMsg2, '3분 후');
      expect(trains.first.arvlMsg3, '사당');
      expect(trains.first.arrivalCode, 1);
      expect(trains.first.isLastTrain, isFalse);
    });

    test(
      'maps line 2 inner and outer directions to adjacent track direction',
      () {
        final outerTrain = TrainArrivalModel.fromJson({
          'subwayId': '1002',
          'updnLine': '외선',
          'statnFid': '1002000202',
          'statnTid': '1002000243',
          'statnId': '1002000201',
          'btrainSttus': '일반',
          'btrainNo': '2263',
          'barvlDt': '150',
          'bstatnNm': '성수',
          'arvlMsg2': '2분 30초 후',
          'arvlMsg3': '을지로3가',
          'arvlCd': '99',
          'lstcarAt': '0',
        });
        final innerTrain = TrainArrivalModel.fromJson({
          'subwayId': '1002',
          'updnLine': '내선',
          'statnFid': '1002000243',
          'statnTid': '1002000202',
          'statnId': '1002000201',
          'btrainSttus': '일반',
          'btrainNo': '2226',
          'barvlDt': '180',
          'bstatnNm': '성수',
          'arvlMsg2': '3분 후',
          'arvlMsg3': '아현',
          'arvlCd': '99',
          'lstcarAt': '0',
        });

        expect(outerTrain.directionType, AdjacentStationDirectionType.prev);
        expect(innerTrain.directionType, AdjacentStationDirectionType.next);
      },
    );
  });

  group('filterStationHits', () {
    const lines = [
      LineModel(lineId: 2, lineName: 'Line 2', color: '#00B140'),
      LineModel(lineId: 3, lineName: 'Line 3', color: '#FC4C02'),
      LineModel(lineId: 4, lineName: 'Line 4', color: '#00A9E0'),
      LineModel(lineId: 6, lineName: 'Line 6', color: '#A9431E'),
      LineModel(lineId: 9, lineName: 'Line 9', color: '#BDB092'),
    ];
    const stations = [
      StationModel(
        stationId: 100,
        stationName: 'sa',
        stationCode: '100',
        lineId: 2,
      ),
      StationModel(
        stationId: 101,
        stationName: 'sacheon',
        stationCode: '101',
        lineId: 2,
      ),
      StationModel(
        stationId: 102,
        stationName: 'sacheon',
        stationCode: '102',
        lineId: 4,
      ),
      StationModel(
        stationId: 103,
        stationName: 'sinsa',
        stationCode: '103',
        lineId: 3,
      ),
      StationModel(
        stationId: 104,
        stationName: 'sapyeong',
        stationCode: '104',
        lineId: 6,
      ),
      StationModel(
        stationId: 105,
        stationName: 'yeoksamsageori',
        stationCode: '105',
        lineId: 9,
      ),
    ];

    test('prioritizes exact match before prefix and contains hits', () {
      final hits = filterStationHits(
        stations: stations,
        lines: lines,
        selectedLine: 'All',
        query: 'sa',
        allLines: 'All',
      );

      expect(hits.map((hit) => hit.station).toList(), [
        'sa',
        'sacheon',
        'sacheon',
        'sapyeong',
        'sinsa',
        'yeoksamsageori',
      ]);
    });

    test(
      'orders same station name by lower lineId first after relevance ties',
      () {
        final hits = filterStationHits(
          stations: stations,
          lines: lines,
          selectedLine: 'All',
          query: 'sa',
          allLines: 'All',
        );

        final sacheonHits =
            hits.where((hit) => hit.station == 'sacheon').toList();
        expect(sacheonHits[0].lineId, 2);
        expect(sacheonHits[1].lineId, 4);
      },
    );

    test(
      'prefers shorter station names before line order within same relevance',
      () {
        final hits = filterStationHits(
          stations: stations,
          lines: lines,
          selectedLine: 'All',
          query: 'sa',
          allLines: 'All',
        );

        final prefixHits =
            hits
                .where((hit) => hit.matchPriority == 1)
                .map((hit) => hit.station)
                .toList();

        expect(prefixHits, ['sacheon', 'sacheon', 'sapyeong']);
      },
    );

    test('keeps selected line filter while applying relevance priority', () {
      final hits = filterStationHits(
        stations: stations,
        lines: lines,
        selectedLine: 'Line 4',
        query: 'sa',
        allLines: 'All',
      );

      expect(hits, hasLength(1));
      expect(hits.first.line, 'Line 4');
      expect(hits.first.station, 'sacheon');
    });

    test('returns empty when query is blank', () {
      final hits = filterStationHits(
        stations: stations,
        lines: lines,
        selectedLine: 'All',
        query: '   ',
        allLines: 'All',
      );

      expect(hits, isEmpty);
    });
  });

  group('StationSearchStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'adds recent stations with newest first and removes duplicates',
      () async {
        var tick = 0;
        final storage = SharedPreferencesStationSearchStorage(
          now: () => DateTime(2026, 1, 1).add(Duration(minutes: tick++)),
        );

        await storage.addRecent(_stationSearchRecord(1, '이수', 4));
        await storage.addRecent(_stationSearchRecord(2, '사당', 2));
        final history = await storage.addRecent(
          _stationSearchRecord(1, '이수', 4),
        );

        expect(history.recents.map((record) => record.stationId), [1, 2]);
        expect(history.recents.first.stationName, '이수');
      },
    );

    test('keeps recent station list within ten items', () async {
      final storage = SharedPreferencesStationSearchStorage(
        now: () => DateTime(2026, 1, 1),
      );

      for (var index = 0; index < 12; index++) {
        await storage.addRecent(_stationSearchRecord(index, '역$index', index));
      }

      final history = await storage.readHistory();

      expect(history.recents, hasLength(10));
      expect(history.recents.first.stationId, 11);
      expect(history.recents.last.stationId, 2);
    });

    test('toggles favorite stations', () async {
      final storage = SharedPreferencesStationSearchStorage(
        now: () => DateTime(2026, 1, 1),
      );
      final record = _stationSearchRecord(1, '이수', 4);

      final added = await storage.toggleFavorite(record);
      final removed = await storage.toggleFavorite(record);

      expect(added.isFavorite(record), isTrue);
      expect(removed.isFavorite(record), isFalse);
      expect(removed.favorites, isEmpty);
    });

    test(
      'keeps favorites separate for the same station on different lines',
      () async {
        final storage = SharedPreferencesStationSearchStorage(
          now: () => DateTime(2026, 1, 1),
        );
        final line2Sadang = _stationSearchRecord(1, '사당', 2);
        final line4Sadang = _stationSearchRecord(1, '사당', 4);

        final added = await storage.toggleFavorite(line4Sadang);
        final updated = await storage.toggleFavorite(line2Sadang);
        final removedLine2 = await storage.toggleFavorite(line2Sadang);

        expect(added.isFavorite(line4Sadang), isTrue);
        expect(added.isFavorite(line2Sadang), isFalse);
        expect(updated.isFavorite(line4Sadang), isTrue);
        expect(updated.isFavorite(line2Sadang), isTrue);
        expect(removedLine2.isFavorite(line4Sadang), isTrue);
        expect(removedLine2.isFavorite(line2Sadang), isFalse);
      },
    );
  });

  group('ApiLoggingInterceptor', () {
    test('logs successful responses', () async {
      final adapter = _ScriptedHttpClientAdapter((options, _) {
        return _jsonResponse({
          'clientMessage': 'ok',
          'serverMessage': 'ok',
          'data': {'value': 1},
        }, 200);
      });
      final dio =
          Dio(BaseOptions(baseUrl: 'https://dev-api.metroeye.click'))
            ..httpClientAdapter = adapter
            ..interceptors.add(ApiLoggingInterceptor(apiName: 'Test API'));

      await dio.get<Map<String, dynamic>>('/test');

      final output = logs.join('\n');
      expect(output, contains('[Test API] response'));
      expect(output, contains('statusCode=200'));
      expect(output, contains('"value":1'));
    });
  });

  group('ClientVersionInterceptor', () {
    test('adds Client-Version header from app version loader', () async {
      final adapter = _ScriptedHttpClientAdapter((options, callCount) {
        expect(options.headers[ClientVersionInterceptor.headerName], '1.0.0');
        return _jsonResponse({'data': null}, 200);
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://dev-api.metroeye.click'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(
        ClientVersionInterceptor(loadClientVersion: () async => '1.0.0'),
      );

      await dio.get<void>('/v1/stations');

      expect(adapter.requests, hasLength(1));
    });
  });

  group('AuthRecoveryInterceptor', () {
    test(
      'retries protected request after 401 and logs both responses',
      () async {
        const initialSession = DeviceSession(
          osType: 'ANDROID',
          uuid: 'device-uuid',
          secret: 'secret',
          accessToken: 'old-access',
          refreshToken: 'refresh-token',
          expiresIn: 180,
        );
        final tokenStorage = _FakeDeviceTokenStorage(
          initialSession: initialSession,
        );
        final recoveryService = _FakeAuthRecoveryService(
          initialSession.copyWith(accessToken: 'new-access'),
        );
        final adapter = _ScriptedHttpClientAdapter((options, callCount) {
          final authorization = options.headers['Authorization'];

          if (callCount == 1) {
            expect(authorization, 'Bearer old-access');
            return _jsonResponse({
              'clientMessage': '',
              'serverMessage': 'Authentication failed.',
              'data': null,
            }, 401);
          }

          expect(authorization, 'Bearer new-access');
          return _jsonResponse({
            'clientMessage': '',
            'serverMessage': '',
            'data': [
              {'lineId': 1, 'lineName': 'Line 1', 'color': '#0033A0'},
            ],
          }, 200);
        });
        final dio = Dio(BaseOptions(baseUrl: 'https://dev-api.metroeye.click'))
          ..httpClientAdapter = adapter;
        dio.interceptors.add(
          AuthRecoveryInterceptor(
            apiName: 'Line API',
            dio: dio,
            tokenStorage: tokenStorage,
            authRecoveryService: recoveryService,
          ),
        );
        dio.interceptors.add(ApiLoggingInterceptor(apiName: 'Line API'));

        final service = LineApiService(dio: dio);
        final lines = await service.fetchLines();

        expect(lines, hasLength(1));
        expect(adapter.requests, hasLength(2));
        expect(recoveryService.recoverCalls, 1);

        final output = logs.join('\n');
        expect(output, contains('statusCode=401'));
        expect(output, contains('statusCode=200'));
      },
    );

    test(
      'treats auth failure messages as token errors even when status is not 401',
      () async {
        const initialSession = DeviceSession(
          osType: 'ANDROID',
          uuid: 'device-uuid',
          secret: 'secret',
          accessToken: 'old-access',
          refreshToken: 'refresh-token',
          expiresIn: 180,
        );
        final tokenStorage = _FakeDeviceTokenStorage(
          initialSession: initialSession,
        );
        final recoveryService = _FakeAuthRecoveryService(
          initialSession.copyWith(accessToken: 'new-access'),
        );
        final adapter = _ScriptedHttpClientAdapter((options, callCount) {
          if (callCount == 1) {
            return _jsonResponse({
              'clientMessage': '',
              'serverMessage': 'Authentication failed.',
              'data': null,
            }, 403);
          }

          return _jsonResponse({
            'clientMessage': '',
            'serverMessage': '',
            'data': [
              {'lineId': 1, 'lineName': 'Line 1', 'color': '#0033A0'},
            ],
          }, 200);
        });
        final dio = Dio(BaseOptions(baseUrl: 'https://dev-api.metroeye.click'))
          ..httpClientAdapter = adapter;
        dio.interceptors.add(
          AuthRecoveryInterceptor(
            apiName: 'Line API',
            dio: dio,
            tokenStorage: tokenStorage,
            authRecoveryService: recoveryService,
          ),
        );
        dio.interceptors.add(ApiLoggingInterceptor(apiName: 'Line API'));

        final service = LineApiService(dio: dio);
        final lines = await service.fetchLines();

        expect(lines, hasLength(1));
        expect(recoveryService.recoverCalls, 1);
        expect(adapter.requests, hasLength(2));
      },
    );
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
  _FakeDeviceApiService(this.response) : super(Dio());

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

class _FakeAuthApiService extends AuthApiService {
  _FakeAuthApiService({
    this.clientCredentialsResults = const <Object>[],
    this.refreshTokenResults = const <Object>[],
  }) : super(Dio());

  final List<Object> clientCredentialsResults;
  final List<Object> refreshTokenResults;
  int clientCredentialCalls = 0;
  int refreshTokenCalls = 0;

  @override
  Future<ClientCredentialsTokenResponse> issueWithClientCredentials({
    required String uuid,
    required String secret,
  }) async {
    final result = clientCredentialsResults[clientCredentialCalls];
    clientCredentialCalls += 1;

    if (result is ApiException) {
      throw result;
    }

    return result as ClientCredentialsTokenResponse;
  }

  @override
  Future<RefreshTokenResponse> issueWithRefreshToken({
    required String refreshToken,
  }) async {
    final result = refreshTokenResults[refreshTokenCalls];
    refreshTokenCalls += 1;

    if (result is ApiException) {
      throw result;
    }

    return result as RefreshTokenResponse;
  }
}

class _FakeAuthRecoveryService extends AuthRecoveryService {
  _FakeAuthRecoveryService(this.result)
    : super(
        authApiService: _FakeAuthApiService(),
        tokenStorage: _FakeDeviceTokenStorage(),
      );

  final DeviceSession result;
  int recoverCalls = 0;

  @override
  Future<DeviceSession> recoverSession() async {
    recoverCalls += 1;
    return result;
  }
}

class _FakeLineApiService extends LineApiService {
  _FakeLineApiService(this.lines, {this.error}) : super(dio: Dio());

  final List<LineModel> lines;
  final ApiException? error;
  int fetchCalls = 0;

  @override
  Future<List<LineModel>> fetchLines() async {
    fetchCalls += 1;

    if (error != null) {
      throw error!;
    }

    return lines;
  }
}

class _FakeLineCacheStorage implements LineCacheStorage {
  _FakeLineCacheStorage({this.cachedLines = const [], bool hasCache = false})
    : _hasCache = hasCache || cachedLines.isNotEmpty;

  final List<LineModel> cachedLines;
  int writeCalls = 0;
  int readCalls = 0;
  String? rawJson;
  bool _hasCache;

  @override
  Future<String?> readRawJson() async => rawJson;

  @override
  Future<List<LineModel>> readLines() async {
    readCalls += 1;

    if (!_hasCache) {
      throw const ApiException('No cached line data found.');
    }

    return cachedLines;
  }

  @override
  Future<void> writeRawJson(String json) async {
    rawJson = json;
    _hasCache = true;
    writeCalls += 1;
  }
}

class _FakeStationApiService extends StationApiService {
  _FakeStationApiService(this.stations) : super(dio: Dio());

  final List<StationModel> stations;
  int fetchCalls = 0;

  @override
  Future<List<StationModel>> fetchStations() async {
    fetchCalls += 1;

    return stations;
  }
}

class _FakeStationCacheStorage implements StationCacheStorage {
  _FakeStationCacheStorage({
    this.cachedStations = const [],
    bool hasCache = false,
  }) : _hasCache = hasCache || cachedStations.isNotEmpty;

  final List<StationModel> cachedStations;
  int writeCalls = 0;
  int readCalls = 0;
  String? rawJson;
  bool _hasCache;

  @override
  Future<String?> readRawJson() async => rawJson;

  @override
  Future<List<StationModel>> readStations() async {
    readCalls += 1;

    if (!_hasCache) {
      throw const ApiException('No cached station data found.');
    }

    return cachedStations;
  }

  @override
  Future<void> writeRawJson(String json) async {
    rawJson = json;
    _hasCache = true;
    writeCalls += 1;
  }
}

class _ScriptedHttpClientAdapter implements HttpClientAdapter {
  _ScriptedHttpClientAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options, int callCount)
  _handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _handler(options, requests.length);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

StationSearchRecord _stationSearchRecord(
  int stationId,
  String stationName,
  int lineId,
) {
  return StationSearchRecord(
    stationId: stationId,
    stationCode: 'code-$stationId',
    stationName: stationName,
    lineId: lineId,
    lineName: 'Line $lineId',
    lineColor: '#49729B',
    updatedAt: DateTime(2026, 1, 1),
  );
}
