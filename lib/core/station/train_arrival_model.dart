import 'package:metroeye_flutter/core/station/adjacent_station_model.dart';

class TrainArrivalModel {
  const TrainArrivalModel({
    required this.subwayId,
    required this.updnLine,
    required this.statnFid,
    required this.statnTid,
    required this.statnId,
    required this.btrainSttus,
    required this.btrainNo,
    required this.barvlDt,
    required this.bstatnNm,
    required this.arvlMsg2,
    required this.arvlMsg3,
    required this.arvlCd,
    required this.lstcarAt,
  });

  factory TrainArrivalModel.fromJson(Map<String, dynamic> json) {
    return TrainArrivalModel(
      subwayId: _asString(json['subwayId']),
      updnLine: _asString(json['updnLine']),
      statnFid: _asString(json['statnFid']),
      statnTid: _asString(json['statnTid']),
      statnId: _asString(json['statnId']),
      btrainSttus: _asString(json['btrainSttus']),
      btrainNo: _asString(json['btrainNo']),
      barvlDt: _asString(json['barvlDt']),
      bstatnNm: _asString(json['bstatnNm']),
      arvlMsg2: _asString(json['arvlMsg2']),
      arvlMsg3: _asString(json['arvlMsg3']),
      arvlCd: _asString(json['arvlCd']),
      lstcarAt: _asString(json['lstcarAt']),
    );
  }

  final String subwayId;
  final String updnLine;
  final String statnFid;
  final String statnTid;
  final String statnId;
  final String btrainSttus;
  final String btrainNo;
  final String barvlDt;
  final String bstatnNm;
  final String arvlMsg2;
  final String arvlMsg3;
  final String arvlCd;
  final String lstcarAt;

  AdjacentStationDirectionType? get directionType {
    if (_isLine2) {
      return switch (updnLine) {
        '외선' => AdjacentStationDirectionType.prev,
        '내선' => AdjacentStationDirectionType.next,
        _ => _defaultDirectionType,
      };
    }

    return _defaultDirectionType;
  }

  AdjacentStationDirectionType? get _defaultDirectionType {
    return switch (updnLine) {
      '상행' || '내선' => AdjacentStationDirectionType.prev,
      '하행' || '외선' => AdjacentStationDirectionType.next,
      '0' => AdjacentStationDirectionType.prev,
      '1' => AdjacentStationDirectionType.next,
      _ => null,
    };
  }

  int? get arrivalCode => int.tryParse(arvlCd);

  int? get arrivalSeconds => int.tryParse(barvlDt);

  bool get isLastTrain => lstcarAt == '1';

  bool get _isLine2 => subwayId == '1002' || subwayId == '2';

  Map<String, dynamic> toJson() {
    return {
      'subwayId': subwayId,
      'updnLine': updnLine,
      'statnFid': statnFid,
      'statnTid': statnTid,
      'statnId': statnId,
      'btrainSttus': btrainSttus,
      'btrainNo': btrainNo,
      'barvlDt': barvlDt,
      'bstatnNm': bstatnNm,
      'arvlMsg2': arvlMsg2,
      'arvlMsg3': arvlMsg3,
      'arvlCd': arvlCd,
      'lstcarAt': lstcarAt,
    };
  }
}

String _asString(Object? value) {
  if (value == null) {
    return '';
  }

  if (value is String) {
    return value;
  }

  return value.toString();
}
