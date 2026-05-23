import 'package:flutter/material.dart';

class RealtimeTrainPositionScreen extends StatelessWidget {
  const RealtimeTrainPositionScreen({
    super.key,
    required this.stationName,
    required this.stationCode,
    required this.lineId,
    required this.lineName,
  });

  final String stationName;
  final String stationCode;
  final int lineId;
  final String lineName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('실시간 열차 위치')),
      body: const SafeArea(child: SizedBox.shrink()),
    );
  }
}
