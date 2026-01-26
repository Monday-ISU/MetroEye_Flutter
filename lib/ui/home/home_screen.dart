import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class StationHit {
  final String line;
  final String station;
  const StationHit({required this.line, required this.station});
}

class _HomeScreenState extends State<HomeScreen> {
  static const String allLines = '전체노선';

  static const List<String> lines = [
    allLines,
    '1호선',
    '2호선',
    '3호선',
    '4호선',
    '5호선',
    '6호선',
    '7호선',
    '8호선',
    '9호선',
  ];

  static const Map<String, List<String>> stationsByLine = {
    '1호선': ['서울역', '시청', '종각', '종로3가'],
    '2호선': ['시청', '강남', '잠실', '홍대입구'],
    '3호선': ['대화', '경복궁', '종로3가'],
    '4호선': ['혜화', '서울역', '사당'],
    '5호선': ['여의도', '광화문', '왕십리'],
    '6호선': ['합정', '이태원'],
    '7호선': ['건대입구', '고속터미널'],
    '8호선': ['잠실', '모란'],
    '9호선': ['여의도', '고속터미널'],
  };

  static const Map<String, Color> lineColors = {
    '1호선': Color(0xFF0033A0),
    '2호선': Color(0xFF00B140),
    '3호선': Color(0xFFFC4C02),
    '4호선': Color(0xFF30E6FF),
    '5호선': Color(0xFFA05EB5),
    '6호선': Color(0xFFC75D28),
    '7호선': Color(0xFF6D712E),
    '8호선': Color(0xFFE31C79),
    '9호선': Color(0xFFACAA88),
  };

  String selectedLine = allLines;
  String query = '';

  Color iconColorForLine(String line) {
    if (line == allLines) return const Color(0xFF49729B);
    return lineColors[line] ?? const Color(0xFF49729B);
  }

  List<StationHit> filteredHits() {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final hits = <StationHit>[];

    if (selectedLine == allLines) {
      stationsByLine.forEach((line, stations) {
        for (final s in stations) {
          if (s.contains(q)) hits.add(StationHit(line: line, station: s));
        }
      });
    } else {
      final stations = stationsByLine[selectedLine] ?? const [];
      for (final s in stations) {
        if (s.contains(q)) hits.add(StationHit(line: selectedLine, station: s));
      }
    }

    hits.sort((a, b) {
      final byStation = a.station.compareTo(b.station);
      return byStation != 0 ? byStation : a.line.compareTo(b.line);
    });

    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final hits = filteredHits();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'MetroEye',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // ✅ Dropdown도 "입력 폼"처럼 보이게: Flutter UI 일관성
            DropdownButtonFormField<String>(
              value: selectedLine,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: lines
                  .map(
                    (line) => DropdownMenuItem(
                  value: line,
                  child: Row(
                    children: [
                      Icon(Icons.train, color: iconColorForLine(line)),
                      const SizedBox(width: 8),
                      Text(line),
                    ],
                  ),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedLine = value);
              },
            ),

            const SizedBox(height: 12),

            TextField(
              decoration: InputDecoration(
                hintText: '역을 검색하세요',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                  onPressed: () => setState(() => query = ''),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear',
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => query = value),
            ),

            const SizedBox(height: 12),

            if (query.trim().isEmpty)
              const SizedBox.shrink()
            else if (hits.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('검색 결과가 없습니다'),
              )
            else
            // ✅ Column+Expanded 대신 ListView 하나로 구성 → overflow/레이아웃 문제 줄어듦
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: hits.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final hit = hits[index];
                  return ListTile(
                    leading: Icon(Icons.train, color: iconColorForLine(hit.line)),
                    title: Text(hit.station),
                    subtitle: selectedLine == allLines ? Text(hit.line) : null,
                    onTap: () {
                      // TODO: 다음 브랜치에서 ArrivalsScreen 네비게이션 연결
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
