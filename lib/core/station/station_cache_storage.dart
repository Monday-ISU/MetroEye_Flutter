import 'dart:convert';

import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/network/api_response.dart';
import 'package:metroeye_flutter/core/station/station_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class StationCacheStorage {
  Future<void> writeRawJson(String json);

  Future<String?> readRawJson();

  Future<List<StationModel>> readStations();
}

class SharedPreferencesStationCacheStorage implements StationCacheStorage {
  static const _stationDataKey = 'metroeye_station_data';

  Future<SharedPreferences> get _preferences async {
    return SharedPreferences.getInstance();
  }

  @override
  Future<String?> readRawJson() async {
    final preferences = await _preferences;
    return preferences.getString(_stationDataKey);
  }

  @override
  Future<List<StationModel>> readStations() async {
    final rawJson = await readRawJson();
    if (rawJson == null || rawJson.isEmpty) {
      throw const ApiException('No cached station data found.');
    }

    try {
      final decoded = jsonDecode(rawJson);
      return asList(
        decoded,
      ).map((item) => StationModel.fromJson(asMap(item))).toList();
    } on Object catch (error) {
      throw ApiException(
        'Cached station data is invalid.',
        details: error.toString(),
      );
    }
  }

  @override
  Future<void> writeRawJson(String json) async {
    final preferences = await _preferences;
    await preferences.setString(_stationDataKey, json);
  }
}
