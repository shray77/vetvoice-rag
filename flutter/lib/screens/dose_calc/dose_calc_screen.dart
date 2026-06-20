import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../../core/utils/voice_parser.dart';
import '../../core/widgets/app_components.dart';
import '../../providers/vet_provider.dart';
import '../../models/drug_models.dart';
import '../../widgets/shared/animal_grid.dart';
import '../../widgets/dose_calc/dose_result_card.dart';

/// Главный экран калькулятора дозировок — Apple Health-style.
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
  bool _searchHasText = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final has = _searchController.text.isNotEmpty;
      if (has != _searchHasText) {
        setState(() => _searchHasText = has);
      }
    });
  }

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

    if (provider.isLoading) {
      return AppLoadingState(message: provider.statusMessage);
    }

    return Scaffold(
      backgroundColor: AppColorsResolver.background(context),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // Header with status
          SliverToBoxAdapter(child: _buildHeader(provider)),

          // Animal selector
          SliverToBoxAdapter(child: _buildAnimalSection(provider)),

          // Search bar (always visible)
          SliverToBoxAdapter(
            child: AppSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Поиск препарата или МНН…',
              onChanged: (v) => provider.setSearchQuery(v),
            ),
          ),

          // Weight input (only when animal selected)
          if (provider.selectedAnimal != null)
            SliverToBoxAdapter(child: _buildWeightSection(provider)),

          // Result / drug list / empty
          if (provider.selectedCalcDrug != null ||
              provider.selectedRegistryDrug != null)
            SliverToBoxAdapter(child: DoseResultCard(result: provider.result))
          else if (provider.searchQuery.isNotEmpty)
            _buildSearchResults(provider)
          else if (provider.selectedAnimal != null)
            _buildDrugList(provider)
          else
            SliverToBoxAdapter(
              child: AppEmptyState(
                icon: Icons.pets_rounded,
                title: 'Выберите животное',
                subtitle: 'Сначала укажите вид животного, затем препарат для расчёта дозы.',
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildHeader(VetProvider provider) {
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
            style: AppTypography.largeTitle.copyWith(
              color: AppColorsResolver.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.statusMessage,
                  style: AppTypography.footnote.copyWith(
                    color: AppColorsResolver.textSecondary(context),
                  ),
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

  Widget _buildAnimalSection(VetProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Животное',
          subtitle: 'Выберите вид — можно голосом: «корова», «собака»…',
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: AnimalGrid(
            animals: provider.animals,
            selectedAnimal: provider.selectedAnimal,
            onAnimalSelected: (animal) {
              HapticHelper.selection();
              provider.selectAnimal(animal);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeightSection(VetProvider provider) {
    final textColor = AppColorsResolver.textPrimary(context);
    final tertiary = AppColorsResolver.textTertiary(context);
    final a = provider.selectedAnimal!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Вес животного',
                style: AppTypography.sectionLabel.copyWith(color: tertiary),
              ),
              Text(
                '${a.minWeight.toStringAsFixed(0)}-${a.maxWeight > 100 ? a.maxWeight.toStringAsFixed(0) : a.maxWeight.toStringAsFixed(1)} кг',
                style: AppTypography.caption1.copyWith(color: tertiary),
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
              hintStyle: AppTypography.body.copyWith(
                color: AppColorsResolver.textTertiary(context),
              ),
              suffixText: 'кг',
              suffixStyle: AppTypography.body.copyWith(color: tertiary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic_none_rounded, color: AppColors.primary),
                onPressed: () {
                  // TODO: Voice input
                  HapticHelper.light();
                },
                tooltip: 'Голосовой ввод веса',
              ),
            ),
            style: AppTypography.body.copyWith(color: textColor),
            onChanged: (value) {
              final w = double.tryParse(value);
              if (w != null) provider.setWeight(w);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(VetProvider provider) {
    final results = provider.searchResults;
    if (results.isEmpty) {
      return const SliverToBoxAdapter(
        child: AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Ничего не найдено',
          subtitle: 'Попробуйте изменить запрос или выбрать другое животное.',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final drug = results[index];
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: 3,
            ),
            child: _DrugListTile(
              drug: drug,
              onTap: () {
                HapticHelper.light();
                provider.selectDrug(drug);
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
            ),
          );
        },
        childCount: results.length > 20 ? 20 : results.length,
      ),
    );
  }

  Widget _buildDrugList(VetProvider provider) {
    final drugs = provider.availableDrugs;
    if (drugs.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          icon: Icons.medication_outlined,
          title: 'Нет препаратов для ${provider.selectedAnimal?.name ?? 'животного'}',
          subtitle: 'Используйте поиск, чтобы найти препарат по названию или МНН.',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final drug = drugs[index];
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: 3,
            ),
            child: _DrugListTile(
              drug: drug,
              onTap: () {
                HapticHelper.light();
                provider.selectDrug(drug);
                FocusScope.of(context).unfocus();
              },
            ),
          );
        },
        childCount: drugs.length > 30 ? 30 : drugs.length,
      ),
    );
  }
}

/// Tile for drug list item — polished Apple Health-style.
class _DrugListTile extends StatelessWidget {
  final dynamic drug;
  final VoidCallback onTap;

  const _DrugListTile({required this.drug, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondary = AppColorsResolver.textSecondary(context);
    final primary = AppColorsResolver.primary(context);

    final String name;
    final String subtitle;
    final String? category;

    if (drug is CalcDrug) {
      name = (drug as CalcDrug).name;
      subtitle = '${(drug as CalcDrug).inn} • ${(drug as CalcDrug).form}';
      category = (drug as CalcDrug).category;
    } else if (drug is RegistryDrug) {
      name = (drug as RegistryDrug).tradeName;
      subtitle = '${(drug as RegistryDrug).inn} • ${(drug as RegistryDrug).form}';
      category = (drug as RegistryDrug).pharmacologicalGroup;
    } else {
      name = 'Неизвестно';
      subtitle = '';
      category = null;
    }

    return AppCard.standard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.body.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.footnote.copyWith(color: secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category != null && category.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  AppChip(
                    label: category,
                    color: primary,
                    style: AppChipStyle.filled,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColorsResolver.textTertiary(context),
            size: 20,
          ),
        ],
      ),
    );
  }
}
