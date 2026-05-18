import 'package:flutter/material.dart';

class LineModel {
  const LineModel({
    required this.lineId,
    required this.lineName,
    required this.color,
  });

  factory LineModel.fromJson(Map<String, dynamic> json) {
    return LineModel(
      lineId: (json['lineId'] as num).toInt(),
      lineName: json['lineName'] as String,
      color: json['color'] as String,
    );
  }

  final int lineId;
  final String lineName;
  final String color;

  Map<String, dynamic> toJson() {
    return {'lineId': lineId, 'lineName': lineName, 'color': color};
  }

  Color get colorValue {
    final normalized = color.replaceAll('#', '').trim();
    final buffer = StringBuffer();
    if (normalized.length == 6) {
      buffer.write('FF');
    }
    buffer.write(normalized);
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
