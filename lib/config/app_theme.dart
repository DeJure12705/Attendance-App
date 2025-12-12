import 'package:flutter/material.dart';

/// Application theme configuration for Light and Dark modes
/// Maintains consistent design system with custom green primary color
class AppTheme {
  // Brand colors
  static const Color primaryGreen = Color(0xFF2F912A);
  static const Color primaryGreenDark = Color(0xFF1F6E1C);
  static const Color accentGreen = Color(0xFF4CAF50);

  /// Light Theme Configuration
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Primary color scheme
    colorScheme: ColorScheme.light(
      primary: primaryGreen,
      secondary: accentGreen,
      surface: Colors.white,
      background: Colors.grey[100]!,
      error: Colors.red[700]!,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
      onBackground: Colors.black87,
    ),

    // AppBar theme
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black87),
      titleTextStyle: const TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 20,
        color: Colors.black87,
      ),
    ),

    // Card theme
    cardTheme: CardThemeData(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Elevated button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // Text button theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primaryGreen),
    ),

    // Icon theme
    iconTheme: const IconThemeData(color: Colors.black54, size: 24),

    // Scaffold background
    scaffoldBackgroundColor: Colors.grey[100],

    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
    ),

    // Bottom navigation bar theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryGreen,
      unselectedItemColor: Colors.grey,
      elevation: 8,
    ),

    // Divider theme
    dividerTheme: DividerThemeData(color: Colors.grey[300], thickness: 1),

    // Text theme
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 32,
        color: Colors.black87,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 24,
        color: Colors.black87,
      ),
      titleLarge: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 20,
        color: Colors.black87,
      ),
      titleMedium: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 16,
        color: Colors.black87,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'NexaRegular',
        fontSize: 16,
        color: Colors.black87,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'NexaRegular',
        fontSize: 14,
        color: Colors.black87,
      ),
      labelLarge: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 14,
        color: Colors.black87,
      ),
    ),
  );

  /// Dark Theme Configuration
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Primary color scheme
    colorScheme: ColorScheme.dark(
      primary: accentGreen,
      secondary: primaryGreen,
      surface: const Color(0xFF1E1E1E),
      background: const Color(0xFF121212),
      error: Colors.red[400]!,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
    ),

    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 20,
        color: Colors.white,
      ),
    ),

    // Card theme
    cardTheme: const CardThemeData(
      elevation: 4,
      color: Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    // Elevated button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentGreen,
        foregroundColor: Colors.black,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // Text button theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accentGreen),
    ),

    // Icon theme
    iconTheme: const IconThemeData(color: Colors.white70, size: 24),

    // Scaffold background
    scaffoldBackgroundColor: const Color(0xFF121212),

    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3C3C3C)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3C3C3C)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentGreen, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
    ),

    // Bottom navigation bar theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: accentGreen,
      unselectedItemColor: Colors.white54,
      elevation: 8,
    ),

    // Divider theme
    dividerTheme: const DividerThemeData(
      color: Color(0xFF3C3C3C),
      thickness: 1,
    ),

    // Text theme
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 32,
        color: Colors.white,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 24,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 20,
        color: Colors.white,
      ),
      titleMedium: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 16,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'NexaRegular',
        fontSize: 16,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'NexaRegular',
        fontSize: 14,
        color: Colors.white70,
      ),
      labelLarge: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 14,
        color: Colors.white,
      ),
    ),
  );
}
