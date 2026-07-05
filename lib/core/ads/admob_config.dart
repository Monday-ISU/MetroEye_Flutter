import 'dart:io';

import 'package:flutter/foundation.dart';

enum AdMobBannerPlacement { homeSearch, realtimeTrainPosition }

abstract final class AdMobConfig {
  static const androidAppId = 'ca-app-pub-7394989706935409~7875728386';

  static const _androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  static const _homeSearchBannerAdUnitId =
      'ca-app-pub-7394989706935409/2623401708';
  static const _realtimeTrainPositionBannerAdUnitId =
      'ca-app-pub-7394989706935409/6804143691';

  static String bannerAdUnitId(AdMobBannerPlacement placement) {
    if (!kReleaseMode) {
      return Platform.isIOS
          ? _iosTestBannerAdUnitId
          : _androidTestBannerAdUnitId;
    }

    return switch (placement) {
      AdMobBannerPlacement.homeSearch => _homeSearchBannerAdUnitId,
      AdMobBannerPlacement.realtimeTrainPosition =>
        _realtimeTrainPositionBannerAdUnitId,
    };
  }
}
