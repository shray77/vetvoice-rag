import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/app_colors_resolver.dart';

/// Polished card with consistent radius, padding, and optional header/footer.
///
/// Variants:
/// - `AppCard.elevated` — subtle shadow for primary content
/// - `AppCard.standard` — flat with thin border (default)
/// - `AppCard.tinted` — tinted background for grouped content
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final double? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.borderRadius,
  });

  /// Subtle shadow card — for primary content blocks (results, key info).
  factory AppCard.elevated({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.cardPaddingLg),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    VoidCallback? onTap,
  }) {
    return AppCard(
      key: key,
      child: child,
      padding: padding,
      margin: margin,
      onTap: onTap,
      boxShadow: AppElevation.low,
      borderRadius: AppRadius.card,
    );
  }

  /// Flat card with subtle separator border — default for list items.
  factory AppCard.standard({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.cardPadding),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    VoidCallback? onTap,
  }) {
    return AppCard(
      key: key,
      child: child,
      padding: padding,
      margin: margin,
      onTap: onTap,
    );
  }

  /// Tinted card for grouped/secondary content.
  factory AppCard.tinted({
    Key? key,
    required Widget child,
    Color? tintColor,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.cardPadding),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    VoidCallback? onTap,
  }) {
    return AppCard(
      key: key,
      child: child,
      padding: padding,
      margin: margin,
      onTap: onTap,
      backgroundColor: tintColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark ? AppColors.darkSurface : AppColors.surface);
    final radius = borderRadius ?? AppRadius.card;
    final defaultBorder = border ??
        Border.all(
          color: isDark ? AppColors.darkSeparator : AppColors.separator,
          width: 0.5,
        );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: defaultBorder,
        boxShadow: boxShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Section header with title, optional subtitle, and optional trailing action.
///
/// Apple-style: small uppercase-ish label, or large display title.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool large;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.large = false,
  });

  /// Large display title — for top of screen.
  const AppSectionHeader.large({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  }) : large = true;

  /// Small label — for section dividers within a screen.
  const AppSectionHeader.label({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  }) : large = false;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryColor = AppColorsResolver.textSecondary(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        bottom: AppSpacing.sm,
        top: AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: large
                      ? AppTypography.largeTitle.copyWith(color: textColor)
                      : AppTypography.sectionLabel.copyWith(
                          color: secondaryColor,
                          letterSpacing: 0.4,
                        ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.footnote.copyWith(color: secondaryColor),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Empty state with icon, title, optional subtitle, and optional action.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconTint;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconTint,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = AppColorsResolver.textSecondary(context);
    final tint = iconTint ?? AppColorsResolver.primary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tint.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: tint),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTypography.headline.copyWith(color: AppColorsResolver.textPrimary(context)),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: AppTypography.subheadline.copyWith(color: secondaryColor),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading state — clean centered spinner with optional message.
class AppLoadingState extends StatelessWidget {
  final String? message;
  final double size;

  const AppLoadingState({
    super.key,
    this.message,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = AppColorsResolver.textSecondary(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColorsResolver.primary(context),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: AppTypography.subheadline.copyWith(color: secondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Severity badge — for medical status indicators.
///
/// Variants: critical, warning, moderate, info, mild, neutral
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;
  final bool compact;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _variantColors(variant, context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 10 : 12, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.caption2.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeColors _variantColors(AppBadgeVariant v, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (v) {
      case AppBadgeVariant.critical:
        return _BadgeColors(
          background: isDark ? const Color(0x33DC2626) : AppColors.dangerContainer,
          foreground: isDark ? const Color(0xFFF87171) : AppColors.danger,
          border: Colors.transparent,
        );
      case AppBadgeVariant.warning:
        return _BadgeColors(
          background: isDark ? const Color(0x33EA580C) : AppColors.warningContainer,
          foreground: isDark ? const Color(0xFFFB923C) : AppColors.warning,
          border: Colors.transparent,
        );
      case AppBadgeVariant.moderate:
        return _BadgeColors(
          background: isDark ? const Color(0x33CA8A04) : const Color(0xFFFEF3C7),
          foreground: isDark ? const Color(0xFFFACC15) : const Color(0xFFA16207),
          border: Colors.transparent,
        );
      case AppBadgeVariant.info:
        return _BadgeColors(
          background: isDark ? const Color(0x332563EB) : AppColors.infoContainer,
          foreground: isDark ? const Color(0xFF60A5FA) : AppColors.info,
          border: Colors.transparent,
        );
      case AppBadgeVariant.mild:
        return _BadgeColors(
          background: isDark ? const Color(0x3316A34A) : AppColors.successContainer,
          foreground: isDark ? const Color(0xFF4ADE80) : AppColors.success,
          border: Colors.transparent,
        );
      case AppBadgeVariant.neutral:
        return _BadgeColors(
          background: AppColorsResolver.secondarySurface(context),
          foreground: AppColorsResolver.textSecondary(context),
          border: AppColorsResolver.separator(context),
        );
      case AppBadgeVariant.primary:
        final pc = AppColorsResolver.primaryContainer(context);
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return _BadgeColors(
          background: pc,
          foreground: isDarkMode ? AppColors.primaryLight : AppColors.primaryDark,
          border: Colors.transparent,
        );
    }
  }
}

enum AppBadgeVariant {
  critical,  // red — danger/severe
  warning,   // orange — caution
  moderate,  // yellow — moderate severity
  info,      // blue — informational
  mild,      // green — mild/success
  neutral,   // grey — default
  primary,   // teal — brand
}

class _BadgeColors {
  final Color background;
  final Color foreground;
  final Color border;
  const _BadgeColors({
    required this.background,
    required this.foreground,
    required this.border,
  });
}

/// Semantic chip — for tags, conditions, categories.
///
/// More flexible than [AppBadge] — supports filled/outlined styles.
class AppChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final AppChipStyle style;
  final VoidCallback? onTap;
  final bool selected;

  const AppChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.style = AppChipStyle.filled,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = color ?? AppColorsResolver.primary(context);
    Color bg, fg, border;

    switch (style) {
      case AppChipStyle.filled:
        bg = tint.withOpacity(selected ? 0.18 : 0.10);
        fg = tint;
        border = Colors.transparent;
        break;
      case AppChipStyle.outlined:
        bg = Colors.transparent;
        fg = tint;
        border = tint.withOpacity(0.3);
        break;
      case AppChipStyle.solid:
        bg = tint;
        fg = isDark ? Colors.black : Colors.white;
        border = Colors.transparent;
        break;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: AppTypography.caption2.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum AppChipStyle { filled, outlined, solid }

/// Unified search field with proper styling and clear button.
class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final Widget? suffix;
  final FocusNode? focusNode;

  const AppSearchBar({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.suffix,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final tertiaryColor = AppColorsResolver.textTertiary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, color: tertiaryColor, size: 20),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller != null && controller!.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close_rounded, color: tertiaryColor, size: 18),
                  onPressed: () {
                    controller?.clear();
                    onClear?.call();
                    onChanged?.call('');
                  },
                  tooltip: 'Очистить',
                  visualDensity: VisualDensity.compact,
                ),
              if (suffix != null) suffix!,
            ],
          ),
        ),
        style: AppTypography.body.copyWith(color: AppColorsResolver.textPrimary(context)),
      ),
    );
  }
}

/// Polished list tile — for drug/disease/protocol lists.
///
/// Apple-style inset grouped list with optional leading icon, trailing chevron.
class AppListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryColor = AppColorsResolver.textSecondary(context);
    final tertiaryColor = AppColorsResolver.textTertiary(context);

    return Material(
      color: backgroundColor ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.footnote.copyWith(color: secondaryColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              if (showChevron) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: tertiaryColor, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Metric display — large number with optional unit and label.
/// Used in dose calculator for the calculated volume.
class AppMetricCard extends StatelessWidget {
  final String value;
  final String? unit;
  final String? label;
  final IconData? icon;
  final Color? accentColor;
  final Widget? footer;

  const AppMetricCard({
    super.key,
    required this.value,
    this.unit,
    this.label,
    this.icon,
    this.accentColor,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryColor = AppColorsResolver.textSecondary(context);
    final accent = accentColor ?? AppColorsResolver.primary(context);

    return AppCard.elevated(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null || icon != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                ],
                if (label != null)
                  Expanded(
                    child: Text(
                      label!,
                      style: AppTypography.caption1.copyWith(
                        color: secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.metricLarge.copyWith(color: textColor),
              ),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Text(
                  unit!,
                  style: AppTypography.title3.copyWith(color: secondaryColor),
                ),
              ],
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.md),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Screen scaffold with consistent background and safe area.
class AppScreenScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool centerTitle;
  final Color? backgroundColor;

  const AppScreenScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.centerTitle = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColorsResolver.background(context),
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              centerTitle: centerTitle,
              actions: actions,
            ),
      body: SafeArea(
        child: body,
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
