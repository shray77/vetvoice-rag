import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/ds.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// VetEco — vet-ds v2.3.2: голос A «Научная периодика» + бирюза бренда.
/// v1.2.0: бумага A-light / тёплый графит A-dark (lib/theme/ds.dart —
/// DsLight/DsDark), характер — Vet Teal #0F766E/#2DD4BF (зеркально
/// vet-insilico), эмодзи в UI запрещены, радиусы ≤ 10, текст ≥ AA,
/// движение 160 мс, Prata-дисплей. Прежние имена констант сохранены
/// (AppColors.*, AppTypography.*) — значения едут из ядра DS.
/// ═══════════════════════════════════════════════════════════════════════
/// Inspired by Apple Health — clean clinical aesthetic, generous whitespace,
/// strong typographic hierarchy, semantic color usage.
///
/// Brand: Vet Teal (#0D9488) — calm, medical, trustworthy.
/// Density: Comfortable (15-16pt body, 16px screen padding).
/// Theme: Auto (system) — proper Material 3 dark mode.
/// ═══════════════════════════════════════════════════════════════════════

class AppColors {
  // ─── Brand: Vet Teal ───────────────────────────────────────────────
  /// Primary brand color — calm clinical teal.
  static const Color primary = DsLight.accent; // характер: AA на бумаге
  static const Color primaryLight = DsDark.accent; // яркий характер для тёмного
  static const Color primaryDark = DsLight.accentStrong;
  static const Color primaryContainer = Color(0xFFD8F0ED);   // бирюзовый тинт на бумаге
  static const Color primaryContainerDark = Color(0xFF123B37);
  static const Color onPrimary = DsLight.accentInk;
  static const Color onPrimaryContainer = Color(0xFF123B37);

  // ─── Semantic ──────────────────────────────────────────────────────
  static const Color success = DsLight.green;
  static const Color successContainer = Color(0xFFDDEBD6);
  static const Color warning = DsLight.orange;
  static const Color warningContainer = Color(0xFFF5E7DC);
  static const Color danger = DsLight.red;
  static const Color dangerContainer = Color(0xFFFBE3E1);
  static const Color info = DsLight.blue;
  static const Color infoContainer = Color(0xFFE1EAF2);

  // ─── Apple-style system colors (kept for semantic clarity) ────────
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemYellow = Color(0xFFFFCC00);
  static const Color systemPurple = Color(0xFFAF52DE);
  static const Color systemTeal = Color(0xFF5AC8FA);
  static const Color systemIndigo = Color(0xFF5856D6);
  static const Color systemPink = Color(0xFFFF2D55);
  static const Color systemCyan = Color(0xFF32ADE6);
  static const Color systemBrown = Color(0xFF8E6E53);
  static const Color systemGrey = Color(0xFF8E8E93);

  // ─── Light theme surfaces ──────────────────────────────────────────
  static const Color background = DsLight.bg;           // тёплая бумага DS
  static const Color surface = DsLight.surface;        // Card surface
  static const Color secondarySurface = DsLight.surface2;
  static const Color tertiarySurface = Color(0xFFE9E6DC);

  // ─── Light theme text ──────────────────────────────────────────────
  static const Color textPrimary = DsLight.text;
  static const Color textSecondary = DsLight.muted;
  static const Color textTertiary = DsLight.faint;
  static const Color textPlaceholder = Color(0xFF9E9789);
  static const Color textOnTeal = DsLight.accentInk;

  // ─── Light theme separators/fills ──────────────────────────────────
  static const Color separator = DsLight.border;
  static const Color opaqueSeparator = DsLight.borderStrong;
  static const Color fillPrimary = Color(0x331C1B1A);
  static const Color fillSecondary = Color(0x1A1C1B1A);

  // ─── Dark theme surfaces ───────────────────────────────────────────
  /// Slightly off-black for less eye strain vs pure black.
  static const Color darkBackground = DsDark.bg;
  static const Color darkSurface = DsDark.surface;
  static const Color darkSecondarySurface = DsDark.surface2;
  static const Color darkTertiarySurface = DsDark.border;

  // ─── Dark theme text ───────────────────────────────────────────────
  static const Color darkTextPrimary = DsDark.text;
  static const Color darkTextSecondary = DsDark.muted;
  static const Color darkTextTertiary = DsDark.faint;
  static const Color darkTextPlaceholder = DsDark.rule;

  // ─── Dark theme separators/fills ───────────────────────────────────
  static const Color darkSeparator = DsDark.border;
  static const Color darkOpaqueSeparator = DsDark.borderStrong;
  static const Color darkFillPrimary = Color(0x66EDE9E0);
  static const Color darkFillSecondary = Color(0x33EDE9E0);

  // ─── Severity scale (for medical status indicators) ────────────────
  static const Color severityCritical = DsLight.red;
  static const Color severityWarning = DsLight.orange;
  static const Color severityModerate = DsLight.amber;
  static const Color severityInfo = DsLight.blue;
  static const Color severityMild = DsLight.green;

  // ─── Legacy aliases (keep for back-compat with existing screens) ──
  static const Color error = danger;
}

/// Apple SF Pro-inspired typography, calibrated for medical UIs.
/// Body uses 16pt for comfortable density.
class AppTypography {
  // ─── Display / Headers ─────────────────────────────────────────────
  static const TextStyle largeTitle = TextStyle(
    fontFamily: Ds.display, // Prata — заголовки-витрины периодики
    fontSize: 34,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    height: 1.12,
  );

  static const TextStyle title1 = TextStyle(
    fontFamily: Ds.display, // Prata — заголовки-витрины периодики
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    height: 1.18,
  );

  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.24,
  );

  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.29,
  );

  // ─── Body ──────────────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.15,
    height: 1.4,
  );

  static const TextStyle callout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.35,
  );

  static const TextStyle subheadline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.33,
  );

  // ─── Small / Labels ────────────────────────────────────────────────
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.38,
  );

  static const TextStyle caption1 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.33,
  );

  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.18,
  );

  // ─── Specialized ───────────────────────────────────────────────────
  /// For numeric values in dose calculator — tabular figures.
  static const TextStyle metric = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// For section labels above content blocks.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    height: 1.4,
  );

  /// Section title inside content/cards — sits above body (16) in hierarchy.
  /// Use for in-card headings ("Алгоритм:", "Препараты:", tier labels) so the
  /// design system — not magic numbers — owns the size.
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
  );

  /// Micro text for dense badges/chips (compact mode).
  static const TextStyle micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.1,
  );

  /// Aliases
  static const TextStyle caption = caption1;
  static const TextStyle label = caption1;
}

/// Spacing scale based on 4px grid.
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  static const double screenPadding = 16.0;
  static const double screenPaddingLg = 20.0;
  static const double cardPadding = 16.0;
  static const double cardPaddingLg = 20.0;
  static const double sectionSpacing = 24.0;
  static const double itemSpacing = 12.0;
}

/// Corner radius scale.
class AppRadius {
  static const double xs = 4.0;
  static const double small = 8.0;
  static const double medium = Ds.radius;
  static const double large = Ds.radius;
  static const double xl = Ds.radius;
  static const double xxl = Ds.radius;
  static const double full = 9999.0;

  /// Card radius (matches Material 3 default).
  static const double card = Ds.radius;

  /// Button radius.
  static const double button = Ds.radiusS;

  /// Chip/badge radius.
  static const double chip = Ds.radiusS;
}

/// Elevation (subtle, Apple-style — small shadows only).
class AppElevation {
  static const List<BoxShadow> none = [];
  static List<BoxShadow> get low => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> get high => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Animation durations.
class AppDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Ds.dur; // 160 мс — единая спецификация DS
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slower = Duration(milliseconds: 800);
}

/// Animation curves.
class AppCurves {
  static const Curve standard = Curves.easeInOutCubicEmphasized;
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve accelerate = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;
}

/// ─── Theme data ──────────────────────────────────────────────────────

class AppTheme {
  /// Night mode — amber accent + pure black bg, reduces eye strain at night.
  static ThemeData get nightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: DsDark.amber,
      onPrimary: Color(0xFF1F1305),
      primaryContainer: Color(0xFF3E2723),
      onPrimaryContainer: Color(0xFFFFCC80),
      secondary: DsDark.amber,
      onSecondary: Color(0xFF1F1305),
      surface: Color(0xFF16130E),
      onSurface: DsDark.text,
      surfaceContainerHighest: Color(0xFF2A251C),
      error: DsDark.red,
      onError: Color(0xFF1F1305),
      outline: Color(0xFF332D22),
      outlineVariant: Color(0xFF3A3428),
    ),
    scaffoldBackgroundColor: const Color(0xFF16130E),
    canvasColor: const Color(0xFF16130E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF16130E),
      foregroundColor: DsDark.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: DsDark.text, letterSpacing: -0.3),
      systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF201C15),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A251C), thickness: 0.5, space: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF241F17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: DsDark.amber, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppTypography.body.copyWith(color: const Color(0xFF6E685C)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF16130E),
      surfaceTintColor: Colors.transparent,
      indicatorColor: const Color(0xFF3E2A1D),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.caption2.copyWith(color: DsDark.amber, fontWeight: FontWeight.w600);
        }
        return AppTypography.caption2.copyWith(color: const Color(0xFF6E685C));
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: DsDark.amber, size: 24);
        }
        return const IconThemeData(color: Color(0xFF6E685C), size: 24);
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(DsDark.amber),
        foregroundColor: WidgetStateProperty.all(const Color(0xFF1F1305)),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
        textStyle: WidgetStateProperty.all(AppTypography.callout),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: AppTypography.largeTitle,
      displayMedium: AppTypography.title1,
      displaySmall: AppTypography.title2,
      headlineLarge: AppTypography.title2,
      headlineMedium: AppTypography.title3,
      headlineSmall: AppTypography.headline,
      titleLarge: AppTypography.title3,
      titleMedium: AppTypography.headline,
      titleSmall: AppTypography.subheadline,
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.bodyMedium,
      bodySmall: AppTypography.footnote,
      labelLarge: AppTypography.callout,
      labelMedium: AppTypography.caption1,
      labelSmall: AppTypography.caption2,
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.primary,
      onSecondary: AppColors.onPrimary,
      secondaryContainer: AppColors.primaryContainer,
      onSecondaryContainer: AppColors.onPrimaryContainer,
      tertiary: AppColors.info,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.secondarySurface,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.separator,
      outlineVariant: AppColors.tertiarySurface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.separator,
      thickness: 0.5,
      space: 0.5,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.secondarySurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppTypography.body.copyWith(color: AppColors.textPlaceholder),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.caption2.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          );
        }
        return AppTypography.caption2.copyWith(color: AppColors.textTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 24);
        }
        return const IconThemeData(color: AppColors.textTertiary, size: 24);
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.onPrimary;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.tertiarySurface;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.separator;
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.tertiarySurface;
          return AppColors.primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.textTertiary;
          return AppColors.onPrimary;
        }),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        textStyle: WidgetStateProperty.all(AppTypography.callout),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.primary),
        textStyle: WidgetStateProperty.all(AppTypography.callout),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.primary),
        side: WidgetStateProperty.all(const BorderSide(color: AppColors.separator, width: 1)),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        textStyle: WidgetStateProperty.all(AppTypography.callout),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.secondarySurface,
      selectedColor: AppColors.primaryContainer,
      labelStyle: AppTypography.caption1.copyWith(color: AppColors.textPrimary),
      secondaryLabelStyle: AppTypography.caption1.copyWith(color: AppColors.onPrimaryContainer),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.tertiarySurface,
      circularTrackColor: AppColors.tertiarySurface,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.tertiarySurface,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withValues(alpha: 0.12),
      trackHeight: 4,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: AppTypography.subheadline.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: AppTypography.subheadline,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.08)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      modalBarrierColor: Color(0x66000000),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.opaqueSeparator), // волосок DS
      ),
      titleTextStyle: AppTypography.title3.copyWith(color: AppColors.textPrimary),
      contentTextStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.secondarySurface, // DS-панель surface2
      contentTextStyle: AppTypography.body.copyWith(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: const BorderSide(color: AppColors.opaqueSeparator), // волосок DS
      ),
      actionTextColor: AppColors.primary,
    ),
    textTheme: const TextTheme(
      displayLarge: AppTypography.largeTitle,
      displayMedium: AppTypography.title1,
      displaySmall: AppTypography.title2,
      headlineLarge: AppTypography.title2,
      headlineMedium: AppTypography.title3,
      headlineSmall: AppTypography.headline,
      titleLarge: AppTypography.title3,
      titleMedium: AppTypography.headline,
      titleSmall: AppTypography.subheadline,
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.bodyMedium,
      bodySmall: AppTypography.footnote,
      labelLarge: AppTypography.callout,
      labelMedium: AppTypography.caption1,
      labelSmall: AppTypography.caption2,
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainerDark,
      onPrimaryContainer: AppColors.primaryContainer,
      secondary: AppColors.primaryLight,
      onSecondary: AppColors.onPrimary,
      secondaryContainer: AppColors.primaryContainerDark,
      onSecondaryContainer: AppColors.primaryContainer,
      tertiary: DsDark.blue,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkSecondarySurface,
      error: DsDark.red,
      onError: Colors.white,
      outline: AppColors.darkSeparator,
      outlineVariant: AppColors.darkTertiarySurface,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    canvasColor: AppColors.darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
        letterSpacing: -0.3,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkSeparator,
      thickness: 0.5,
      space: 0.5,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSecondarySurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: DsDark.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: DsDark.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppTypography.body.copyWith(color: AppColors.darkTextTertiary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: AppColors.darkTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryContainerDark,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.caption2.copyWith(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.w600,
          );
        }
        return AppTypography.caption2.copyWith(color: AppColors.darkTextTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primaryLight, size: 24);
        }
        return const IconThemeData(color: AppColors.darkTextTertiary, size: 24);
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.onPrimary;
        return AppColors.darkTextTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
        return AppColors.darkTertiarySurface;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
        return AppColors.darkSeparator;
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.darkTertiarySurface;
          return AppColors.primaryLight;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.darkTextTertiary;
          return AppColors.onPrimary;
        }),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        textStyle: WidgetStateProperty.all(AppTypography.callout),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.primaryLight),
        textStyle: WidgetStateProperty.all(AppTypography.callout),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.primaryLight),
        side: WidgetStateProperty.all(const BorderSide(color: AppColors.darkSeparator, width: 1)),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        textStyle: WidgetStateProperty.all(AppTypography.callout),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSecondarySurface,
      selectedColor: AppColors.primaryContainerDark,
      labelStyle: AppTypography.caption1.copyWith(color: AppColors.darkTextPrimary),
      secondaryLabelStyle: AppTypography.caption1.copyWith(color: AppColors.primaryContainer),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryLight,
      linearTrackColor: AppColors.darkTertiarySurface,
      circularTrackColor: AppColors.darkTertiarySurface,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primaryLight,
      inactiveTrackColor: AppColors.darkTertiarySurface,
      thumbColor: AppColors.primaryLight,
      overlayColor: AppColors.primaryLight.withValues(alpha: 0.12),
      trackHeight: 4,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primaryLight,
      unselectedLabelColor: AppColors.darkTextSecondary,
      labelStyle: AppTypography.subheadline.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: AppTypography.subheadline,
      indicatorColor: AppColors.primaryLight,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(AppColors.primaryLight.withValues(alpha: 0.08)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      modalBarrierColor: Color(0x99000000),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.darkOpaqueSeparator), // волосок DS
      ),
      titleTextStyle: AppTypography.title3.copyWith(color: AppColors.darkTextPrimary),
      contentTextStyle: AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkSecondarySurface, // DS-панель surface2
      contentTextStyle: AppTypography.body.copyWith(color: AppColors.darkTextPrimary),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: const BorderSide(color: AppColors.darkOpaqueSeparator), // волосок DS
      ),
      actionTextColor: AppColors.primaryLight,
    ),
    textTheme: const TextTheme(
      displayLarge: AppTypography.largeTitle,
      displayMedium: AppTypography.title1,
      displaySmall: AppTypography.title2,
      headlineLarge: AppTypography.title2,
      headlineMedium: AppTypography.title3,
      headlineSmall: AppTypography.headline,
      titleLarge: AppTypography.title3,
      titleMedium: AppTypography.headline,
      titleSmall: AppTypography.subheadline,
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.bodyMedium,
      bodySmall: AppTypography.footnote,
      labelLarge: AppTypography.callout,
      labelMedium: AppTypography.caption1,
      labelSmall: AppTypography.caption2,
    ),
  );
}

/// Haptic feedback helpers — keep interactions tactile.
class HapticHelper {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
}
