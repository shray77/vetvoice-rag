import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../../models/drug_models.dart';

/// Сетка выбора животного — Apple Health-style tiles with vet teal accent.
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
        childAspectRatio: 1.05,
      ),
      itemCount: animals.length,
      itemBuilder: (context, index) {
        final animal = animals[index];
        final isSelected = selectedAnimal?.id == animal.id;

        return _AnimalTile(
          animal: animal,
          isSelected: isSelected,
          onTap: () => onAnimalSelected(animal),
        );
      },
    );
  }
}

class _AnimalTile extends StatelessWidget {
  final Animal animal;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimalTile({
    required this.animal,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColorsResolver.primary(context);
    final primaryContainer = AppColorsResolver.primaryContainer(context);
    final textColor = AppColorsResolver.textPrimary(context);
    final tertiaryColor = AppColorsResolver.textTertiary(context);
    final surfaceColor = AppColorsResolver.surface(context);
    final separatorColor = AppColorsResolver.separator(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.decelerate,
          decoration: BoxDecoration(
            color: isSelected ? primaryContainer : surfaceColor,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(
              color: isSelected ? primaryColor : separatorColor,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.15)
                      : AppColorsResolver.tertiarySurface(context),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    animal.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                animal.name,
                style: AppTypography.caption1.copyWith(
                  color: isSelected ? primaryColor : textColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (animal.minWeight > 0) ...[
                const SizedBox(height: 1),
                Text(
                  _weightLabel(animal),
                  style: AppTypography.caption2.copyWith(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.8)
                        : tertiaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _weightLabel(Animal a) {
    if (a.maxWeight > 100) {
      return '${a.minWeight.toStringAsFixed(0)}-${a.maxWeight.toStringAsFixed(0)} кг';
    }
    return '${a.minWeight.toStringAsFixed(0)}-${a.maxWeight.toStringAsFixed(1)} кг';
  }
}
