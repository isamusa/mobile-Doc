import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF00796B); // Teal 700
  static const Color secondary = Color(0xFFB2DFDB); // Teal 100
  static const Color background = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
  static const Color aiBubble = Color(0xFFE0F2F1);
  static const Color userBubble = Color(0xFF00796B);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primary,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 1,
      ),
    );
  }
}
