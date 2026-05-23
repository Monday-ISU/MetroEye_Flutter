import 'dart:convert';

import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/station/station_api_service.dart';
import 'package:metroeye_flutter/core/station/station_cache_storage.dart';
import 'package:metroeye_flutter/core/station/station_model.dart';

class StationLoadResult {
  const StationLoadResult({required this.stations, required this.debugText});

  final List<StationModel> stations;
  final String debugText;
}

class StationService {
  StationService({
    StationApiService? apiService,
    StationCacheStorage? cacheStorage,
  }) : _apiService = apiService ?? StationApiService(),
       _cacheStorage = cacheStorage ?? SharedPreferencesStationCacheStorage();

  final StationApiService _apiService;
  final StationCacheStorage _cacheStorage;

  Future<List<StationModel>> fetchAndCacheStations() async {
    final stations = await _apiService.fetchStations();
    final rawJson = jsonEncode(
      stations.map((station) => station.toJson()).toList(),
    );
    await _cacheStorage.writeRawJson(rawJson);
    return stations;
  }

  Future<List<StationModel>> loadCachedStations() {
    return _cacheStorage.readStations();
  }

  Future<List<StationModel>> loadForHome() async {
    final result = await loadForHomeWithDebug();
    return result.stations;
  }

  Future<StationLoadResult> loadForHomeWithDebug() async {
    try {
      final cachedStations = await loadCachedStations();
      return StationLoadResult(
        stations: cachedStations,
        debugText: [
          'Station source: cache',
          'cachedStationCount=${cachedStations.length}',
        ].join('\n'),
      );
    } on ApiException catch (cacheError) {
      try {
        final stations = await fetchAndCacheStations();
        return StationLoadResult(
          stations: stations,
          debugText: [
            'Station source: api',
            'cacheError=${cacheError.message}',
            if (cacheError.details != null && cacheError.details!.isNotEmpty)
              cacheError.details!,
            'stationCount=${stations.length}',
            'cacheUpdated=true',
          ].join('\n'),
        );
      } on ApiException catch (apiError) {
        throw ApiException(
          'Station bootstrap failed.',
          details: [
            'Station source: failed',
            'cacheError=${cacheError.message}',
            if (cacheError.details != null && cacheError.details!.isNotEmpty)
              cacheError.details!,
            'stationApiError=${apiError.message}',
            if (apiError.details != null && apiError.details!.isNotEmpty)
              apiError.details!,
          ].join('\n'),
        );
      }
    }
  }
}
