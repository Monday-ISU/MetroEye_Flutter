import 'package:flutter/material.dart';
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
  const RealtimeTrainPositionScreen({
    super.key,
    required this.stationName,
    required this.stationId,
    required this.stationCode,
    required this.lineId,
    required this.connectedLines,
  }) : assert(connectedLines.length > 0);

  final String stationName;
  final int stationId;
  final String stationCode;
  final int lineId;
  final List<RealtimeTrainPositionLine> connectedLines;

  @override
  State<RealtimeTrainPositionScreen> createState() {
    return _RealtimeTrainPositionScreenState();
  }
}

class _RealtimeTrainPositionScreenState
    extends State<RealtimeTrainPositionScreen> {
  late RealtimeTrainPositionLine _selectedLine;

  @override
  void initState() {
    super.initState();
    _selectedLine = _resolveSelectedLine();
  }

  @override
  void didUpdateWidget(covariant RealtimeTrainPositionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lineId != widget.lineId ||
        oldWidget.connectedLines != widget.connectedLines) {
      _selectedLine = _resolveSelectedLine();
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedStationName = _displayStationName(widget.stationName);
    final lineColor = _selectedLine.color;
    final tracks = _dummyAdjacentStationTracks(normalizedStationName);

    return Scaffold(
      backgroundColor: AppColors.gray1,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _MetroEyeHeader(),
            const SizedBox(height: 12),
            Text(
              '$normalizedStationName역',
              style: AppTypography.body4.copyWith(color: Colors.black),
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
                      setState(() {
                        _selectedLine = line;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '실시간 위치',
              style: AppTypography.body4.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 17),
            for (var index = 0; index < tracks.length; index++) ...[
              if (index > 0) const SizedBox(height: 20),
              _RailDirectionView(track: tracks[index], lineColor: lineColor),
            ],
          ],
        ),
      ),
    );
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
    final trimmed = name.trim();
    if (trimmed.endsWith('역')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
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

List<_AdjacentStationTrack> _dummyAdjacentStationTracks(
  String currentStationName,
) {
  return [
    _AdjacentStationTrack(
      stationNames: ['', '', '종점', currentStationName],
      currentStationIndex: 3,
      arrowDirection: _RailArrowDirection.right,
      flipTrainIcon: true,
      trains: const [
        _TrainPosition(
          stationIndex: 2,
          status: _TrainRunStatus.departed,
          destination: '출발',
          number: '4134',
        ),
      ],
    ),
    _AdjacentStationTrack(
      stationNames: ['선바위', '남태령', '사당', currentStationName],
      currentStationIndex: 3,
      arrowDirection: _RailArrowDirection.right,
      flipTrainIcon: true,
      trains: const [
        _TrainPosition(
          stationIndex: 0,
          status: _TrainRunStatus.departed,
          destination: '출발',
          number: '4130',
        ),
        _TrainPosition(
          stationIndex: 1,
          status: _TrainRunStatus.arrived,
          destination: '도착',
          number: '4131',
        ),
        _TrainPosition(
          stationIndex: 2,
          status: _TrainRunStatus.entering,
          destination: '진입',
          number: '4132',
        ),
        _TrainPosition(
          stationIndex: 3,
          status: _TrainRunStatus.previousStationDeparted,
          destination: '전역출발',
          number: '4133',
        ),
      ],
    ),
    _AdjacentStationTrack(
      stationNames: [currentStationName, '동작', '이촌', '신용산'],
      currentStationIndex: 0,
      arrowDirection: _RailArrowDirection.left,
      flipTrainIcon: false,
      trains: const [
        _TrainPosition(
          stationIndex: 0,
          status: _TrainRunStatus.arrived,
          destination: '오이도행',
          number: '4132',
        ),
        _TrainPosition(
          stationIndex: 1,
          status: _TrainRunStatus.departed,
          destination: '오이도행',
          number: '4133',
        ),
      ],
    ),
  ];
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

enum _RailArrowDirection { left, right }

const _maxVisibleRailStationCount = 4;

abstract final class _TrainRunStatus {
  static const entering = 0;
  static const arrived = 1;
  static const departed = 2;
  static const previousStationDeparted = 3;
}

class _AdjacentStationTrack {
  const _AdjacentStationTrack({
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

  final List<String> stationNames;
  final int currentStationIndex;
  final _RailArrowDirection arrowDirection;
  final bool flipTrainIcon;
  final List<_TrainPosition> trains;
}

class _TrainPosition {
  const _TrainPosition({
    required this.stationIndex,
    required this.status,
    required this.destination,
    required this.number,
  });

  final int stationIndex;
  final int status;
  final String destination;
  final String number;
}

class _RailDirectionView extends StatelessWidget {
  const _RailDirectionView({required this.track, required this.lineColor});

  static const double _stationLabelWidth = 74;

  final _AdjacentStationTrack track;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final stationCount = track.stationNames.length;
          final stationGap =
              stationCount > 1 ? width / (stationCount - 1) : 0.0;
          final stationX = List<double>.generate(
            stationCount,
            (index) => stationGap * index,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final train in track.trains)
                Positioned(
                  left: _trainLeft(
                    train: train,
                    width: width,
                    stationCount: stationCount,
                  ),
                  top: 0,
                  child: _TrainMarker(
                    destination: train.destination,
                    number: train.number,
                    flipIcon: track.flipTrainIcon,
                    bubbleColor: lineColor,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 50,
                child: _RailLine(
                  direction: track.arrowDirection,
                  color: lineColor,
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
    required int stationCount,
  }) {
    const trainWidth = 40.0;
    final positionX = _trainPositionX(
      train: train,
      width: width,
      stationCount: stationCount,
    );
    return (positionX - trainWidth / 2).clamp(0.0, width - trainWidth);
  }

  static double _trainPositionX({
    required _TrainPosition train,
    required double width,
    required int stationCount,
  }) {
    if (stationCount <= 1) {
      return width / 2;
    }

    final lastStationIndex = stationCount - 1;
    final stationGap = width / lastStationIndex;
    final baseIndex = train.stationIndex.clamp(0, lastStationIndex).toDouble();
    final positionedIndex = switch (train.status) {
      _TrainRunStatus.entering => baseIndex - 0.18,
      _TrainRunStatus.arrived => baseIndex,
      _TrainRunStatus.departed => baseIndex + 0.18,
      _TrainRunStatus.previousStationDeparted => baseIndex - 0.55,
      _ => baseIndex,
    };

    return positionedIndex.clamp(0.0, lastStationIndex.toDouble()) * stationGap;
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
    required this.stationCount,
  });

  final _RailArrowDirection direction;
  final Color color;
  final int stationCount;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RailLinePainter(
        direction: direction,
        color: color,
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
    required this.stationCount,
  });

  final _RailArrowDirection direction;
  final Color color;
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
    canvas.drawLine(Offset(0, y), Offset(size.width, y), railPaint);

    final visibleStationCount = stationCount < 1 ? 1 : stationCount;
    final segmentCount = visibleStationCount - 1;
    final stationGap = segmentCount > 0 ? size.width / segmentCount : 0.0;

    for (var index = 0; index < visibleStationCount; index++) {
      canvas.drawCircle(Offset(stationGap * index, y), 4, pointPaint);
    }

    for (var index = 0; index < segmentCount; index++) {
      final centerX = stationGap * index + stationGap / 2;
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
        oldDelegate.stationCount != stationCount;
  }
}

class _TrainMarker extends StatelessWidget {
  const _TrainMarker({
    required this.destination,
    required this.number,
    required this.flipIcon,
    required this.bubbleColor,
  });

  final String destination;
  final String number;
  final bool flipIcon;
  final Color bubbleColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 30,
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(6),
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
