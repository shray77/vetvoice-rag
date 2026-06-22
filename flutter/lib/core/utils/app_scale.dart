import 'package:flutter/widgets.dart';
import '../theme/app_theme.dart';

/// Адаптивный масштаб для шрифтов и spacing.
/// Базовый размер: 375px ширины (iPhone SE / средний Android).
/// На больших экранах — слегка увеличивает, на маленьких — уменьшает.
///
/// Использование:
///   final scale = AppScale.of(context);
///   Text('Привет', style: AppTypography.body.scaled(scale))
///   SizedBox(height: AppSpacing.lg * scale.vertical)
class AppScale {
  final double textScale;
  final double spacingScale;

  const AppScale._(this.textScale, this.spacingScale);

  /// Базовая ширина экрана для расчёта масштаба.
  static const double _baseWidth = 375.0;
  static const double _baseHeight = 812.0;

  /// Получить масштаб для текущего контекста.
  factory AppScale.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;

    // Текст масштабируется по ширине, но ограничен 0.85..1.15
    final rawTextScale = width / _baseWidth;
    final textScale = rawTextScale.clamp(0.85, 1.15);

    // Spacing масштабируется по минимальному измерению
    final minDim = width < height ? width : height;
    final rawSpacingScale = minDim / _baseWidth;
    final spacingScale = rawSpacingScale.clamp(0.85, 1.10);

    return AppScale._(textScale, spacingScale);
  }

  // ─── Spacing helpers ──────────────────────────────────────────────
  double get xs => AppSpacing.xs * spacingScale;
  double get sm => AppSpacing.sm * spacingScale;
  double get md => AppSpacing.md * spacingScale;
  double get lg => AppSpacing.lg * spacingScale;
  double get xl => AppSpacing.xl * spacingScale;
  double get xxl => AppSpacing.xxl * spacingScale;
  double get screenPadding => AppSpacing.screenPadding * spacingScale;
  double get cardPadding => AppSpacing.cardPadding * spacingScale;
}

/// Extension для масштабирования TextStyle.
extension ScaledTextStyle on TextStyle {
  TextStyle scaled(double scale) => copyWith(fontSize: (fontSize ?? 16) * scale);
}
