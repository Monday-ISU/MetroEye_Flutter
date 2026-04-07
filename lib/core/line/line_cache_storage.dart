import 'dart:convert';

import 'package:metroeye_flutter/core/line/line_model.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/network/api_response.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LineCacheStorage {
  Future<void> writeRawJson(String json);

  Future<String?> readRawJson();

  Future<List<LineModel>> readLines();
}

class SharedPreferencesLineCacheStorage implements LineCacheStorage {
  static const _lineDataKey = 'metroeye_line_data';

  Future<SharedPreferences> get _preferences async {
    return SharedPreferences.getInstance();
  }

  @override
  Future<String?> readRawJson() async {
    final preferences = await _preferences;
    return preferences.getString(_lineDataKey);
  }

  @override
  Future<List<LineModel>> readLines() async {
    final rawJson = await readRawJson();
    if (rawJson == null || rawJson.isEmpty) {
      throw const ApiException('No cached line data found.');
    }

    final decoded = jsonDecode(rawJson);
    return asList(decoded)
        .map((item) => LineModel.fromJson(asMap(item)))
        .toList();
  }

  @override
  Future<void> writeRawJson(String json) async {
    final preferences = await _preferences;
    await preferences.setString(_lineDataKey, json);
  }
}
