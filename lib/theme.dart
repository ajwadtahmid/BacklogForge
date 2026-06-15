import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

// Brand accent — electric indigo, gaming-forward
const _kSeed = Color(0xFF6C4DF6);

// Dark surface ramp — layered depth instead of flat charcoal
const _kDarkBg               = Color(0xFF0E0E12);
const _kDarkCard              = Color(0xFF16161D);
const _kDarkRaised            = Color(0xFF1E1E27);
const _kDarkElevated          = Color(0xFF252535);
const _kDarkOutline           = Color(0xFF2E2E42);
const _kDarkOutlineVariant    = Color(0xFF23233A);

// Light surface ramp — warm off-white with an indigo tint, matching the dark
// theme's layering hierarchy so both modes feel like the same design system.
const _kLightBg               = Color(0xFFF5F4FC);
const _kLightCard              = Color(0xFFECEAF8);
const _kLightRaised            = Color(0xFFE3E0F4);
const _kLightElevated          = Color(0xFFDAD7F0);
const _kLightOutline           = Color(0xFFCCC9E4);
const _kLightOutlineVariant    = Color(0xFFD8D5EC);

// Semantic state colors — consistent across light/dark
const kColorPlaying    = Color(0xFF4CAF82);
const kColorPlayingBg  = Color(0x1A4CAF82);
const kColorProgressLo = Color(0xFF6C4DF6);
const kColorProgressMid = Color(0xFFFFB74D);
const kColorProgressHi = Color(0xFF4CAF82);

// Completion grade colors — A through D.
// kGradeA reuses kColorPlaying (same green hue).
const kColorGradeB = Color(0xFF26A69A); // teal
const kColorGradeD = Color(0xFFFF8A65); // soft orange

TextTheme _buildTextTheme(Brightness brightness) {
  final base = brightness == Brightness.dark
      ? ThemeData.dark().textTheme
      : ThemeData.light().textTheme;
  return GoogleFonts.spaceGroteskTextTheme(base);
}

ColorScheme _darkColorScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: _kSeed,
    brightness: Brightness.dark,
  );
  return base.copyWith(
    surface: _kDarkBg,
    surfaceContainerLowest: const Color(0xFF0A0A0F),
    surfaceContainerLow: _kDarkBg,
    surfaceContainer: _kDarkCard,
    surfaceContainerHigh: _kDarkRaised,
    surfaceContainerHighest: _kDarkElevated,
    outline: _kDarkOutline,
    outlineVariant: _kDarkOutlineVariant,
  );
}

ColorScheme _lightColorScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: _kSeed,
    brightness: Brightness.light,
  );
  return base.copyWith(
    surface: _kLightBg,
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: _kLightBg,
    surfaceContainer: _kLightCard,
    surfaceContainerHigh: _kLightRaised,
    surfaceContainerHighest: _kLightElevated,
    outline: _kLightOutline,
    outlineVariant: _kLightOutlineVariant,
  );
}

ThemeData _buildTheme(ColorScheme cs) {
  final textTheme = _buildTextTheme(cs.brightness);

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    textTheme: textTheme,

    scaffoldBackgroundColor: cs.surface,

    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      iconTheme: IconThemeData(color: cs.onSurfaceVariant),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: cs.primary,
      unselectedLabelColor: cs.onSurfaceVariant,
      indicatorColor: cs.primary,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: textTheme.labelMedium,
    ),

    cardTheme: CardThemeData(
      color: cs.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
    ),

    listTileTheme: ListTileThemeData(
      titleTextStyle:
          textTheme.bodyLarge?.copyWith(color: cs.onSurface),
      subtitleTextStyle:
          textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      iconColor: cs.onSurfaceVariant,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      isDense: true,
      hintStyle: TextStyle(color: cs.onSurfaceVariant),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cs.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: cs.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),

    dividerTheme: DividerThemeData(
      color: cs.outlineVariant.withValues(alpha: 0.5),
      thickness: 0.5,
      space: 0,
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: cs.primary,
      linearTrackColor: cs.surfaceContainerHighest,
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle:
          textTheme.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
    ),
  );
}

final lightTheme = _buildTheme(_lightColorScheme());
final darkTheme  = _buildTheme(_darkColorScheme());

/// Returns a progress-bar color that shifts primary → amber → green as
/// completion approaches 100%.
Color progressColor(double progress, ColorScheme cs) {
  if (progress >= AppConstants.kProgressColorHiThreshold) return kColorProgressHi;
  if (progress >= AppConstants.kProgressColorMidThreshold) return kColorProgressMid;
  return cs.primary;
}
