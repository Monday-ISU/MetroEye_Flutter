import 'package:flutter/material.dart';
import 'package:metroeye_flutter/core/station/adjacent_station_model.dart';
import 'package:metroeye_flutter/core/station/station_api_service.dart';
import 'package:metroeye_flutter/core/station/station_cache_storage.dart';
import 'package:metroeye_flutter/core/station/station_model.dart';
import 'package:metroeye_flutter/core/station/station_search_storage.dart';
import 'package:metroeye_flutter/core/station/train_arrival_model.dart';
import 'package:metroeye_flutter/core/theme/app_colors.dart';
import 'package:metroeye_flutter/core/theme/app_typography.dart';

class RealtimeTrainPositionLine {
  const RealtimeTrainPositionLine({
    required this.lineId,
    required this.lineName,
    required this.color,
  });

  final int lineId;
  final String lineName;
  final Color color;

  String get label => _lineLabel(lineName, lineId);
}

class RealtimeTrainPositionScreen extends StatefulWidget {
  RealtimeTrainPositionScreen({
    super.key,
    required this.stationName,
    required this.stationId,
    required this.stationCode,
    required this.lineId,
    required this.connectedLines,
    StationApiService? stationApiService,
    StationCacheStorage? stationCacheStorage,
    StationSearchStorage? stationSearchStorage,
  }) : _stationApiService = stationApiService ?? StationApiService(),
       _stationCacheStorage =
           stationCacheStorage ?? SharedPreferencesStationCacheStorage(),
       _stationSearchStorage =
           stationSearchStorage ?? SharedPreferencesStationSearchStorage(),
       assert(connectedLines.isNotEmpty);

  final String stationName;
  final int stationId;
  final String stationCode;
  final int lineId;
  final List<RealtimeTrainPositionLine> connectedLines;
  final StationApiService _stationApiService;
  final StationCacheStorage _stationCacheStorage;
  final StationSearchStorage _stationSearchStorage;

  @override
  State<RealtimeTrainPositionScreen> createState() {
    return _RealtimeTrainPositionScreenState();
  }
}

class _RealtimeTrainPositionScreenState
    extends State<RealtimeTrainPositionScreen> {
  late RealtimeTrainPositionLine _selectedLine;
  late Future<List<_AdjacentStationTrack>> _tracksFuture;
  List<_AdjacentStationTrack>? _visibleTracks;
  _TrainPosition? _selectedTrain;
  StationSearchHistory _searchHistory = StationSearchHistory.empty();
  _SelectedStationContext? _favoriteStationContext;
  bool _isRefreshing = true;

  @override
  void initState() {
    super.initState();
    _selectedLine = _resolveSelectedLine();
    _tracksFuture = _loadAdjacentStationTracks();
    _watchTracksFuture(_tracksFuture);
    _loadSearchHistory();
    _loadFavoriteStationContext();
  }

  @override
  void didUpdateWidget(covariant RealtimeTrainPositionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lineId != widget.lineId ||
        oldWidget.stationId != widget.stationId ||
        oldWidget.stationCode != widget.stationCode ||
        oldWidget.connectedLines != widget.connectedLines) {
      _selectedLine = _resolveSelectedLine();
      _tracksFuture = _loadAdjacentStationTracks();
      _visibleTracks = null;
      _selectedTrain = null;
      _favoriteStationContext = null;
      _isRefreshing = true;
      _watchTracksFuture(_tracksFuture);
      _loadSearchHistory();
      _loadFavoriteStationContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedStationName = _displayStationName(widget.stationName);
    final lineColor = _selectedLine.color;
    final selectedFavoriteRecord = _selectedLineSearchRecord();
    final isFavorite = _searchHistory.isFavorite(selectedFavoriteRecord);

    return Scaffold(
      backgroundColor: AppColors.gray1,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _MetroEyeHeader(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$normalizedStationName역',
                        style: AppTypography.body4.copyWith(
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (final line in widget.connectedLines) ...[
                            _LineBadge(
                              data: _LineBadgeData(
                                label: line.label,
                                color: line.color,
                                selected: line.lineId == _selectedLine.lineId,
                              ),
                              onTap: () {
                                _selectLine(line);
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _FavoriteToggleButton(
                  isFavorite: isFavorite,
                  color: lineColor,
                  onPressed: _toggleFavorite,
                ),
                const SizedBox(width: 8),
                _RefreshControl(
                  isRefreshing: _isRefreshing,
                  color: lineColor,
                  onPressed: () {
                    _refreshTracks();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '실시간 위치',
              style: AppTypography.body4.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 17),
            FutureBuilder<List<_AdjacentStationTrack>>(
              future: _tracksFuture,
              initialData: _visibleTracks,
              builder: (context, snapshot) {
                final tracks =
                    snapshot.data ??
                    _visibleTracks ??
                    const <_AdjacentStationTrack>[];

                if (snapshot.connectionState != ConnectionState.done &&
                    tracks.isEmpty) {
                  return const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError && tracks.isEmpty) {
                  debugPrint('Adjacent station load error: ${snapshot.error}');
                  debugPrint(
                    'Adjacent station load stack: ${snapshot.stackTrace}',
                  );
                  return const _RailStatusMessage(
                    message: '인접 역 정보를 불러오지 못했습니다.',
                  );
                }

                if (tracks.isEmpty) {
                  return const _RailStatusMessage(message: '인접 역 정보가 없습니다.');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < tracks.length; index++) ...[
                      if (index > 0) const SizedBox(height: 20),
                      _RailDirectionView(
                        track: tracks[index],
                        lineColor: lineColor,
                        selectedTrainId: _selectedTrain?.id,
                        onTrainSelected: _selectTrain,
                      ),
                      if (_isSelectedTrainInTrack(tracks[index])) ...[
                        const SizedBox(height: 12),
                        _SelectedTrainServicePanel(
                          train: _selectedTrain!,
                          lineColor: lineColor,
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectLine(RealtimeTrainPositionLine line) {
    if (line.lineId == _selectedLine.lineId) {
      return;
    }

    setState(() {
      _selectedLine = line;
      _favoriteStationContext = null;
    });
    _loadFavoriteStationContext();
    _refreshTracks(preserveVisibleTracks: false);
  }

  Future<void> _loadSearchHistory() async {
    try {
      final history = await widget._stationSearchStorage.readHistory();
      if (!mounted) {
        return;
      }

      setState(() {
        _searchHistory = history;
      });
    } on Object catch (error, stackTrace) {
      debugPrint('Station search history load error: $error');
      debugPrint('Station search history load stack: $stackTrace');
    }
  }

  Future<void> _loadFavoriteStationContext() async {
    final selectedLineId = _selectedLine.lineId;
    final stations = await _loadCachedStationsSafely();
    final selectedStation = _resolveSelectedStation(stations);
    if (!mounted || _selectedLine.lineId != selectedLineId) {
      return;
    }

    setState(() {
      _favoriteStationContext = selectedStation;
    });
  }

  Future<void> _toggleFavorite() async {
    final stations = await _loadCachedStationsSafely();
    final selectedStation = _resolveSelectedStation(stations);
    final history = await widget._stationSearchStorage.toggleFavorite(
      _selectedLineSearchRecord(selectedStation: selectedStation),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteStationContext = selectedStation;
      _searchHistory = history;
    });
  }

  void _refreshTracks({bool preserveVisibleTracks = true}) {
    final future = _loadAdjacentStationTracks();
    setState(() {
      _tracksFuture = future;
      if (!preserveVisibleTracks) {
        _visibleTracks = null;
        _selectedTrain = null;
      }
      _isRefreshing = true;
    });
    _watchTracksFuture(future);
  }

  void _watchTracksFuture(Future<List<_AdjacentStationTrack>> future) {
    future.then(
      (tracks) {
        if (!mounted || !identical(_tracksFuture, future)) {
          return;
        }

        setState(() {
          _visibleTracks = tracks;
          _selectedTrain = _updatedSelectedTrain(tracks);
          _isRefreshing = false;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || !identical(_tracksFuture, future)) {
          return;
        }

        debugPrint('Adjacent station load error: $error');
        debugPrint('Adjacent station load stack: $stackTrace');
        setState(() {
          _isRefreshing = false;
        });
      },
    );
  }

  void _selectTrain(_TrainPosition train) {
    setState(() {
      _selectedTrain = train;
    });
  }

  bool _isSelectedTrainInTrack(_AdjacentStationTrack track) {
    final selectedTrainId = _selectedTrain?.id;
    if (selectedTrainId == null) {
      return false;
    }

    return track.trains.any((train) => train.id == selectedTrainId);
  }

  _TrainPosition? _updatedSelectedTrain(List<_AdjacentStationTrack> tracks) {
    final selectedTrainId = _selectedTrain?.id;
    if (selectedTrainId == null) {
      return null;
    }

    for (final track in tracks) {
      for (final train in track.trains) {
        if (train.id == selectedTrainId) {
          return train;
        }
      }
    }

    return null;
  }

  Future<List<_AdjacentStationTrack>> _loadAdjacentStationTracks() async {
    final cachedStations = await _loadCachedStationsSafely();
    final selectedStation = _resolveSelectedStation(cachedStations);
    final adjacentStationsFuture = widget._stationApiService
        .fetchAdjacentStations(
          stationId: selectedStation.stationId,
          lineId: _selectedLine.lineId,
          size: 3,
        );

    final adjacentStations = await adjacentStationsFuture;
    final tracks = _buildAdjacentStationTracks(
      adjacentStations: adjacentStations,
      stations: cachedStations,
      currentStationCode: selectedStation.stationCode,
    );
    final trainArrivals = await _loadTrainArrivalsForTrackBasisStationsSafely(
      tracks: tracks,
      stations: cachedStations,
      selectedStation: selectedStation,
    );

    return _attachTrainArrivalsToTracks(
      tracks: tracks,
      trainArrivals: trainArrivals,
      includeRunningArrivals: false,
    );
  }

  StationSearchRecord _selectedLineSearchRecord({
    _SelectedStationContext? selectedStation,
  }) {
    final station = selectedStation ?? _favoriteStationContext;
    return StationSearchRecord(
      stationId: station?.stationId ?? widget.stationId,
      stationCode: station?.stationCode ?? widget.stationCode,
      stationName: _displayStationName(widget.stationName),
      lineId: _selectedLine.lineId,
      lineName: _selectedLine.lineName,
      lineColor: _colorToHex(_selectedLine.color),
      updatedAt: DateTime.now(),
    );
  }

  Future<List<StationModel>> _loadCachedStationsSafely() async {
    try {
      return await widget._stationCacheStorage.readStations();
    } on Object catch (error) {
      debugPrint('Station cache read failed for adjacent tracks: $error');
      return const <StationModel>[];
    }
  }

  Future<List<TrainArrivalModel>> _loadTrainArrivalsSafely({
    required Future<List<TrainArrivalModel>> future,
    required _SelectedStationContext selectedStation,
  }) async {
    try {
      final trainArrivals = await future;
      debugPrint(
        [
          'Train arrivals loaded',
          'stationId=${selectedStation.stationId}',
          'stationCode=${selectedStation.stationCode}',
          'lineId=${_selectedLine.lineId}',
          'count=${trainArrivals.length}',
          'data=${trainArrivals.map((arrival) => arrival.toJson()).toList()}',
        ].join('\n'),
      );
      return trainArrivals;
    } on Object catch (error, stackTrace) {
      debugPrint('Train arrival load error: $error');
      debugPrint('Train arrival load stack: $stackTrace');
      return const <TrainArrivalModel>[];
    }
  }

  Future<List<TrainArrivalModel>>
  _loadTrainArrivalsForTrackBasisStationsSafely({
    required List<_AdjacentStationTrack> tracks,
    required List<StationModel> stations,
    required _SelectedStationContext selectedStation,
  }) async {
    final basisStations = _trainArrivalBasisStations(
      tracks: tracks,
      stations: stations,
      selectedStation: selectedStation,
    );
    final trainArrivalGroups = await Future.wait(
      basisStations.map(
        (basisStation) => _loadTrainArrivalsSafely(
          future: widget._stationApiService.fetchTrains(
            stationId: basisStation.stationId,
            lineId: _selectedLine.lineId,
          ),
          selectedStation: basisStation,
        ),
      ),
    );

    final trainArrivalsByBasisStationCode = <String, List<TrainArrivalModel>>{
      for (var index = 0; index < basisStations.length; index++)
        basisStations[index].stationCode: trainArrivalGroups[index],
    };
    final selectedStationArrivals =
        trainArrivalGroups.isEmpty
            ? const <TrainArrivalModel>[]
            : trainArrivalGroups.first;
    final departedArrivals = _departedSecondPreviousArrivals(
      tracks: tracks,
      selectedStationArrivals: selectedStationArrivals,
      trainArrivalsByBasisStationCode: trainArrivalsByBasisStationCode,
    );

    return [
      for (final trainArrivals in trainArrivalGroups) ...trainArrivals,
      ...departedArrivals,
    ];
  }

  List<_SelectedStationContext> _trainArrivalBasisStations({
    required List<_AdjacentStationTrack> tracks,
    required List<StationModel> stations,
    required _SelectedStationContext selectedStation,
  }) {
    final stationsByCode = {
      for (final station in stations)
        if (station.lineId == _selectedLine.lineId)
          station.stationCode: _SelectedStationContext(
            stationId: station.stationId,
            stationCode: station.stationCode,
          ),
    };
    final basisStationsByCode = <String, _SelectedStationContext>{
      selectedStation.stationCode: selectedStation,
    };

    for (final track in tracks) {
      final secondPreviousStationCode = _secondPreviousStationCode(track);
      if (secondPreviousStationCode == null) {
        continue;
      }

      final station = stationsByCode[secondPreviousStationCode];
      if (station == null) {
        debugPrint(
          'Train arrival basis station skipped because station id is missing: '
          '$secondPreviousStationCode',
        );
        continue;
      }

      basisStationsByCode.putIfAbsent(station.stationCode, () => station);
    }

    return basisStationsByCode.values.toList();
  }

  _SelectedStationContext _resolveSelectedStation(List<StationModel> stations) {
    final normalizedStationName = _displayStationName(widget.stationName);
    for (final station in stations) {
      if (_displayStationName(station.stationName) == normalizedStationName &&
          station.lineId == _selectedLine.lineId) {
        return _SelectedStationContext(
          stationId: station.stationId,
          stationCode: station.stationCode,
        );
      }
    }

    return _SelectedStationContext(
      stationId: widget.stationId,
      stationCode: widget.stationCode,
    );
  }

  List<_AdjacentStationTrack> _buildAdjacentStationTracks({
    required List<AdjacentStationModel> adjacentStations,
    required List<StationModel> stations,
    required String currentStationCode,
  }) {
    final stationNamesByCode = {
      for (final station in stations)
        station.stationCode: _displayStationName(station.stationName),
    };
    final sortedAdjacentStations = [...adjacentStations]
      ..sort(_compareAdjacentStations);

    final tracks =
        sortedAdjacentStations
            .where((track) => track.stationCodes.isNotEmpty)
            .map((track) {
              final isPrev =
                  track.directionType == AdjacentStationDirectionType.prev;
              final currentStationIndex = _currentStationSlotIndex(
                isPrev: isPrev,
              );
              final stationCodeSlots = _fixedStationCodeSlots(
                stationCodes: track.stationCodes,
                currentStationCode: currentStationCode,
                currentStationIndex: currentStationIndex,
                isPrev: isPrev,
              );

              return _AdjacentStationTrack(
                directionType: track.directionType,
                directionIndex: track.directionIndex,
                stationCodeSlots: stationCodeSlots,
                stationNames:
                    stationCodeSlots
                        .map((code) => stationNamesByCode[code] ?? code)
                        .toList(),
                currentStationIndex: currentStationIndex,
                arrowDirection:
                    isPrev
                        ? _RailArrowDirection.right
                        : _RailArrowDirection.left,
                flipTrainIcon: isPrev,
                trains: const [],
              );
            })
            .toList();
    return tracks;
  }

  RealtimeTrainPositionLine _resolveSelectedLine() {
    for (final line in widget.connectedLines) {
      if (line.lineId == widget.lineId) {
        return line;
      }
    }
    return widget.connectedLines.first;
  }

  static String _displayStationName(String name) {
    return _normalizeStationNameForMatch(name);
  }
}

class _SelectedStationContext {
  const _SelectedStationContext({
    required this.stationId,
    required this.stationCode,
  });

  final int stationId;
  final String stationCode;
}

int _compareAdjacentStations(AdjacentStationModel a, AdjacentStationModel b) {
  final directionOrder = _directionSortOrder(
    a.directionType,
  ).compareTo(_directionSortOrder(b.directionType));
  if (directionOrder != 0) {
    return directionOrder;
  }

  return a.directionIndex.compareTo(b.directionIndex);
}

int _directionSortOrder(AdjacentStationDirectionType directionType) {
  return switch (directionType) {
    AdjacentStationDirectionType.prev => 0,
    AdjacentStationDirectionType.next => 1,
  };
}

List<_AdjacentStationTrack> _attachTrainArrivalsToTracks({
  required List<_AdjacentStationTrack> tracks,
  required List<TrainArrivalModel> trainArrivals,
  required bool includeRunningArrivals,
}) {
  if (tracks.isEmpty || trainArrivals.isEmpty) {
    return tracks;
  }

  final trainsByTrackIndex = List<List<_TrainPosition>>.generate(
    tracks.length,
    (_) => <_TrainPosition>[],
  );
  final visibleTrainIds = <String>{};

  for (final arrival in trainArrivals) {
    if (!includeRunningArrivals && !_isSegmentArrival(arrival)) {
      debugPrint(
        'Train arrival skipped because comparison mode only displays '
        'segment statuses: ${arrival.toJson()}',
      );
      continue;
    }

    final trainId = _trainPositionId(arrival);
    final trackIndex = _bestTrackIndexForArrival(
      tracks: tracks,
      arrival: arrival,
    );
    if (trackIndex == null) {
      debugPrint(
        'Train arrival skipped because arvlMsg3 is outside visible tracks: '
        '${arrival.toJson()}',
      );
      continue;
    }

    final track = tracks[trackIndex];
    final stationIndex = _messageStationIndexForArrival(
      track: track,
      arrival: arrival,
    );
    if (stationIndex < 0) {
      debugPrint(
        'Train arrival skipped because arvlMsg3 did not match track stations: '
        '${arrival.toJson()}',
      );
      continue;
    }
    if (!visibleTrainIds.add(trainId)) {
      debugPrint('Duplicate train arrival skipped: ${arrival.toJson()}');
      continue;
    }

    trainsByTrackIndex[trackIndex].add(
      _TrainPosition(
        id: trainId,
        stationIndex: stationIndex,
        status: arrival.arrivalCode ?? _TrainRunStatus.running,
        destination: _trainDestinationLabel(arrival),
        number: arrival.btrainNo,
        trainType: _trainTypeLabel(arrival),
        messageStationName: arrival.arvlMsg3,
        isLastTrain: arrival.isLastTrain,
        markerColor: _trainMarkerColor(arrival),
        markerWidth: _trainMarkerWidthForArrival(arrival),
      ),
    );
  }

  return List<_AdjacentStationTrack>.generate(
    tracks.length,
    (index) => tracks[index].copyWith(trains: trainsByTrackIndex[index]),
  );
}

String? _secondPreviousStationCode(_AdjacentStationTrack track) {
  final indexOffset =
      track.directionType == AdjacentStationDirectionType.prev ? -2 : 2;
  final stationIndex = track.currentStationIndex + indexOffset;
  if (stationIndex < 0 || stationIndex >= track.stationCodeSlots.length) {
    return null;
  }

  final stationCode = track.stationCodeSlots[stationIndex].trim();
  return stationCode.isEmpty ? null : stationCode;
}

bool _isSegmentArrival(TrainArrivalModel arrival) {
  final arrivalCode = arrival.arrivalCode;
  if (arrivalCode == null) {
    return false;
  }

  return arrivalCode >= _TrainRunStatus.entering &&
      arrivalCode <= _TrainRunStatus.previousStationArrived;
}

List<TrainArrivalModel> _departedSecondPreviousArrivals({
  required List<_AdjacentStationTrack> tracks,
  required List<TrainArrivalModel> selectedStationArrivals,
  required Map<String, List<TrainArrivalModel>> trainArrivalsByBasisStationCode,
}) {
  final departedArrivals = <TrainArrivalModel>[];
  final emittedTrainIds = <String>{};

  for (final arrival in selectedStationArrivals) {
    if (arrival.arrivalCode != _TrainRunStatus.running) {
      continue;
    }

    final trainId = _trainPositionId(arrival);
    for (final track in tracks) {
      final secondPreviousStationCode = _secondPreviousStationCode(track);
      if (secondPreviousStationCode == null) {
        continue;
      }

      final messageStationIndex = _messageStationIndexForArrival(
        track: track,
        arrival: arrival,
      );
      final secondPreviousStationIndex = track.stationCodeSlots.indexOf(
        secondPreviousStationCode,
      );
      if (messageStationIndex != secondPreviousStationIndex) {
        continue;
      }

      final basisStationArrivals =
          trainArrivalsByBasisStationCode[secondPreviousStationCode] ??
          const <TrainArrivalModel>[];
      final existsInBasisStation = basisStationArrivals.any(
        (basisArrival) => _trainPositionId(basisArrival) == trainId,
      );
      if (existsInBasisStation || !emittedTrainIds.add(trainId)) {
        continue;
      }

      final departedArrival = _departedArrivalFromRunningArrival(
        arrival: arrival,
        basisStationCode: secondPreviousStationCode,
      );
      debugPrint(
        'Train arrival converted from running to departed: '
        '${departedArrival.toJson()}',
      );
      departedArrivals.add(departedArrival);
      break;
    }
  }

  return departedArrivals;
}

TrainArrivalModel _departedArrivalFromRunningArrival({
  required TrainArrivalModel arrival,
  required String basisStationCode,
}) {
  final stationName = _trainDetailValue(arrival.arvlMsg3);
  return TrainArrivalModel(
    subwayId: arrival.subwayId,
    updnLine: arrival.updnLine,
    statnFid: arrival.statnFid,
    statnTid: arrival.statnTid,
    statnId: basisStationCode,
    btrainSttus: arrival.btrainSttus,
    btrainNo: arrival.btrainNo,
    barvlDt: arrival.barvlDt,
    bstatnNm: arrival.bstatnNm,
    arvlMsg2: '$stationName 출발',
    arvlMsg3: arrival.arvlMsg3,
    arvlCd: '${_TrainRunStatus.departed}',
    lstcarAt: arrival.lstcarAt,
  );
}

int? _bestTrackIndexForArrival({
  required List<_AdjacentStationTrack> tracks,
  required TrainArrivalModel arrival,
}) {
  var bestIndex = -1;
  var bestScore = -1;

  for (var index = 0; index < tracks.length; index++) {
    final track = tracks[index];
    if (arrival.directionType != null &&
        arrival.directionType != track.directionType) {
      continue;
    }

    final messageStationIndex = _messageStationIndexForArrival(
      track: track,
      arrival: arrival,
    );
    if (messageStationIndex < 0) {
      continue;
    }

    final score = _trackMatchScore(track: track, arrival: arrival);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = index;
    }
  }

  if (bestIndex >= 0) {
    return bestIndex;
  }

  return null;
}

int _trackMatchScore({
  required _AdjacentStationTrack track,
  required TrainArrivalModel arrival,
}) {
  final candidates = [
    arrival.statnFid,
    arrival.statnTid,
    arrival.statnId,
  ].where((code) => code.isNotEmpty);

  var score = 0;
  for (final code in candidates) {
    if (track.stationCodeSlots.contains(code)) {
      score += 1;
    }
  }

  return score;
}

String _trainPositionId(TrainArrivalModel arrival) {
  final id = [
    arrival.subwayId,
    arrival.updnLine,
    arrival.btrainNo,
  ].where((value) => value.trim().isNotEmpty).join('|');

  if (id.isNotEmpty) {
    return id;
  }

  return arrival.toJson().toString();
}

int _messageStationIndexForArrival({
  required _AdjacentStationTrack track,
  required TrainArrivalModel arrival,
}) {
  final messageStationName = _normalizeStationNameForMatch(arrival.arvlMsg3);
  if (messageStationName.isEmpty) {
    return -1;
  }

  for (var index = 0; index < track.stationNames.length; index++) {
    final stationName = _normalizeStationNameForMatch(
      track.stationNames[index],
    );
    if (_stationNameMatches(stationName, messageStationName)) {
      return index;
    }
  }

  return -1;
}

String _normalizeStationNameForMatch(String name) {
  final trimmed = name.trim();
  if (trimmed.endsWith('역')) {
    return trimmed.substring(0, trimmed.length - 1);
  }

  return trimmed;
}

bool _stationNameMatches(String left, String right) {
  if (left == right) {
    return true;
  }

  return _stationNameAliases(left).contains(right) ||
      _stationNameAliases(right).contains(left);
}

Set<String> _stationNameAliases(String name) {
  final aliases = <String>{name};
  final openIndex = name.indexOf('(');
  final closeIndex = name.indexOf(')', openIndex + 1);
  if (openIndex > 0) {
    aliases.add(name.substring(0, openIndex).trim());
  }
  if (openIndex >= 0 && closeIndex > openIndex) {
    aliases.add(name.substring(openIndex + 1, closeIndex).trim());
  }

  aliases.remove('');
  return aliases;
}

String _trainDestinationLabel(TrainArrivalModel arrival) {
  final destination = arrival.bstatnNm.trim();
  final label =
      destination.isEmpty
          ? _arrivalStatusLabel(arrival.arrivalCode)
          : destination;
  if (arrival.isLastTrain) {
    return '막차·$label';
  }

  return label;
}

String _trainTypeLabel(TrainArrivalModel arrival) {
  final trainType = arrival.btrainSttus.trim();
  return trainType.isEmpty ? '일반' : trainType;
}

Color? _trainMarkerColor(TrainArrivalModel arrival) {
  final trainType = arrival.btrainSttus.trim();
  if (trainType.contains('특급')) {
    return const Color(0xFF7B2CBF);
  }

  if (trainType.contains('급행')) {
    return AppColors.no;
  }

  return null;
}

double _trainMarkerWidthForArrival(TrainArrivalModel arrival) {
  final destination = _trainDestinationLabel(arrival);
  final longestTextLength =
      destination.length > arrival.btrainNo.length
          ? destination.length
          : arrival.btrainNo.length;

  return (longestTextLength * 8.5 + 14).clamp(
    _minTrainMarkerWidth,
    _maxTrainMarkerWidth,
  );
}

String _arrivalStatusLabel(int? arrivalCode) {
  return switch (arrivalCode) {
    _TrainRunStatus.entering => '진입',
    _TrainRunStatus.arrived => '도착',
    _TrainRunStatus.departed => '출발',
    _TrainRunStatus.previousStationDeparted => '전역출발',
    _TrainRunStatus.previousStationEntering => '전역진입',
    _TrainRunStatus.previousStationArrived => '전역도착',
    _TrainRunStatus.running => '운행중',
    _ => '열차',
  };
}

List<String> _fixedStationCodeSlots({
  required List<String> stationCodes,
  required String currentStationCode,
  required int currentStationIndex,
  required bool isPrev,
}) {
  final slots = List<String>.filled(_maxVisibleRailStationCount, '');
  final limitedStationCodes = stationCodes.take(_maxVisibleRailStationCount);
  final selectedSourceIndex = stationCodes.indexOf(currentStationCode);

  if (selectedSourceIndex >= 0) {
    for (
      var sourceIndex = 0;
      sourceIndex < stationCodes.length;
      sourceIndex++
    ) {
      final slotIndex = currentStationIndex + sourceIndex - selectedSourceIndex;
      if (slotIndex < 0 || slotIndex >= slots.length) {
        continue;
      }
      slots[slotIndex] = stationCodes[sourceIndex];
    }
    return slots;
  }

  final fallbackStartIndex =
      isPrev ? slots.length - limitedStationCodes.length : 0;
  var offset = 0;
  for (final stationCode in limitedStationCodes) {
    slots[fallbackStartIndex + offset] = stationCode;
    offset += 1;
  }

  return slots;
}

int _currentStationSlotIndex({required bool isPrev}) {
  if (isPrev) {
    return _maxVisibleRailStationCount - 1;
  }

  return 0;
}

int _lineNumber(String lineName, int lineId) {
  final match = RegExp(r'\d+').firstMatch(lineName);
  if (match != null) {
    return int.parse(match.group(0)!);
  }
  return lineId;
}

String _lineLabel(String lineName, int lineId) {
  if (lineId == 10 || lineName.contains('경의중앙')) {
    return '경중';
  }

  return '${_lineNumber(lineName, lineId)}';
}

String _colorToHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class _RailStatusMessage extends StatelessWidget {
  const _RailStatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body5.copyWith(color: AppColors.gray5),
        ),
      ),
    );
  }
}

class _MetroEyeHeader extends StatelessWidget {
  const _MetroEyeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/icons/small_logo.png',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Text('MetroEye', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _FavoriteToggleButton extends StatelessWidget {
  const _FavoriteToggleButton({
    required this.isFavorite,
    required this.color,
    required this.onPressed,
  });

  final bool isFavorite;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gray2),
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            size: 23,
            color: isFavorite ? AppColors.warning : color,
          ),
        ),
      ),
    );
  }
}

class _RefreshControl extends StatelessWidget {
  const _RefreshControl({
    required this.isRefreshing,
    required this.color,
    required this.onPressed,
  });

  final bool isRefreshing;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: isRefreshing ? null : 1,
              strokeWidth: 2.5,
              backgroundColor: AppColors.gray2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          IconButton(
            onPressed: isRefreshing ? null : onPressed,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.refresh_rounded,
              size: 21,
              color: isRefreshing ? AppColors.gray4 : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineBadgeData {
  const _LineBadgeData({
    required this.label,
    required this.color,
    required this.selected,
  });

  final String label;
  final Color color;
  final bool selected;
}

class _LineBadge extends StatelessWidget {
  const _LineBadge({required this.data, required this.onTap});

  final _LineBadgeData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeWidth = data.label.length > 1 ? 36.0 : 28.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: badgeWidth,
        height: 28,
        decoration: BoxDecoration(
          color: data.selected ? data.color : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border:
              data.selected ? null : Border.all(color: data.color, width: 2),
        ),
        child: Center(
          child: Text(
            data.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            strutStyle: const StrutStyle(
              fontSize: 14,
              height: 1,
              forceStrutHeight: true,
            ),
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            style: AppTypography.body6.copyWith(
              color: data.selected ? Colors.white : data.color,
              fontSize: 14,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedTrainServicePanel extends StatelessWidget {
  const _SelectedTrainServicePanel({
    required this.train,
    required this.lineColor,
  });

  final _TrainPosition train;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final destinationText = _trainDestinationText(train);
    final locationText = _trainServiceLocationText(train);
    final statusText = _trainServiceRunStatusText(train.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: lineColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${train.number} · $destinationText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body6.copyWith(color: AppColors.gray5),
                ),
              ),
              const SizedBox(width: 8),
              _TrainInfoBadge(
                label: train.trainType,
                color: train.markerColor ?? lineColor,
              ),
              if (train.isLastTrain) ...[
                const SizedBox(width: 4),
                const _TrainInfoBadge(label: '막차', color: AppColors.gray5),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ServiceTrainInfoItem(
                  label: '현재 위치',
                  value: locationText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ServiceTrainInfoItem(label: '상태', value: statusText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceTrainInfoItem extends StatelessWidget {
  const _ServiceTrainInfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gray1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body7.copyWith(color: AppColors.gray4),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body6.copyWith(color: AppColors.gray5),
          ),
        ],
      ),
    );
  }
}

class _TrainInfoBadge extends StatelessWidget {
  const _TrainInfoBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: AppTypography.body7.copyWith(color: Colors.white, height: 1),
      ),
    );
  }
}

String _trainDetailValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _trainDestinationText(_TrainPosition train) {
  final destination = train.destination.replaceFirst('막차·', '').trim();
  if (destination.isEmpty) {
    return '종착역 정보 없음';
  }

  return '$destination행';
}

String _trainServiceLocationText(_TrainPosition train) {
  final location = train.messageStationName.trim();
  if (location.isEmpty) {
    return '-';
  }

  if (train.status == _TrainRunStatus.running) {
    return '$location 부근';
  }

  return location;
}

String _trainServiceRunStatusText(int status) {
  return switch (status) {
    _TrainRunStatus.entering || _TrainRunStatus.previousStationEntering => '진입',
    _TrainRunStatus.arrived || _TrainRunStatus.previousStationArrived => '도착',
    _TrainRunStatus.departed || _TrainRunStatus.previousStationDeparted => '출발',
    _TrainRunStatus.running => '운행중',
    _ => '열차',
  };
}

enum _RailArrowDirection { left, right }

const _maxVisibleRailStationCount = 4;
const double _minTrainMarkerWidth = 40;
const double _maxTrainMarkerWidth = 96;

abstract final class _TrainRunStatus {
  static const entering = 0;
  static const arrived = 1;
  static const departed = 2;
  static const previousStationDeparted = 3;
  static const previousStationEntering = 4;
  static const previousStationArrived = 5;
  static const running = 99;
}

class _AdjacentStationTrack {
  const _AdjacentStationTrack({
    required this.directionType,
    required this.directionIndex,
    required this.stationCodeSlots,
    required this.stationNames,
    required this.currentStationIndex,
    required this.arrowDirection,
    required this.flipTrainIcon,
    required this.trains,
  }) : assert(stationNames.length > 0),
       assert(stationNames.length <= _maxVisibleRailStationCount),
       assert(
         currentStationIndex >= 0 && currentStationIndex < stationNames.length,
       );

  final AdjacentStationDirectionType directionType;
  final int directionIndex;
  final List<String> stationCodeSlots;
  final List<String> stationNames;
  final int currentStationIndex;
  final _RailArrowDirection arrowDirection;
  final bool flipTrainIcon;
  final List<_TrainPosition> trains;

  _AdjacentStationTrack copyWith({List<_TrainPosition>? trains}) {
    return _AdjacentStationTrack(
      directionType: directionType,
      directionIndex: directionIndex,
      stationCodeSlots: stationCodeSlots,
      stationNames: stationNames,
      currentStationIndex: currentStationIndex,
      arrowDirection: arrowDirection,
      flipTrainIcon: flipTrainIcon,
      trains: trains ?? this.trains,
    );
  }
}

class _TrainPosition {
  const _TrainPosition({
    required this.id,
    required this.stationIndex,
    required this.status,
    required this.destination,
    required this.number,
    required this.trainType,
    required this.messageStationName,
    required this.isLastTrain,
    required this.markerColor,
    required this.markerWidth,
  });

  final String id;
  final int stationIndex;
  final int status;
  final String destination;
  final String number;
  final String trainType;
  final String messageStationName;
  final bool isLastTrain;
  final Color? markerColor;
  final double markerWidth;
}

class _RailDirectionView extends StatelessWidget {
  const _RailDirectionView({
    required this.track,
    required this.lineColor,
    required this.selectedTrainId,
    required this.onTrainSelected,
  });

  static const double _stationLabelWidth = 74;

  final _AdjacentStationTrack track;
  final Color lineColor;
  final String? selectedTrainId;
  final ValueChanged<_TrainPosition> onTrainSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final stationCount = track.stationNames.length;
          final railInset = _railInset(width);
          final railWidth = (width - railInset * 2).clamp(0.0, width);
          final stationGap =
              stationCount > 1 ? railWidth / (stationCount - 1) : 0.0;
          final stationX = List<double>.generate(
            stationCount,
            (index) => railInset + stationGap * index,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final train in track.trains)
                Positioned(
                  left: _trainLeft(
                    train: train,
                    width: width,
                    railInset: railInset,
                    railWidth: railWidth,
                    stationCount: stationCount,
                    direction: track.arrowDirection,
                  ),
                  top: 0,
                  child: _TrainMarker(
                    destination: train.destination,
                    number: train.number,
                    width: train.markerWidth,
                    flipIcon: track.flipTrainIcon,
                    bubbleColor: train.markerColor ?? lineColor,
                    selected: train.id == selectedTrainId,
                    onTap: () {
                      onTrainSelected(train);
                    },
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 50,
                child: _RailLine(
                  direction: track.arrowDirection,
                  color: lineColor,
                  horizontalInset: railInset,
                  stationCount: stationCount,
                ),
              ),
              for (var index = 0; index < stationCount; index++)
                Positioned(
                  left: _stationLabelLeft(
                    index: index,
                    stationX: stationX[index],
                    width: width,
                    stationCount: stationCount,
                  ),
                  top: 64,
                  width: _stationLabelWidth,
                  child: Text(
                    track.stationNames[index],
                    textAlign: _stationTextAlign(index, stationCount),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: (index == track.currentStationIndex
                            ? AppTypography.body6
                            : AppTypography.body5)
                        .copyWith(color: AppColors.gray5, height: 1.15),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static double _trainLeft({
    required _TrainPosition train,
    required double width,
    required double railInset,
    required double railWidth,
    required int stationCount,
    required _RailArrowDirection direction,
  }) {
    final positionX = _trainPositionX(
      train: train,
      railInset: railInset,
      railWidth: railWidth,
      stationCount: stationCount,
      direction: direction,
    );
    return (positionX - train.markerWidth / 2).clamp(
      -train.markerWidth / 2,
      width - train.markerWidth / 2,
    );
  }

  static double _trainPositionX({
    required _TrainPosition train,
    required double railInset,
    required double railWidth,
    required int stationCount,
    required _RailArrowDirection direction,
  }) {
    if (stationCount <= 1) {
      return railInset + railWidth / 2;
    }

    final lastStationIndex = stationCount - 1;
    final stationGap = railWidth / lastStationIndex;
    final baseIndex = train.stationIndex.clamp(0, lastStationIndex).toDouble();
    final positionedIndex =
        baseIndex + _trainStatusOffset(train.status, direction);
    final width = railWidth + railInset * 2;

    return (railInset + positionedIndex * stationGap).clamp(0.0, width);
  }

  static double _trainStatusOffset(int status, _RailArrowDirection direction) {
    final approachingSign = direction == _RailArrowDirection.right ? -1.0 : 1.0;
    return switch (status) {
      _TrainRunStatus.entering => approachingSign * 0.18,
      _TrainRunStatus.arrived => 0,
      _TrainRunStatus.departed => -approachingSign * 0.28,
      _TrainRunStatus.previousStationDeparted => -approachingSign * 0.45,
      _TrainRunStatus.previousStationEntering => approachingSign * 0.18,
      _TrainRunStatus.previousStationArrived => 0,
      _TrainRunStatus.running => 0,
      _ => 0,
    };
  }

  static double _stationLabelLeft({
    required int index,
    required double stationX,
    required double width,
    required int stationCount,
  }) {
    const labelWidth = _stationLabelWidth;
    final lastIndex = stationCount - 1;
    if (index == 0) {
      return -6;
    }
    if (index == lastIndex) {
      return width - labelWidth;
    }
    return stationX - labelWidth / 2;
  }

  static double _railInset(double width) {
    if (width <= _minTrainMarkerWidth) {
      return width / 2;
    }

    return _minTrainMarkerWidth / 2;
  }

  static TextAlign _stationTextAlign(int index, int stationCount) {
    if (index == 0) {
      return TextAlign.left;
    }
    if (index == stationCount - 1) {
      return TextAlign.right;
    }
    return TextAlign.center;
  }
}

class _RailLine extends StatelessWidget {
  const _RailLine({
    required this.direction,
    required this.color,
    required this.horizontalInset,
    required this.stationCount,
  });

  final _RailArrowDirection direction;
  final Color color;
  final double horizontalInset;
  final int stationCount;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RailLinePainter(
        direction: direction,
        color: color,
        horizontalInset: horizontalInset,
        stationCount: stationCount,
      ),
      size: const Size(double.infinity, 12),
    );
  }
}

class _RailLinePainter extends CustomPainter {
  const _RailLinePainter({
    required this.direction,
    required this.color,
    required this.horizontalInset,
    required this.stationCount,
  });

  final _RailArrowDirection direction;
  final Color color;
  final double horizontalInset;
  final int stationCount;

  @override
  void paint(Canvas canvas, Size size) {
    final railPaint =
        Paint()
          ..color = color
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = Colors.white;
    final arrowPaint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    final railStart = horizontalInset.clamp(0.0, size.width / 2);
    final railEnd = (size.width - railStart).clamp(railStart, size.width);
    final railWidth = railEnd - railStart;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), railPaint);

    final visibleStationCount = stationCount < 1 ? 1 : stationCount;
    final segmentCount = visibleStationCount - 1;
    final stationGap = segmentCount > 0 ? railWidth / segmentCount : 0.0;

    for (var index = 0; index < visibleStationCount; index++) {
      canvas.drawCircle(
        Offset(railStart + stationGap * index, y),
        4,
        pointPaint,
      );
    }

    for (var index = 0; index < segmentCount; index++) {
      final centerX = railStart + stationGap * index + stationGap / 2;
      final path = Path();
      if (direction == _RailArrowDirection.right) {
        path
          ..moveTo(centerX - 3, y - 4)
          ..lineTo(centerX + 2, y)
          ..lineTo(centerX - 3, y + 4);
      } else {
        path
          ..moveTo(centerX + 3, y - 4)
          ..lineTo(centerX - 2, y)
          ..lineTo(centerX + 3, y + 4);
      }
      canvas.drawPath(path, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RailLinePainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.color != color ||
        oldDelegate.horizontalInset != horizontalInset ||
        oldDelegate.stationCount != stationCount;
  }
}

class _TrainMarker extends StatelessWidget {
  const _TrainMarker({
    required this.destination,
    required this.number,
    required this.width,
    required this.flipIcon,
    required this.bubbleColor,
    required this.selected,
    required this.onTap,
  });

  final String destination;
  final String number;
  final double width;
  final bool flipIcon;
  final Color bubbleColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width,
              height: 30,
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(6),
                border:
                    selected ? Border.all(color: Colors.white, width: 2) : null,
                boxShadow:
                    selected
                        ? [
                          BoxShadow(
                            color: bubbleColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body7.copyWith(
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    number,
                    style: AppTypography.body7.copyWith(
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            _TrainIcon(flip: flipIcon),
          ],
        ),
      ),
    );
  }
}

class _TrainIcon extends StatelessWidget {
  const _TrainIcon({required this.flip});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/icons/train_position.png',
      width: 32,
      height: 13,
      fit: BoxFit.contain,
      matchTextDirection: flip,
    );

    if (!flip) {
      return image;
    }

    return Directionality(textDirection: TextDirection.rtl, child: image);
  }
}
