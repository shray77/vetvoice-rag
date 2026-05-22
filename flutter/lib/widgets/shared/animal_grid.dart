import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../../models/drug_models.dart';

/// Сетка выбора животного (Apple HIG style)
class AnimalGrid extends StatelessWidget {
  final List<Animal> animals;
  final Animal? selectedAnimal;
  final ValueChanged<Animal> onAnimalSelected;

  const AnimalGrid({
    super.key,
    required this.animals,
    this.selectedAnimal,
    required this.onAnimalSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: animals.length,
      itemBuilder: (context, index) {
        final animal = animals[index];
        final isSelected = selectedAnimal?.id == animal.id;

        return GestureDetector(
          onTap: () => onAnimalSelected(animal),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withAlpha(15)
                  : AppColorsResolver.surface(context),
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.separator.withAlpha(100),
                width: isSelected ? 2 : 0.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  animal.icon,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 4),
                Text(
                  animal.name,
                  style: AppTypography.caption1.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (animal.minWeight > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${animal.minWeight.toStringAsFixed(0)}-'
                    '${animal.maxWeight > 100 ? animal.maxWeight.toStringAsFixed(0) : animal.maxWeight.toStringAsFixed(1)} кг',
                    style: AppTypography.caption2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
