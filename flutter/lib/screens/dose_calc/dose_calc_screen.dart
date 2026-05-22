import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/vet_provider.dart';
import '../../models/drug_models.dart';
import '../../core/utils/voice_parser.dart';
import '../../widgets/shared/animal_grid.dart';
import '../../widgets/dose_calc/dose_result_card.dart';

/// Главный экран калькулятора дозировок
class DoseCalcScreen extends StatefulWidget {
  const DoseCalcScreen({super.key});

  @override
  State<DoseCalcScreen> createState() => _DoseCalcScreenState();
}

class _DoseCalcScreenState extends State<DoseCalcScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _weightController.dispose();
    _searchController.dispose();
    _weightFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VetProvider>();
    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryTextColor = AppColorsResolver.textSecondary(context);
    final tertiaryTextColor = AppColorsResolver.textTertiary(context);

    if (provider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              provider.statusMessage,
              style: AppTypography.subheadline.copyWith(color: secondaryTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColorsResolver.background(context),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeader(provider, textColor, secondaryTextColor),
          ),

          // Animal selector
          SliverToBoxAdapter(
            child: _buildAnimalSection(provider, textColor, tertiaryTextColor),
          ),

          // Search + Weight input
          SliverToBoxAdapter(
            child: _buildInputSection(provider, textColor, tertiaryTextColor),
          ),

          // Drug list or result
          if (provider.selectedCalcDrug != null || provider.selectedRegistryDrug != null)
            SliverToBoxAdapter(
              child: DoseResultCard(result: provider.result),
            )
          else if (provider.searchQuery.isNotEmpty)
            _buildSearchResults(provider, textColor, secondaryTextColor)
          else if (provider.selectedAnimal != null)
            _buildDrugList(provider, textColor, secondaryTextColor),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(VetProvider provider, Color textColor, Color secondaryTextColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Калькулятор',
            style: AppTypography.largeTitle.copyWith(color: textColor),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.statusMessage,
                  style: AppTypography.footnote.copyWith(color: secondaryTextColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalSection(VetProvider provider, Color textColor, Color tertiaryTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Выберите животное',
            style: AppTypography.headline.copyWith(color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Можно сказать голосом: "корова", "собака"...',
            style: AppTypography.footnote.copyWith(
              color: tertiaryTextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimalGrid(
            animals: provider.animals,
            selectedAnimal: provider.selectedAnimal,
            onAnimalSelected: (animal) {
              HapticHelper.selection();
              provider.selectAnimal(animal);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(VetProvider provider, Color textColor, Color tertiaryTextColor) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weight input
          if (provider.selectedAnimal != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Вес животного',
                  style: AppTypography.headline.copyWith(color: textColor),
                ),
                Text(
                  '${provider.selectedAnimal!.minWeight.toStringAsFixed(0)}-'
                  '${provider.selectedAnimal!.maxWeight.toStringAsFixed(0)} кг',
                  style: AppTypography.footnote.copyWith(color: tertiaryTextColor),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _weightController,
              focusNode: _weightFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Введите вес в кг',
                suffixText: 'кг',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic_outlined, color: AppColors.primary),
                  onPressed: () {
                    // TODO: Voice input
                  },
                  tooltip: 'Голосовой ввод веса',
                ),
              ),
              onChanged: (value) {
                final w = double.tryParse(value);
                if (w != null) provider.setWeight(w);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Drug search
          Text(
            'Препарат',
            style: AppTypography.headline.copyWith(color: textColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Поиск по названию или МНН...',
              prefixIcon: Icon(Icons.search, color: tertiaryTextColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: tertiaryTextColor),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  : null,
            ),
            onChanged: (value) => provider.setSearchQuery(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(VetProvider provider, Color textColor, Color secondaryTextColor) {
    final results = provider.searchResults;
    if (results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: Text(
              'Ничего не найдено',
              style: AppTypography.subheadline.copyWith(color: secondaryTextColor),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final drug = results[index];
          return _DrugListTile(
            drug: drug,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () {
              HapticHelper.light();
              provider.selectDrug(drug);
              _searchController.clear();
              FocusScope.of(context).unfocus();
            },
          );
        },
        childCount: results.length > 20 ? 20 : results.length,
      ),
    );
  }

  Widget _buildDrugList(VetProvider provider, Color textColor, Color secondaryTextColor) {
    final drugs = provider.availableDrugs;
    if (drugs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: Text(
              'Нет препаратов для ${provider.selectedAnimal?.name ?? "животного"}',
              style: AppTypography.subheadline.copyWith(color: secondaryTextColor),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final drug = drugs[index];
          return _DrugListTile(
            drug: drug,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () {
              HapticHelper.light();
              provider.selectDrug(drug);
              FocusScope.of(context).unfocus();
            },
          );
        },
        childCount: drugs.length > 30 ? 30 : drugs.length,
      ),
    );
  }
}

/// Tile for drug list item (Apple HIG style)
class _DrugListTile extends StatelessWidget {
  final dynamic drug;
  final VoidCallback onTap;
  final Color textColor;
  final Color secondaryTextColor;

  const _DrugListTile({
    required this.drug,
    required this.onTap,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final String name;
    final String subtitle;
    final String? category;

    if (drug is CalcDrug) {
      name = drug.name;
      subtitle = '${drug.inn} • ${drug.form}';
      category = drug.category;
    } else if (drug is RegistryDrug) {
      name = drug.tradeName;
      subtitle = '${drug.inn} • ${drug.form}';
      category = drug.pharmacologicalGroup;
    } else {
      name = 'Неизвестно';
      subtitle = '';
      category = null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: 2,
      ),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.headline.copyWith(
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.footnote.copyWith(
                          color: secondaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category != null && category!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            category!,
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: secondaryTextColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
