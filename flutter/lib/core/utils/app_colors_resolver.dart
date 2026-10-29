import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Утилиты для получения правильных цветов в зависимости от темы.
/// Используется вместо прямого обращения к AppColors в виджетах.
class AppColorsResolver {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? AppColors.darkBackground : AppColors.background;

  static Color surface(BuildContext context) =>
      isDark(context) ? AppColors.darkSurface : AppColors.surface;

  static Color secondarySurface(BuildContext context) =>
      isDark(context) ? AppColors.darkSecondarySurface : AppColors.secondarySurface;

  static Color tertiarySurface(BuildContext context) =>
      isDark(context) ? AppColors.darkTertiarySurface : AppColors.tertiarySurface;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? AppColors.darkTextPrimary : AppColors.textPrimary;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? AppColors.darkTextSecondary : AppColors.textSecondary;

  static Color textTertiary(BuildContext context) =>
      isDark(context) ? AppColors.darkTextTertiary : AppColors.textTertiary;

  static Color separator(BuildContext context) =>
      isDark(context) ? AppColors.darkSeparator : AppColors.separator;

  static Color primary(BuildContext context) =>
      isDark(context) ? AppColors.primaryLight : AppColors.primary;

  static Color primaryContainer(BuildContext context) =>
      isDark(context) ? AppColors.primaryContainerDark : AppColors.primaryContainer;

  static Color fillPrimary(BuildContext context) =>
      isDark(context) ? AppColors.darkFillPrimary : AppColors.fillPrimary;

  // ── Task 194: семантика со тёмными значениями ─────────────────────
  static Color success(BuildContext context) =>
      isDark(context) ? AppColors.successDark : AppColors.success;

  static Color warning(BuildContext context) =>
      isDark(context) ? AppColors.warningDark : AppColors.warning;

  static Color danger(BuildContext context) =>
      isDark(context) ? AppColors.dangerDark : AppColors.danger;

  static Color info(BuildContext context) =>
      isDark(context) ? AppColors.infoDark : AppColors.info;

  /// Чернила на фоне характера (primary/primaryLight):
  /// светлая мята на бумажной бирюзе, тёмный ink на яркой ночной.
  static Color onPrimary(BuildContext context) =>
      isDark(context) ? AppColors.onPrimaryDark : AppColors.onPrimary;
}
