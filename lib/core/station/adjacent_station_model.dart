import 'package:metroeye_flutter/core/network/api_exception.dart';
import 'package:metroeye_flutter/core/network/api_response.dart';

enum AdjacentStationDirectionType {
  prev,
  next;

  factory AdjacentStationDirectionType.fromJson(Object? value) {
    final normalized = (value as String?)?.trim().toUpperCase();
    return switch (normalized) {
      'PREV' => AdjacentStationDirectionType.prev,
      'NEXT' => AdjacentStationDirectionType.next,
      _ => throw ApiException('Unknown adjacent station direction: $value'),
    };
  }
}

class AdjacentStationModel {
  const AdjacentStationModel({
    required this.directionType,
    required this.directionIndex,
    required this.stationCodes,
  });

  factory AdjacentStationModel.fromJson(Map<String, dynamic> json) {
    return AdjacentStationModel(
      directionType: AdjacentStationDirectionType.fromJson(
        json['directionType'],
      ),
      directionIndex: (json['directionIndex'] as num).toInt(),
      stationCodes: asList(
        json['stationCodes'],
      ).map((item) => item as String).toList(growable: false),
    );
  }

  final AdjacentStationDirectionType directionType;
  final int directionIndex;
  final List<String> stationCodes;

  Map<String, dynamic> toJson() {
    return {
      'directionType': directionType.name.toUpperCase(),
      'directionIndex': directionIndex,
      'stationCodes': stationCodes,
    };
  }
}
