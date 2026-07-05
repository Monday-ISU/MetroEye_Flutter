import 'package:flutter/material.dart';
import 'package:metroeye_flutter/core/device/device_session_service.dart';
import 'package:metroeye_flutter/core/line/line_model.dart';
import 'package:metroeye_flutter/core/line/line_service.dart';
import 'package:metroeye_flutter/core/station/station_search_storage.dart';
import 'package:metroeye_flutter/core/station/station_model.dart';
import 'package:metroeye_flutter/core/station/station_service.dart';
import 'package:metroeye_flutter/core/theme/app_colors.dart';
import 'package:metroeye_flutter/core/theme/app_typography.dart';
import 'package:metroeye_flutter/ui/realtime_train_position/realtime_train_position_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, StationSearchStorage? stationSearchStorage})
    : _stationSearchStorage = stationSearchStorage;

  final StationSearchStorage? _stationSearchStorage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class StationHit {
  const StationHit({
    required this.line,
    required this.station,
    required this.stationId,
    required this.stationCode,
    required this.lineId,
    required this.matchPriority,
  });

  final String line;
  final String station;
  final int stationId;
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
        stationId: station.stationId,
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

List<RealtimeTrainPositionLine> connectedLinesForStation({
  required StationHit hit,
  required List<StationModel> stations,
  required List<LineModel> lines,
}) {
  final linesById = {for (final line in lines) line.lineId: line};
  final seenLineIds = <int>{};
  final connectedLines = <RealtimeTrainPositionLine>[];

  for (final station in stations) {
    if (station.stationName != hit.station ||
        !seenLineIds.add(station.lineId)) {
      continue;
    }

    final line = linesById[station.lineId];
    if (line == null) {
      continue;
    }

    connectedLines.add(
      RealtimeTrainPositionLine(
        lineId: line.lineId,
        lineName: line.lineName,
        color: line.colorValue,
      ),
    );
  }

  if (!seenLineIds.contains(hit.lineId)) {
    final selectedLine = linesById[hit.lineId];
    if (selectedLine != null) {
      connectedLines.add(
        RealtimeTrainPositionLine(
          lineId: selectedLine.lineId,
          lineName: selectedLine.lineName,
          color: selectedLine.colorValue,
        ),
      );
    }
  }

  connectedLines.sort((a, b) => a.lineId.compareTo(b.lineId));
  return connectedLines;
}

class _HomeScreenState extends State<HomeScreen> {
  static const String allLines = '전체 노선';

  final TextEditingController _searchController = TextEditingController();
  final DeviceSessionService _deviceSessionService = DeviceSessionService();
  final LineService _lineService = LineService();
  final StationService _stationService = StationService();
  late final StationSearchStorage _stationSearchStorage;

  late Future<HomeScreenData> _homeFuture;
  StationSearchHistory _searchHistory = StationSearchHistory.empty();
  _QuickAccessTab _selectedQuickAccessTab = _QuickAccessTab.favorites;
  String selectedLine = allLines;
  String stationQuery = '';

  @override
  void initState() {
    super.initState();
    _stationSearchStorage =
        widget._stationSearchStorage ?? SharedPreferencesStationSearchStorage();
    _homeFuture = _loadHomeData();
    _loadSearchHistory();
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

  Future<void> _loadSearchHistory() async {
    try {
      final history = await _stationSearchStorage.readHistory();
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

  StationSearchRecord _searchRecordForHit({
    required StationHit hit,
    required List<LineModel> lines,
  }) {
    final lineColor = _lineColorForId(hit.lineId, lines);
    return StationSearchRecord(
      stationId: hit.stationId,
      stationCode: hit.stationCode,
      stationName: hit.station,
      lineId: hit.lineId,
      lineName: hit.line,
      lineColor: lineColor,
      updatedAt: DateTime.now(),
    );
  }

  StationHit _hitForRecord({
    required StationSearchRecord record,
    required List<StationModel> stations,
    required List<LineModel> lines,
  }) {
    for (final station in stations) {
      if (station.lineId == record.lineId &&
          station.stationCode == record.stationCode) {
        return StationHit(
          line:
              _lineNameForId(station.lineId, lines).isEmpty
                  ? record.lineName
                  : _lineNameForId(station.lineId, lines),
          station: station.stationName,
          stationId: station.stationId,
          stationCode: station.stationCode,
          lineId: station.lineId,
          matchPriority: 0,
        );
      }
    }

    return StationHit(
      line: record.lineName,
      station: record.stationName,
      stationId: record.stationId,
      stationCode: record.stationCode,
      lineId: record.lineId,
      matchPriority: 0,
    );
  }

  List<StationSearchRecord> _visibleSearchRecords({
    required List<StationSearchRecord> records,
    required List<LineModel> lines,
  }) {
    if (selectedLine == allLines) {
      return records;
    }

    final lineId = _lineIdForName(selectedLine, lines);
    if (lineId == null) {
      return const <StationSearchRecord>[];
    }

    return records.where((record) => record.lineId == lineId).toList();
  }

  Future<void> _toggleFavoriteHit({
    required StationHit hit,
    required List<LineModel> lines,
  }) async {
    final history = await _stationSearchStorage.toggleFavorite(
      _searchRecordForHit(hit: hit, lines: lines),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _toggleFavoriteRecord(StationSearchRecord record) async {
    final history = await _stationSearchStorage.toggleFavorite(record);
    if (!mounted) {
      return;
    }

    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _openStation({
    required StationHit hit,
    required List<StationModel> stations,
    required List<LineModel> lines,
  }) async {
    final history = await _stationSearchStorage.addRecent(
      _searchRecordForHit(hit: hit, lines: lines),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _searchHistory = history;
    });

    final connectedLines = connectedLinesForStation(
      hit: hit,
      stations: stations,
      lines: lines,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => RealtimeTrainPositionScreen(
              stationName: hit.station,
              stationId: hit.stationId,
              stationCode: hit.stationCode,
              lineId: hit.lineId,
              connectedLines: connectedLines,
              stationSearchStorage: _stationSearchStorage,
            ),
      ),
    );
    await _loadSearchHistory();
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
        final favorites = _visibleSearchRecords(
          records: _searchHistory.favorites,
          lines: apiLines,
        );
        final recents = _visibleSearchRecords(
          records: _searchHistory.recents,
          lines: apiLines,
        );

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
                  _SearchQuickAccessView(
                    selectedTab: _selectedQuickAccessTab,
                    favorites: favorites,
                    recents: recents,
                    isFavorite: _searchHistory.isFavorite,
                    onTabChanged: (tab) {
                      setState(() {
                        _selectedQuickAccessTab = tab;
                      });
                    },
                    onRecordTap: (record) {
                      final hit = _hitForRecord(
                        record: record,
                        stations: stations,
                        lines: apiLines,
                      );
                      _openStation(
                        hit: hit,
                        stations: stations,
                        lines: apiLines,
                      );
                    },
                    onFavoriteTap: _toggleFavoriteRecord,
                  )
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
                      final record = _searchRecordForHit(
                        hit: hit,
                        lines: apiLines,
                      );
                      final isFavorite = _searchHistory.isFavorite(record);
                      return _StationSearchResultTile(
                        stationName: hit.station,
                        lineName: hit.line,
                        lineColor: _iconColorForLine(hit.line, apiLines),
                        showLineName: selectedLine == allLines,
                        isFavorite: isFavorite,
                        onTap: () {
                          _openStation(
                            hit: hit,
                            stations: stations,
                            lines: apiLines,
                          );
                        },
                        onFavoriteTap: () {
                          _toggleFavoriteHit(hit: hit, lines: apiLines);
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

enum _QuickAccessTab { favorites, recents }

class _SearchQuickAccessView extends StatelessWidget {
  const _SearchQuickAccessView({
    required this.selectedTab,
    required this.favorites,
    required this.recents,
    required this.isFavorite,
    required this.onTabChanged,
    required this.onRecordTap,
    required this.onFavoriteTap,
  });

  final _QuickAccessTab selectedTab;
  final List<StationSearchRecord> favorites;
  final List<StationSearchRecord> recents;
  final bool Function(StationSearchRecord record) isFavorite;
  final ValueChanged<_QuickAccessTab> onTabChanged;
  final ValueChanged<StationSearchRecord> onRecordTap;
  final ValueChanged<StationSearchRecord> onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final records =
        selectedTab == _QuickAccessTab.favorites ? favorites : recents;
    final emptyText =
        selectedTab == _QuickAccessTab.favorites
            ? '즐겨찾기한 역이 없습니다'
            : '최근 검색역이 없습니다';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuickAccessSegmentedTab(
          selectedTab: selectedTab,
          onChanged: onTabChanged,
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              emptyText,
              style: AppTypography.body5.copyWith(color: AppColors.gray4),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: records.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = records[index];
              return _StationRecordTile(
                record: record,
                isFavorite: isFavorite(record),
                onTap: () {
                  onRecordTap(record);
                },
                onFavoriteTap: () {
                  onFavoriteTap(record);
                },
              );
            },
          ),
      ],
    );
  }
}

class _QuickAccessSegmentedTab extends StatelessWidget {
  const _QuickAccessSegmentedTab({
    required this.selectedTab,
    required this.onChanged,
  });

  final _QuickAccessTab selectedTab;
  final ValueChanged<_QuickAccessTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.subGray1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickAccessTabButton(
              label: '즐겨찾기',
              selected: selectedTab == _QuickAccessTab.favorites,
              onTap: () {
                onChanged(_QuickAccessTab.favorites);
              },
            ),
          ),
          Expanded(
            child: _QuickAccessTabButton(
              label: '최근 검색',
              selected: selectedTab == _QuickAccessTab.recents,
              onTap: () {
                onChanged(_QuickAccessTab.recents);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessTabButton extends StatelessWidget {
  const _QuickAccessTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: AppTypography.body6.copyWith(
            color: selected ? AppColors.gray5 : AppColors.gray4,
          ),
        ),
      ),
    );
  }
}

class _StationSearchResultTile extends StatelessWidget {
  const _StationSearchResultTile({
    required this.stationName,
    required this.lineName,
    required this.lineColor,
    required this.showLineName,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final String stationName;
  final String lineName;
  final Color lineColor;
  final bool showLineName;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: _LineBadge(label: _lineBadgeLabel(lineName), color: lineColor),
      title: Text(stationName, style: AppTypography.body3),
      subtitle:
          showLineName
              ? Text(
                lineName,
                style: AppTypography.body5.copyWith(color: AppColors.gray4),
              )
              : null,
      trailing: IconButton(
        onPressed: onFavoriteTap,
        icon: Icon(isFavorite ? Icons.star_rounded : Icons.star_border_rounded),
        color: isFavorite ? AppColors.warning : AppColors.gray4,
      ),
      onTap: onTap,
    );
  }
}

class _StationRecordTile extends StatelessWidget {
  const _StationRecordTile({
    required this.record,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final StationSearchRecord record;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return _StationSearchResultTile(
      stationName: record.stationName,
      lineName: record.lineName,
      lineColor: _colorFromHex(record.lineColor),
      showLineName: true,
      isFavorite: isFavorite,
      onTap: onTap,
      onFavoriteTap: onFavoriteTap,
    );
  }
}

class _LineBadge extends StatelessWidget {
  const _LineBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final width = label.length > 1 ? 36.0 : 28.0;

    return Container(
      width: width,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: AppTypography.body6.copyWith(color: Colors.white, height: 1),
      ),
    );
  }
}

String _lineColorForId(int lineId, List<LineModel> lines) {
  for (final line in lines) {
    if (line.lineId == lineId) {
      return line.color;
    }
  }

  return '#49729B';
}

String _lineBadgeLabel(String lineName) {
  if (lineName.contains('경의중앙')) {
    return '경중';
  }

  final match = RegExp(r'\d+').firstMatch(lineName);
  if (match != null) {
    return match.group(0)!;
  }

  return lineName.length > 2 ? lineName.substring(0, 2) : lineName;
}

Color _colorFromHex(String hex) {
  final normalized = hex.replaceAll('#', '').trim();
  final buffer = StringBuffer();
  if (normalized.length == 6) {
    buffer.write('FF');
  }
  buffer.write(normalized);

  return Color(int.tryParse(buffer.toString(), radix: 16) ?? 0xFF49729B);
}
