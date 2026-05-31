class StationModel {
  const StationModel({
    required this.stationId,
    required this.stationName,
    required this.stationCode,
    required this.lineId,
  });

  factory StationModel.fromJson(Map<String, dynamic> json) {
    return StationModel(
      stationId: (json['stationId'] as num).toInt(),
      stationName: json['stationName'] as String,
      stationCode: json['stationCode'] as String,
      lineId: (json['lineId'] as num).toInt(),
    );
  }

  final int stationId;
  final String stationName;
  final String stationCode;
  final int lineId;

  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,
      'stationName': stationName,
      'stationCode': stationCode,
      'lineId': lineId,
    };
  }
}
