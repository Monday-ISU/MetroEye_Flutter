import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:metroeye_flutter/core/device/device_session.dart';

abstract class DeviceTokenStorage {
  Future<DeviceSession?> read();

  Future<void> write(DeviceSession session);
}

class SecureDeviceTokenStorage implements DeviceTokenStorage {
  SecureDeviceTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'metroeye_device_session';

  final FlutterSecureStorage _storage;

  @override
  Future<DeviceSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DeviceSession.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> write(DeviceSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }
}
