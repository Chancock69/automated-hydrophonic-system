import 'package:flutter/material.dart';

class AHSColors {
  static const Color primary = Color(0xFF176B45);
  static const Color primaryMid = Color(0xFF228A58);
  static const Color primaryLight = Color(0xFF4DBB78);
  static const Color primaryGlow = Color(0xFFD9F2E3);

  static const Color bg = Color(0xFFF5F7F6);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgCardAlt = Color(0xFFF0F5F2);
  static const Color border = Color(0xFFDCE5E0);
  static const Color divider = Color(0xFFE8EEEB);

  static const Color textDark = Color(0xFF14251C);
  static const Color textMid = Color(0xFF486057);
  static const Color textSoft = Color(0xFF72847C);
  static const Color textHint = Color(0xFFA2B0AA);

  static const Color stable = Color(0xFF199B5A);
  static const Color stableGlow = Color(0xFFDDF4E8);
  static const Color sensor = Color(0xFF00A8BD);
  static const Color sensorGlow = Color(0xFFDDF6F8);
  static const Color warning = Color(0xFFC58A00);
  static const Color warningGlow = Color(0xFFFFF3D6);
  static const Color critical = Color(0xFFD73A3A);
  static const Color criticalGlow = Color(0xFFFFE7E7);

  // Kept for compatibility with existing graph widgets.
  static const Color neonGreen = Color(0xFF16B86C);
  static const Color neonCyan = Color(0xFF00BCD4);
  static const Color neonLime = Color(0xFF91C93C);
  static const Color neonAmber = Color(0xFFE0A415);
}

class AHSTheme {
  static const double panelRadius = 8;
  static const double controlRadius = 8;

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AHSColors.primary,
      brightness: Brightness.light,
      primary: AHSColors.primary,
      surface: AHSColors.bgCard,
      error: AHSColors.critical,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: AHSColors.bg,
      colorScheme: colorScheme,
      dividerColor: AHSColors.divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: AHSColors.textDark,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: AHSColors.textDark,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: AHSColors.textDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: AHSColors.textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AHSColors.textMid,
        ),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AHSColors.bg,
        foregroundColor: AHSColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AHSColors.textDark),
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AHSColors.textDark,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AHSColors.bgCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(panelRadius)),
          side: BorderSide(color: AHSColors.border),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AHSColors.bgCard,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(panelRadius)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: AHSColors.textDark,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          height: 1.45,
          color: AHSColors.textMid,
        ),
        actionsPadding: EdgeInsets.fromLTRB(20, 4, 20, 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AHSColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AHSColors.primary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          side: const BorderSide(color: AHSColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AHSColors.primary,
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AHSColors.textMid,
          minimumSize: const Size.square(40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AHSColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AHSColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AHSColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AHSColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AHSColors.critical),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Nunito',
          color: AHSColors.textHint,
          fontSize: 13,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AHSColors.textDark,
        contentTextStyle: TextStyle(
          fontFamily: 'Nunito',
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AHSColors.bg,
        modalBackgroundColor: AHSColors.bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: AHSColors.bgCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AHSColors.primaryGlow,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: states.contains(WidgetState.selected)
                ? AHSColors.primary
                : AHSColors.textSoft,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AHSColors.primary
                : AHSColors.textSoft,
            size: 23,
          );
        }),
      ),
    );
  }
}
