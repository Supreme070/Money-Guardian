import 'package:flutter/material.dart';

import 'dark_color.dart';
import 'light_color.dart';

class AppTheme {
  const AppTheme();

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: LightColor.background,
    primaryColor: LightColor.navyBlue1,
    cardTheme: CardThemeData(color: LightColor.navyBlue2),
    textTheme: TextTheme(headlineMedium: TextStyle(color: LightColor.black)),
    iconTheme: IconThemeData(color: LightColor.navyBlue2),
    bottomAppBarTheme: BottomAppBarThemeData(color: LightColor.background),
    dividerColor: LightColor.lightGrey,
    primaryTextTheme: TextTheme(
      bodyMedium: TextStyle(color: LightColor.titleTextColor),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: DarkColor.background,
    primaryColor: DarkColor.navyBlue1,
    cardTheme: CardThemeData(color: DarkColor.cardBackground),
    textTheme: TextTheme(headlineMedium: TextStyle(color: DarkColor.textDark)),
    iconTheme: IconThemeData(color: DarkColor.accentBlue),
    bottomAppBarTheme: BottomAppBarThemeData(color: DarkColor.background),
    dividerColor: DarkColor.surfaceColor,
    primaryTextTheme: TextTheme(
      bodyMedium: TextStyle(color: DarkColor.titleTextColor),
    ),
  );

  static TextStyle titleStyle =
      const TextStyle(color: LightColor.titleTextColor, fontSize: 16);
  static TextStyle subTitleStyle =
      const TextStyle(color: LightColor.subTitleTextColor, fontSize: 12);

  static TextStyle h1Style =
      const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
  static TextStyle h2Style = const TextStyle(fontSize: 22);
  static TextStyle h3Style = const TextStyle(fontSize: 20);
  static TextStyle h4Style = const TextStyle(fontSize: 18);
  static TextStyle h5Style = const TextStyle(fontSize: 16);
  static TextStyle h6Style = const TextStyle(fontSize: 14);
}
