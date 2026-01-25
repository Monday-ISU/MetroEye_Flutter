import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const fontFamily = 'NotoSansKR';

  // 타이틀1 - Bold - 24
  static const title1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  // 본문1 - Light - 48
  static const body1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w300,
  );

  // 본문2 - Light - 24
  static const body2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w300,
  );

  // 본문3 - Medium - 16
  static const body3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  // 본문4 - Bold - 16
  static const body4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  // 본문5 - Regular - 12
  static const body5 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  // 본문6 - Bold - 12
  static const body6 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  // 본문7 - Regular - 8
  static const body7 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 8,
    fontWeight: FontWeight.w400,
  );

  // 본문8 - Bold - 8
  static const body8 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 8,
    fontWeight: FontWeight.w700,
  );

  static const textTheme = TextTheme(
    titleLarge: title1,
    bodyLarge: body3,
    bodyMedium: body5,
    labelMedium: body7,
  );
}
