
import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs mode sombre
  static const Color bgPrimaryDark = Color(0xFF0a1628);
  static const Color bgSecondaryDark = Color(0xFF0f1f3d);
  static const Color bgCardDark = Color(0x0FFFFFFF);
  static const Color bgCardBorderDark = Color(0x14FFFFFF);
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0x80FFFFFF);
  static const Color textTertiaryDark = Color(0x4DFFFFFF);

  // Couleurs mode clair
  static const Color bgPrimaryLight = Color(0xFFF0F4FA);
  static const Color bgSecondaryLight = Color(0xFFE2EAF5);
  static const Color bgCardLight = Colors.white;
  static const Color bgCardBorderLight = Color(0xFFDDE3EE);
  static const Color textPrimaryLight = Color(0xFF0a1628);
  static const Color textSecondaryLight = Color(0xFF4A5568);
  static const Color textTertiaryLight = Color(0xFF8896A8);

  // Couleurs communes
  static const Color blue = Color(0xFF2563eb);
  static const Color blueLight = Color(0xFF60a5fa);
  static const Color blueAccent = Color(0xFF2563eb);
  static const Color green = Color(0xFF16a34a);
  static const Color greenLight = Color(0xFF4ade80);
  static const Color teal = Color(0xFF0d9488);
  static const Color amber = Color(0xFFd97706);
  static const Color amberLight = Color(0xFFfbbf24);
  static const Color red = Color(0xFFdc2626);
  static const Color redLight = Color(0xFFf87171);

  static bool isDark = true;

  // Getters dynamiques
  static Color get bgPrimary => isDark ? bgPrimaryDark : bgPrimaryLight;
  static Color get bgSecondary => isDark ? bgSecondaryDark : bgSecondaryLight;
  static Color get bgCard => isDark ? bgCardDark : bgCardLight;
  static Color get bgCardBorder => isDark ? bgCardBorderDark : bgCardBorderLight;
  static Color get textPrimary => isDark ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary => isDark ? textSecondaryDark : textSecondaryLight;
  static Color get textTertiary => isDark ? textTertiaryDark : textTertiaryLight;
  static Color get colorBlue => isDark ? blueLight : blue;
  static Color get colorGreen => isDark ? greenLight : green;
  static Color get colorAmber => isDark ? amberLight : amber;
  static Color get colorRed => isDark ? redLight : red;

  static ThemeData get theme => isDark ? _darkTheme : _lightTheme;

  static ThemeData get _darkTheme => ThemeData(
        scaffoldBackgroundColor: bgPrimaryDark,
        colorScheme: const ColorScheme.dark(
          primary: blueAccent,
          secondary: blueLight,
          surface: bgSecondaryDark,
        ),
        useMaterial3: true,
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return blueAccent;
            return const Color(0x33FFFFFF);
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0x0FFFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0x14FFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0x14FFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: blueAccent),
          ),
          hintStyle: const TextStyle(color: Color(0x4DFFFFFF)),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Color(0x80FFFFFF)),
        ),
        dividerTheme: const DividerThemeData(color: Color(0x14FFFFFF)),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF0f1f3d),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
          contentTextStyle: TextStyle(color: Color(0x80FFFFFF)),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1d4ed8),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      );

  static ThemeData get _lightTheme => ThemeData(
        scaffoldBackgroundColor: bgPrimaryLight,
        colorScheme: const ColorScheme.light(
          primary: blueAccent,
          secondary: blue,
          surface: bgSecondaryLight,
        ),
        useMaterial3: true,
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return blueAccent;
            return const Color(0xFFCBD5E0);
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: bgCardBorderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: bgCardBorderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: blueAccent),
          ),
          hintStyle: const TextStyle(color: Color(0xFF8896A8)),
          labelStyle: const TextStyle(color: Color(0xFF4A5568)),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: textPrimaryLight),
          bodyMedium: TextStyle(color: textPrimaryLight),
          bodySmall: TextStyle(color: textSecondaryLight),
        ),
        dividerTheme: const DividerThemeData(color: bgCardBorderLight),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(color: textPrimaryLight, fontSize: 18, fontWeight: FontWeight.w500),
          contentTextStyle: TextStyle(color: textSecondaryLight),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: blueAccent,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      );

  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? bgCardBorder, width: isDark ? 1 : 1.2),
      );

  static TextStyle titleStyle() => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static Widget badge(String text, Color bg, Color textColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withOpacity(0.3)),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
      );

  static Widget progressBar(double value) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFDDE3EE),
          valueColor: AlwaysStoppedAnimation<Color>(
            value >= 1.0 ? colorRed : blueAccent,
          ),
        ),
      );
}
