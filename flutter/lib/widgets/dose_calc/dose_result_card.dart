import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/drug_models.dart';

/// Карточка результата расчёта дозы (Apple HIG style)
class DoseResultCard extends StatelessWidget {
  final DoseResult result;

  const DoseResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.hasResult) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main result card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.large),
              side: result.hasError
                  ? const BorderSide(color: AppColors.error, width: 1)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drug name
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.drugName,
                          style: AppTypography.title3.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (result.hasDosage && !result.hasError)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'Дозировка доступна',
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (result.drugForm.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.drugForm,
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // Main dose display
                  if (result.hasError)
                    _buildErrorSection()
                  else if (result.isFixedDose)
                    _buildFixedDoseSection()
                  else if (result.hasDosage && result.volume > 0)
                    _buildCalculatedDoseSection()
                  else
                    _buildNoDoseSection(),

                  // Method & Frequency
                  if (result.method.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildInfoRow(
                      Icons.medication_outlined,
                      'Путь введения',
                      result.method,
                    ),
                  ],

                  if (result.frequency.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildInfoRow(
                      Icons.schedule_outlined,
                      'Частота',
                      result.frequency,
                    ),
                  ],

                  if (result.courseDays.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildInfoRow(
                      Icons.calendar_today_outlined,
                      'Курс',
                      result.courseDays,
                    ),
                  ],

                  if (result.withdrawalDays > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildInfoRow(
                      Icons.timer_outlined,
                      'Срок ожидания',
                      '${result.withdrawalDays} дней',
                      valueColor: AppColors.warning,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Contraindications
          if (result.hasContraindications) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildWarningsCard(
              icon: Icons.warning_amber_rounded,
              color: AppColors.error,
              title: 'Противопоказания',
              items: result.contraindications,
            ),
          ],

          // Side effects
          if (result.hasSideEffects) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildWarningsCard(
              icon: Icons.info_outline_rounded,
              color: AppColors.systemOrange,
              title: 'Побочные эффекты',
              items: result.sideEffects,
            ),
          ],

          // Note
          if (result.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.note_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Примечание',
                          style: AppTypography.footnote.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.note,
                      style: AppTypography.footnote.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalculatedDoseSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Разовая доза',
            style: AppTypography.footnote.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.formattedVolume,
            style: AppTypography.largeTitle.copyWith(
              color: AppColors.primary,
            ),
          ),
          if (result.hasDoseRange) ...[
            const SizedBox(height: 4),
            Text(
              'Диапазон: ${result.doseMin}-${result.doseMax} ${result.doseUnit}',
              style: AppTypography.caption1.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixedDoseSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.systemBlue.withAlpha(10),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Фиксированная доза',
            style: AppTypography.footnote.copyWith(
              color: AppColors.systemBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.fixedDoseText,
            style: AppTypography.title2.copyWith(color: AppColors.systemBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDoseSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.systemOrange.withAlpha(10),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.systemOrange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Дозировка не найдена в базе. Проверьте инструкцию.',
              style: AppTypography.subheadline.copyWith(
                color: AppColors.systemOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(10),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.error,
              style: AppTypography.subheadline.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTypography.footnote.copyWith(
              color: valueColor ?? AppColors.textPrimary,
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

  Widget _buildWarningsCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> items,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: BorderSide(color: color.withAlpha(80), width: 1),
      ),
      child: Padding(
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
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
