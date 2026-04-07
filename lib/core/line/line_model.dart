import 'package:flutter/material.dart';

class LineModel {
  const LineModel({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
  });

  factory LineModel.fromJson(Map<String, dynamic> json) {
    return LineModel(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      code: json['code'] as String,
      color: json['color'] as String,
    );
  }

  final int? id;
  final String name;
  final String code;
  final String color;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'color': color,
    };
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
