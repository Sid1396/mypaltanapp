import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Gilroy';

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          onPrimary: Colors.white,
          onSecondary: AppColors.primary,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        cardTheme: const CardThemeData(elevation: 2),
        textTheme: _textTheme,
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          onPrimary: Colors.white,
          onSecondary: AppColors.primary,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        cardTheme: const CardThemeData(elevation: 2),
        textTheme: _textTheme,
      );

  static const TextTheme _textTheme = TextTheme(
    displayLarge:  TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w900),
    displayMedium: TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w900),
    displaySmall:  TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w700),
    headlineMedium:TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w700),
    titleLarge:    TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w700),
    titleMedium:   TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w500),
    titleSmall:    TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w500),
    bodyLarge:     TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w400),
    bodyMedium:    TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w400),
    bodySmall:     TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w300),
    labelLarge:    TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w500),
    labelMedium:   TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w500),
    labelSmall:    TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w300),
  );
}
