class DeviceSession {
  const DeviceSession({
    required this.osType,
    required this.uuid,
    required this.secret,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String osType;
  final String uuid;
  final String secret;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  DeviceSession copyWith({
    String? osType,
    String? uuid,
    String? secret,
    String? accessToken,
    String? refreshToken,
    int? expiresIn,
  }) {
    return DeviceSession(
      osType: osType ?? this.osType,
      uuid: uuid ?? this.uuid,
      secret: secret ?? this.secret,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresIn: expiresIn ?? this.expiresIn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'osType': osType,
      'uuid': uuid,
      'secret': secret,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
    };
  }

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      osType: json['osType'] as String,
      uuid: json['uuid'] as String,
      secret: json['secret'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
    );
  }
}
