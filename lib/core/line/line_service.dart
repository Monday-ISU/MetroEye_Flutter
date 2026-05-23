import 'dart:convert';

import 'package:metroeye_flutter/core/line/line_api_service.dart';
import 'package:metroeye_flutter/core/line/line_cache_storage.dart';
import 'package:metroeye_flutter/core/line/line_model.dart';
import 'package:metroeye_flutter/core/network/api_exception.dart';

class LineLoadResult {
  const LineLoadResult({
    required this.lines,
    required this.debugText,
  });

  final List<LineModel> lines;
  final String debugText;
}

class LineService {
  LineService({
    LineApiService? apiService,
    LineCacheStorage? cacheStorage,
  }) : _apiService = apiService ?? LineApiService(),
       _cacheStorage = cacheStorage ?? SharedPreferencesLineCacheStorage();

  final LineApiService _apiService;
  final LineCacheStorage _cacheStorage;

  Future<List<LineModel>> fetchAndCacheLines() async {
    final lines = await _apiService.fetchLines();
    final rawJson = jsonEncode(lines.map((line) => line.toJson()).toList());
    await _cacheStorage.writeRawJson(rawJson);
    return lines;
  }

  Future<List<LineModel>> loadCachedLines() {
    return _cacheStorage.readLines();
  }

  Future<List<LineModel>> loadForHome() async {
    final result = await loadForHomeWithDebug();
    return result.lines;
  }

  Future<LineLoadResult> loadForHomeWithDebug() async {
    try {
      final cachedLines = await loadCachedLines();
      return LineLoadResult(
        lines: cachedLines,
        debugText: [
          'Line source: cache',
          'cachedLineCount=${cachedLines.length}',
        ].join('\n'),
      );
    } on ApiException catch (cacheError) {
      try {
        final lines = await fetchAndCacheLines();
        return LineLoadResult(
          lines: lines,
          debugText: [
            'Line source: api',
            'cacheError=${cacheError.message}',
            if (cacheError.details != null && cacheError.details!.isNotEmpty)
              cacheError.details!,
            'lineCount=${lines.length}',
            'cacheUpdated=true',
          ].join('\n'),
        );
      } on ApiException catch (apiError) {
        throw ApiException(
          'Line bootstrap failed.',
          details: [
            'Line source: failed',
            'cacheError=${cacheError.message}',
            if (cacheError.details != null && cacheError.details!.isNotEmpty)
              cacheError.details!,
            'lineApiError=${apiError.message}',
            if (apiError.details != null && apiError.details!.isNotEmpty)
              apiError.details!,
          ].join('\n'),
        );
      }
    }
  }
}
