import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../../core/widgets/app_components.dart';
import '../../models/drug_models.dart';

/// Карточка результата расчёта дозы — Apple Health-style with vet teal accent.
class DoseResultCard extends StatelessWidget {
  final DoseResult result;

  const DoseResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.hasResult) return const SizedBox.shrink();

    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryTextColor = AppColorsResolver.textSecondary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main result card
          AppCard.elevated(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drug name + status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.drugName,
                            style: AppTypography.title3.copyWith(color: textColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (result.drugForm.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              result.drugForm,
                              style: AppTypography.footnote.copyWith(color: secondaryTextColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (result.hasDosage && !result.hasError) ...[
                      const SizedBox(width: 8),
                      const AppBadge(
                        label: 'Дозировка доступна',
                        variant: AppBadgeVariant.primary,
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Main dose display
                if (result.hasError)
                  _buildErrorSection(context)
                else if (result.isFixedDose)
                  _buildFixedDoseSection(context)
                else if (result.hasDosage && result.volume > 0)
                  _buildCalculatedDoseSection(context, secondaryTextColor)
                else
                  _buildNoDoseSection(context),

                // Info rows
                if (result.method.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoRow(
                    context,
                    Icons.medication_outlined,
                    'Путь введения',
                    result.method,
                  ),
                ],
                if (result.frequency.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    context,
                    Icons.schedule_outlined,
                    'Частота',
                    result.frequency,
                  ),
                ],
                if (result.courseDays.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    context,
                    Icons.calendar_today_outlined,
                    'Курс',
                    result.courseDays,
                  ),
                ],
                if (result.withdrawalDays > 0) ...[
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    context,
                    Icons.timer_outlined,
                    'Срок ожидания',
                    '${result.withdrawalDays} дн.',
                    valueColor: AppColors.warning,
                  ),
                ],
              ],
            ),
          ),

          // Contraindications
          if (result.hasContraindications) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildWarningsCard(
              context,
              icon: Icons.warning_amber_rounded,
              color: AppColors.danger,
              title: 'Противопоказания',
              items: result.contraindications,
            ),
          ],

          // Side effects
          if (result.hasSideEffects) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildWarningsCard(
              context,
              icon: Icons.info_outline_rounded,
              color: AppColors.warning,
              title: 'Побочные эффекты',
              items: result.sideEffects,
            ),
          ],

          // Note
          if (result.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard.tinted(
              tintColor: AppColorsResolver.tertiarySurface(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_outlined, size: 16, color: secondaryTextColor),
                      const SizedBox(width: 6),
                      Text(
                        'Примечание',
                        style: AppTypography.footnote.copyWith(
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.note,
                    style: AppTypography.footnote.copyWith(color: secondaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalculatedDoseSection(BuildContext context, Color secondary) {
    final primary = AppColorsResolver.primary(context);
    final primaryContainer = AppColorsResolver.primaryContainer(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Разовая доза',
            style: AppTypography.caption1.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                result.formattedVolume.split(' ').first,
                style: AppTypography.metricLarge.copyWith(color: primary),
              ),
              const SizedBox(width: 6),
              Text(
                result.unit,
                style: AppTypography.title3.copyWith(color: primary.withValues(alpha: 0.8)),
              ),
            ],
          ),
          if (result.hasDoseRange) ...[
            const SizedBox(height: 6),
            Text(
              'Диапазон: ${result.doseMin}-${result.doseMax} ${result.doseUnit}',
              style: AppTypography.caption1.copyWith(color: primary.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixedDoseSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.infoContainer,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Фиксированная доза',
            style: AppTypography.caption1.copyWith(
              color: AppColors.info,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.fixedDoseText,
            style: AppTypography.title2.copyWith(color: AppColors.info),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDoseSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Дозировка не найдена в базе. Проверьте инструкцию.',
              style: AppTypography.subheadline.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerContainer,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.error,
              style: AppTypography.subheadline.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final secondary = AppColorsResolver.textSecondary(context);
    final textColor = AppColorsResolver.textPrimary(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: secondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.footnote.copyWith(color: secondary),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTypography.footnote.copyWith(
              color: valueColor ?? textColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningsCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required List<String> items,
  }) {
    final textColor = AppColorsResolver.textPrimary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark
        ? color.withValues(alpha: 0.18)
        : _lightContainerFor(color);

    return AppCard(
      backgroundColor: containerColor,
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.headline.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: AppTypography.footnote.copyWith(color: color)),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTypography.footnote.copyWith(color: textColor),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _lightContainerFor(Color c) {
    // Approximate container colors for semantic hues
    if (c == AppColors.danger) return AppColors.dangerContainer;
    if (c == AppColors.warning) return AppColors.warningContainer;
    if (c == AppColors.success) return AppColors.successContainer;
    if (c == AppColors.info) return AppColors.infoContainer;
    return c.withValues(alpha: 0.08);
  }
}
