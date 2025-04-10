import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Colors - Changed to dark purple theme
  static const Color primaryColor = Color(0xFF4A148C);
  static const Color primaryLightColor = Color(0xFF7c43bd);
  static const Color primaryDarkColor = Color(0xFF12005e);
  
  // Secondary Colors
  static const Color accentColor = Color(0xFF6A1B9A);
  static const Color accentLightColor = Color(0xFF9c4dcc);
  static const Color accentDarkColor = Color(0xFF38006b);
  
  // Background Colors - Changed to black
  static const Color backgroundColor = Color(0xFF000000);
  static const Color surfaceColor = Color(0xFF121212);
  static const Color cardColor = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimaryColor = Color(0xFFFFFFFF);
  static const Color textSecondaryColor = Color(0xB3FFFFFF); // White with 70% opacity
  static const Color textDisabledColor = Color(0x61FFFFFF); // White with 38% opacity

  // Glass effect colors - Changed to dark purple
  static const Color glassColor = Color(0x4D4A148C);
  static const Color glassBorderColor = Color(0x334A148C);

  // Error
  static const Color errorColor = Color(0xFFCF6679);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: textPrimaryColor,
        displayColor: textPrimaryColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textPrimaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: cardColor,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: glassBorderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(
          color: textSecondaryColor,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.poppins(
          color: textDisabledColor,
          fontSize: 14,
        ),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
    );
  }
} 