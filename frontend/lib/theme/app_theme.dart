import 'package:flutter/material.dart';

ThemeData appTheme() {
  return ThemeData(
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: Color(0xFF1A1A2E),
    primaryColor: Color(0xFF6C5DD3),
    colorScheme: ColorScheme.dark(
      primary: Color(0xFF6C5DD3),
      secondary: Color(0xFF00C897),
      surface: Color(0xFF25273D),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFF1F1F1)),
      bodyMedium: TextStyle(color: Color(0xFF9CA3AF)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        primary: Color(0xFF6C5DD3),
        textStyle: TextStyle(fontFamily: 'Poppins'),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF25273D),
      labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF6C5DD3)),
      ),
    ),
  );
}