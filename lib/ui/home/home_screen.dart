import 'package:flutter/material.dart';
import 'package:metroeye_flutter/core/device/device_session.dart';
import 'package:metroeye_flutter/core/device/device_session_service.dart';
import 'package:metroeye_flutter/core/line/line_model.dart';
import 'package:metroeye_flutter/core/line/line_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class StationHit {
  const StationHit({
    required this.line,
    required this.station,
  });

  final String line;
  final String station;
}

class HomeScreenData {
  const HomeScreenData({
    required this.session,
    required this.lines,
  });

  final DeviceSession session;
  final List<LineModel> lines;
}

class _HomeScreenState extends State<HomeScreen> {
  static const String allLines = '전체 노선';

  static const Map<String, List<String>> stationsByLine = {
    '1호선': ['서울역', '시청', '종각', '종로3가'],
    '2호선': ['시청', '강남', '홍대입구', '신도림'],
    '3호선': ['대화', '경복궁', '종로3가'],
    '4호선': ['명동', '서울역', '사당'],
    '5호선': ['여의도', '광화문', '왕십리'],
    '6호선': ['이태원', '합정'],
    '7호선': ['건대입구', '고속터미널'],
    '8호선': ['잠실', '모란'],
    '9호선': ['여의도', '고속터미널'],
  };

  final TextEditingController _searchController = TextEditingController();
  final DeviceSessionService _deviceSessionService = DeviceSessionService();
  final LineService _lineService = LineService();

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
    final session = await _deviceSessionService.loadOrCreateSession();
    final lines = await _lineService.loadForHome(
      accessToken: session.accessToken,
    );

    return HomeScreenData(
      session: session,
      lines: lines,
    );
  }

  void _retry() {
    setState(() {
      _homeFuture = _loadHomeData();
    });
  }

  List<StationHit> _filteredHits(List<LineModel> lines) {
    final q = stationQuery.trim();
    if (q.isEmpty) {
      return const [];
    }

    final hits = <StationHit>[];

    if (selectedLine == allLines) {
      for (final line in lines) {
        final stations = stationsByLine[line.name] ?? const [];
        for (final station in stations) {
          if (station.contains(q)) {
            hits.add(StationHit(line: line.name, station: station));
          }
        }
      }
    } else {
      final stations = stationsByLine[selectedLine] ?? const [];
      for (final station in stations) {
        if (station.contains(q)) {
          hits.add(StationHit(line: selectedLine, station: station));
        }
      }
    }

    hits.sort((a, b) {
      final byStation = a.station.compareTo(b.station);
      return byStation != 0 ? byStation : a.line.compareTo(b.line);
    });

    return hits;
  }

  Color _iconColorForLine(String lineName, List<LineModel> lines) {
    if (lineName == allLines) {
      return const Color(0xFF49729B);
    }

    for (final line in lines) {
      if (line.name == lineName) {
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
            body: SafeArea(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
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
                        '자세한 실패 원인은 콘솔 로그를 확인하세요.',
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
        final dropdownLines = [
          allLines,
          ...apiLines.map((line) => line.name),
        ];

        if (!dropdownLines.contains(selectedLine)) {
          selectedLine = allLines;
        }

        final hits = _filteredHits(apiLines);

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
                  items: dropdownLines
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
                    suffixIcon: stationQuery.isEmpty
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
                        subtitle: selectedLine == allLines ? Text(hit.line) : null,
                        onTap: () {
                          // TODO: 다음작업 화면이동
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
