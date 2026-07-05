import 'dart:convert';

import 'package:metroeye_flutter/core/network/api_response.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class StationSearchStorage {
  Future<StationSearchHistory> readHistory();

  Future<StationSearchHistory> addRecent(StationSearchRecord record);

  Future<StationSearchHistory> toggleFavorite(StationSearchRecord record);
}

class StationSearchRecord {
  const StationSearchRecord({
    required this.stationId,
    required this.stationCode,
    required this.stationName,
    required this.lineId,
    required this.lineName,
    required this.lineColor,
    required this.updatedAt,
  });

  factory StationSearchRecord.fromJson(Map<String, dynamic> json) {
    return StationSearchRecord(
      stationId: (json['stationId'] as num).toInt(),
      stationCode: json['stationCode'] as String,
      stationName: json['stationName'] as String,
      lineId: (json['lineId'] as num).toInt(),
      lineName: json['lineName'] as String,
      lineColor: json['lineColor'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final int stationId;
  final String stationCode;
  final String stationName;
  final int lineId;
  final String lineName;
  final String lineColor;
  final DateTime updatedAt;

  String get key => '$lineId:$stationCode';

  StationSearchRecord copyWith({DateTime? updatedAt}) {
    return StationSearchRecord(
      stationId: stationId,
      stationCode: stationCode,
      stationName: stationName,
      lineId: lineId,
      lineName: lineName,
      lineColor: lineColor,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,
      'stationCode': stationCode,
      'stationName': stationName,
      'lineId': lineId,
      'lineName': lineName,
      'lineColor': lineColor,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class StationSearchHistory {
  const StationSearchHistory({required this.favorites, required this.recents});

  factory StationSearchHistory.empty() {
    return const StationSearchHistory(
      favorites: <StationSearchRecord>[],
      recents: <StationSearchRecord>[],
    );
  }

  factory StationSearchHistory.fromJson(Map<String, dynamic> json) {
    return StationSearchHistory(
      favorites:
          asList(
            json['favorites'],
          ).map((item) => StationSearchRecord.fromJson(asMap(item))).toList(),
      recents:
          asList(
            json['recents'],
          ).map((item) => StationSearchRecord.fromJson(asMap(item))).toList(),
    );
  }

  final List<StationSearchRecord> favorites;
  final List<StationSearchRecord> recents;

  bool isFavorite(StationSearchRecord record) {
    return favorites.any((favorite) => favorite.key == record.key);
  }

  Map<String, dynamic> toJson() {
    return {
      'favorites': favorites.map((record) => record.toJson()).toList(),
      'recents': recents.map((record) => record.toJson()).toList(),
    };
  }
}

class SharedPreferencesStationSearchStorage implements StationSearchStorage {
  SharedPreferencesStationSearchStorage({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _historyKey = 'metroeye_station_search_history';
  static const _maxRecentCount = 10;

  final DateTime Function() _now;

  Future<SharedPreferences> get _preferences async {
    return SharedPreferences.getInstance();
  }

  @override
  Future<StationSearchHistory> readHistory() async {
    final preferences = await _preferences;
    final rawJson = preferences.getString(_historyKey);
    if (rawJson == null || rawJson.isEmpty) {
      return StationSearchHistory.empty();
    }

    try {
      return StationSearchHistory.fromJson(asMap(jsonDecode(rawJson)));
    } on Object {
      return StationSearchHistory.empty();
    }
  }

  @override
  Future<StationSearchHistory> addRecent(StationSearchRecord record) async {
    final history = await readHistory();
    final updatedRecord = record.copyWith(updatedAt: _now());
    final recents =
        [
          updatedRecord,
          ...history.recents.where((item) => item.key != updatedRecord.key),
        ].take(_maxRecentCount).toList();

    return _writeHistory(
      StationSearchHistory(favorites: history.favorites, recents: recents),
    );
  }

  @override
  Future<StationSearchHistory> toggleFavorite(
    StationSearchRecord record,
  ) async {
    final history = await readHistory();
    final updatedRecord = record.copyWith(updatedAt: _now());
    final isFavorite = history.favorites.any(
      (item) => item.key == updatedRecord.key,
    );
    final favorites =
        isFavorite
            ? history.favorites
                .where((item) => item.key != updatedRecord.key)
                .toList()
            : [
              updatedRecord,
              ...history.favorites.where(
                (item) => item.key != updatedRecord.key,
              ),
            ];

    return _writeHistory(
      StationSearchHistory(favorites: favorites, recents: history.recents),
    );
  }

  Future<StationSearchHistory> _writeHistory(
    StationSearchHistory history,
  ) async {
    final preferences = await _preferences;
    await preferences.setString(_historyKey, jsonEncode(history.toJson()));
    return history;
  }
}
