import 'package:flutter/material.dart';
import 'package:metroeye_flutter/core/device/device_session_service.dart';
import 'package:metroeye_flutter/core/line/line_model.dart';
import 'package:metroeye_flutter/core/line/line_service.dart';
import 'package:metroeye_flutter/core/station/station_model.dart';
import 'package:metroeye_flutter/core/station/station_service.dart';
import 'package:metroeye_flutter/ui/realtime_train_position/realtime_train_position_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class StationHit {
  const StationHit({
    required this.line,
    required this.station,
    required this.stationCode,
    required this.lineId,
    required this.matchPriority,
  });

  final String line;
  final String station;
  final String stationCode;
  final int lineId;
  final int matchPriority;
}

class HomeScreenData {
  const HomeScreenData({required this.lines, required this.stations});

  final List<LineModel> lines;
  final List<StationModel> stations;
}

List<StationHit> filterStationHits({
  required List<StationModel> stations,
  required List<LineModel> lines,
  required String selectedLine,
  required String query,
  required String allLines,
}) {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return const [];
  }

  final normalizedQuery = trimmedQuery.toLowerCase();
  final hits = <StationHit>[];
  final selectedLineId =
      selectedLine == allLines ? null : _lineIdForName(selectedLine, lines);
  if (selectedLine != allLines && selectedLineId == null) {
    return const [];
  }

  for (final station in stations) {
    if (selectedLineId != null && station.lineId != selectedLineId) {
      continue;
    }

    final normalizedName = station.stationName.toLowerCase();
    if (!normalizedName.contains(normalizedQuery)) {
      continue;
    }

    final matchPriority =
        normalizedName == normalizedQuery
            ? 0
            : normalizedName.startsWith(normalizedQuery)
            ? 1
            : 2;

    hits.add(
      StationHit(
        line: _lineNameForId(station.lineId, lines),
        station: station.stationName,
        stationCode: station.stationCode,
        lineId: station.lineId,
        matchPriority: matchPriority,
      ),
    );
  }

  hits.sort((a, b) {
    final byMatchPriority = a.matchPriority.compareTo(b.matchPriority);
    if (byMatchPriority != 0) {
      return byMatchPriority;
    }

    final byStationLength = a.station.length.compareTo(b.station.length);
    if (byStationLength != 0) {
      return byStationLength;
    }

    final byStation = a.station.compareTo(b.station);
    if (byStation != 0) {
      return byStation;
    }

    final byLineOrder = a.lineId.compareTo(b.lineId);
    if (byLineOrder != 0) {
      return byLineOrder;
    }

    return a.stationCode.compareTo(b.stationCode);
  });

  return hits;
}

int? _lineIdForName(String lineName, List<LineModel> lines) {
  for (final line in lines) {
    if (line.lineName == lineName) {
      return line.lineId;
    }
  }

  return null;
}

String _lineNameForId(int lineId, List<LineModel> lines) {
  for (final line in lines) {
    if (line.lineId == lineId) {
      return line.lineName;
    }
  }

  return '';
}

class _HomeScreenState extends State<HomeScreen> {
  static const String allLines = '전체 노선';

  final TextEditingController _searchController = TextEditingController();
  final DeviceSessionService _deviceSessionService = DeviceSessionService();
  final LineService _lineService = LineService();
  final StationService _stationService = StationService();

  late Future<HomeScreenData> _homeFuture;
  String selectedLine = allLines;
  String stationQuery = '';

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHomeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<HomeScreenData> _loadHomeData() async {
    await _deviceSessionService.loadOrCreateSession();
    final results = await Future.wait([
      _lineService.loadForHome(),
      _stationService.loadForHome(),
    ]);

    return HomeScreenData(
      lines: results[0] as List<LineModel>,
      stations: results[1] as List<StationModel>,
    );
  }

  void _retry() {
    setState(() {
      _homeFuture = _loadHomeData();
    });
  }

  List<StationHit> _filteredHits({
    required List<StationModel> stations,
    required List<LineModel> lines,
  }) {
    return filterStationHits(
      stations: stations,
      lines: lines,
      selectedLine: selectedLine,
      query: stationQuery,
      allLines: allLines,
    );
  }

  Color _iconColorForLine(String lineName, List<LineModel> lines) {
    if (lineName == allLines) {
      return const Color(0xFF49729B);
    }

    for (final line in lines) {
      if (line.lineName == lineName) {
        return line.colorValue;
      }
    }

    return const Color(0xFF49729B);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeScreenData>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          debugPrint('Home bootstrap error: ${snapshot.error}');
          debugPrint('Home bootstrap stack: ${snapshot.stackTrace}');
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Home bootstrap failed.',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '실패 콘솔 로그 확인',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final apiLines = data.lines;
        final stations = data.stations;
        final dropdownLines = [
          allLines,
          ...apiLines.map((line) => line.lineName),
        ];

        if (!dropdownLines.contains(selectedLine)) {
          selectedLine = allLines;
        }

        final hits = _filteredHits(stations: stations, lines: apiLines);

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/small_logo.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'MetroEye',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLine,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items:
                      dropdownLines
                          .map(
                            (line) => DropdownMenuItem(
                              value: line,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.train,
                                    color: _iconColorForLine(line, apiLines),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(line),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      selectedLine = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '역을 검색하세요',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        stationQuery.isEmpty
                            ? null
                            : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  stationQuery = '';
                                });
                              },
                              icon: const Icon(Icons.clear),
                              tooltip: 'Clear',
                            ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      stationQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (stationQuery.trim().isEmpty)
                  const SizedBox.shrink()
                else if (hits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('검색 결과가 없습니다'),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: hits.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final hit = hits[index];
                      return ListTile(
                        leading: Icon(
                          Icons.train,
                          color: _iconColorForLine(hit.line, apiLines),
                        ),
                        title: Text(hit.station),
                        subtitle:
                            selectedLine == allLines ? Text(hit.line) : null,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => RealtimeTrainPositionScreen(
                                    stationName: hit.station,
                                    stationCode: hit.stationCode,
                                    lineId: hit.lineId,
                                    lineName: hit.line,
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
