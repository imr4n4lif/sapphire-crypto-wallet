import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {

  // // Light Theme Colors
  // static const Color primaryLight = Color(0xFF6C63FF);
  // static const Color secondaryLight = Color(0xFF4CAF50);
  // static const Color backgroundLight = Color(0xFFF5F7FA);
  // static const Color surfaceLight = Color(0xFFFFFFFF);
  // static const Color errorLight = Color(0xFFE53935);
  // static const Color successLight = Color(0xFF4CAF50);
  // static const Color warningLight = Color(0xFFFFA726);
  //
  // // Dark Theme Colors
  // static const Color primaryDark = Color(0xFF8B83FF);
  // static const Color secondaryDark = Color(0xFF66BB6A);
  // static const Color backgroundDark = Color(0xFF121212);
  // static const Color surfaceDark = Color(0xFF1E1E1E);
  // static const Color errorDark = Color(0xFFEF5350);
  // static const Color successDark = Color(0xFF66BB6A);
  // static const Color warningDark = Color(0xFFFFB74D);

  // Light Theme Colors
  static const Color primaryLight = Color(0xFF3A7BFF);      // Soft bright blue
  static const Color secondaryLight = Color(0xFF2B2D30);    // Aqua/teal accent
  static const Color backgroundLight = Color(0xFFF2F6FA);   // Gentle bluish-white
  static const Color surfaceLight = Color(0xFFFFFFFF);      // Clean white surfaces
  static const Color errorLight = Color(0xFFDC3545);        // Modern red
  static const Color successLight = Color(0xFF2ECC71);      // Fresh green
  static const Color warningLight = Color(0xFFFFC75F);      // Warm but soft yellow


  // Dark Theme Colors
  static const Color primaryDark = Color(0xFF5EA0FF);       // Vibrant soft blue
  static const Color secondaryDark = Color(0xFF00D4FF);     // Neon aqua accent
  static const Color backgroundDark = Color(0xFF0D1117);    // GitHub-style deep navy
  static const Color surfaceDark = Color(0xFF161B22);       // Slightly lighter navy
  static const Color errorDark = Color(0xFFFF6B6B);         // Softened red
  static const Color successDark = Color(0xFF28D98B);       // Neon green
  static const Color warningDark = Color(0xFFFFD580);       // Softer amber


  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: secondaryLight,
        surface: surfaceLight,
        error: errorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
          bodySmall: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        color: surfaceLight,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: backgroundLight,
        foregroundColor: Colors.black87,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorLight),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        secondary: secondaryDark,
        surface: surfaceDark,
        error: errorDark,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onError: Colors.black,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
          bodySmall: TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        color: surfaceDark,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: backgroundDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorDark),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}