import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:metroeye_flutter/core/device/device_identity.dart';
import 'package:uuid/uuid.dart';

typedef OsTypeResolver = String Function();
typedef UuidGenerator = String Function();

abstract class DeviceIdentityStore {
  Future<String?> readUuid();

  Future<void> writeUuid(String uuid);
}

class SecureDeviceIdentityStore implements DeviceIdentityStore {
  SecureDeviceIdentityStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _uuidKey = 'metroeye_device_uuid';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readUuid() {
    return _storage.read(key: _uuidKey);
  }

  @override
  Future<void> writeUuid(String uuid) {
    return _storage.write(key: _uuidKey, value: uuid);
  }
}

class DeviceIdentityService {
  DeviceIdentityService({
    DeviceIdentityStore? store,
    OsTypeResolver? osTypeResolver,
    UuidGenerator? uuidGenerator,
  }) : _store = store ?? SecureDeviceIdentityStore(),
       _osTypeResolver = osTypeResolver ?? _defaultOsTypeResolver,
       _uuidGenerator = uuidGenerator ?? (() => const Uuid().v4());

  final DeviceIdentityStore _store;
  final OsTypeResolver _osTypeResolver;
  final UuidGenerator _uuidGenerator;

  Future<DeviceIdentity> load() async {
    final storedUuid = await _store.readUuid();
    final uuid = storedUuid ?? _uuidGenerator();

    if (storedUuid == null) {
      await _store.writeUuid(uuid);
    }

    return DeviceIdentity(
      osType: _osTypeResolver(),
      uuid: uuid,
    );
  }

  static String _defaultOsTypeResolver() {
    if (Platform.isIOS) {
      return 'IOS';
    }
    return 'ANDROID';
  }
}
