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

/// Главный экран калькулятора дозировок — Apple Health-style
/// с onboarding-флоу: пошаговое ведение пользователя за руку.
///
/// Шаги:
///   1. Выбери животное
///   2. Укажи вес
///   3. Найди препарат
///   4. Получи результат
///
/// На каждом шаге автоматически скроллит к активной секции
/// и подсвечивает её пульсирующей рамкой.
class DoseCalcScreen extends StatefulWidget {
  const DoseCalcScreen({super.key});

  @override
  State<DoseCalcScreen> createState() => _DoseCalcScreenState();
}

class _DoseCalcScreenState extends State<DoseCalcScreen>
    with TickerProviderStateMixin {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchHasText = false;

  // ─── Walkthrough machinery ────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _animalKey = GlobalKey();
  final GlobalKey _weightKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _resultKey = GlobalKey();

  /// Пульсирующая подсветка активной секции.
  late final AnimationController _pulseController;
  int _previousStep = 1;

  /// Текущий шаг выводится из состояния провайдера.
  int _currentStep(VetProvider p) {
    if (p.selectedCalcDrug != null || p.selectedRegistryDrug != null) return 4;
    if (p.searchQuery.isNotEmpty) return 3;
    if (p.selectedAnimal != null && p.weight > 0) return 3;
    if (p.selectedAnimal != null) return 2;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseController.repeat(reverse: true);
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
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Плавно скроллит к указанной секции.
  void _scrollToKey(GlobalKey key, {double alignment = -0.1}) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: AppCurves.decelerate,
        alignment: alignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  /// Подсветка рамки для активной секции.
  Border? _highlightBorder(int sectionStep, int currentStep) {
    if (sectionStep != currentStep) return null;
    final primary = AppColorsResolver.primary(context);
    // Анимированная прозрачность рамки — пульс
    final t = _pulseController.value;
    final alpha = 0.4 + 0.5 * t; // 0.4..0.9
    return Border.all(color: primary.withValues(alpha: alpha), width: 2);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VetProvider>();

    if (provider.isLoading) {
      return AppLoadingState(message: provider.statusMessage);
    }

    final step = _currentStep(provider);

    // Реагируем на смену шага
    if (step != _previousStep) {
      final targetKey = switch (step) {
        1 => _animalKey,
        2 => _weightKey,
        3 => _searchKey,
        4 => _resultKey,
        _ => null,
      };
      if (targetKey != null) {
        _scrollToKey(targetKey);
      }
      // Авто-фокус на поле ввода при переходе к шагу
      if (step == 2 && provider.weight <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _weightFocusNode.requestFocus();
        });
      } else if (step == 3 && !_searchHasText) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchFocusNode.requestFocus();
        });
      }
      _previousStep = step;
    }

    return Scaffold(
      backgroundColor: AppColorsResolver.background(context),
      body: CustomScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // Header + step indicator
          SliverToBoxAdapter(child: _buildHeader(provider)),
          SliverToBoxAdapter(child: _buildStepIndicator(step)),

          // Шаг 1: Animal selector
          SliverToBoxAdapter(
            child: _HighlightBox(
              key: _animalKey,
              border: _highlightBorder(1, step),
              child: _buildAnimalSection(provider),
            ),
          ),

          // Шаг 2: Weight (only when animal selected)
          if (provider.selectedAnimal != null)
            SliverToBoxAdapter(
              child: _HighlightBox(
                key: _weightKey,
                border: _highlightBorder(2, step),
                child: _buildWeightSection(provider),
              ),
            ),

          // Шаг 3: Search bar
          SliverToBoxAdapter(
            child: _HighlightBox(
              key: _searchKey,
              border: _highlightBorder(3, step),
              child: AppSearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: provider.selectedAnimal == null
                    ? 'Сначала выберите животное ↑'
                    : 'Поиск препарата или МНН…',
                onChanged: (v) => provider.setSearchQuery(v),
              ),
            ),
          ),

          // Шаг 4: Result / drug list / empty
          if (provider.selectedCalcDrug != null ||
              provider.selectedRegistryDrug != null)
            SliverToBoxAdapter(
              child: _HighlightBox(
                key: _resultKey,
                border: _highlightBorder(4, step),
                child: DoseResultCard(result: provider.result),
              ),
            )
          else if (provider.searchQuery.isNotEmpty)
            _buildSearchResults(provider)
          else if (provider.selectedAnimal != null && provider.weight > 0)
            _buildDrugList(provider)
          else if (provider.selectedAnimal != null)
            SliverToBoxAdapter(
              child: _buildWeightHint(),
            )
          else
            SliverToBoxAdapter(
              child: AppEmptyState(
                icon: Icons.pets_rounded,
                title: 'Выберите животное',
                subtitle: 'Начните с выбора вида — калькулятор проведёт вас по шагам.',
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Step indicator (1 → 2 → 3 → 4)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStepIndicator(int currentStep) {
    final primary = AppColorsResolver.primary(context);
    final tertiary = AppColorsResolver.textTertiary(context);

    const steps = [
      (1, 'Животное', Icons.pets_rounded),
      (2, 'Вес', Icons.scale_rounded),
      (3, 'Препарат', Icons.medication_rounded),
      (4, 'Результат', Icons.check_circle_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _stepDot(steps[i].$1, steps[i].$2, steps[i].$3, currentStep, primary, tertiary),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: steps[i].$1 < currentStep
                        ? primary.withValues(alpha: 0.4)
                        : tertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stepDot(
    int step,
    String label,
    IconData icon,
    int currentStep,
    Color primary,
    Color tertiary,
  ) {
    final isDone = step < currentStep;
    final isActive = step == currentStep;
    final color = isDone || isActive ? primary : tertiary;
    final textColor = AppColorsResolver.textPrimary(context);

    return Tooltip(
      message: 'Шаг $step: $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 36 : 28,
            height: isActive ? 36 : 28,
            decoration: BoxDecoration(
              color: isDone
                  ? primary
                  : isActive
                      ? primary.withValues(alpha: 0.12)
                      : AppColorsResolver.tertiarySurface(context),
              shape: BoxShape.circle,
              border: isActive
                  ? Border.all(color: primary, width: 2)
                  : null,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : icon,
              size: isActive ? 18 : 14,
              color: isDone
                  ? Colors.white
                  : isActive
                      ? primary
                      : tertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption2.copyWith(
              color: isActive ? textColor : tertiary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Sections
  // ═══════════════════════════════════════════════════════════════════

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
          subtitle: 'Выберите вид — калькулятор продолжит автоматически',
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

  Widget _buildWeightHint() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: AppCard.tinted(
        tintColor: AppColorsResolver.primaryContainer(context),
        child: Row(
          children: [
            Icon(Icons.arrow_upward_rounded,
                color: AppColorsResolver.primary(context), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Укажите вес животного выше — калькулятор сам подберёт препараты',
                style: AppTypography.footnote.copyWith(
                  color: AppColorsResolver.primary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
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

/// Контейнер с опциональной подсветкой-рамкой для walkthrough.
/// Принимает GlobalKey через `key` (стандартный параметр Widget),
/// чтобы потом можно было сделать Scrollable.ensureVisible(key.currentContext).
class _HighlightBox extends StatelessWidget {
  final Border? border;
  final Widget child;

  const _HighlightBox({super.key, required this.border, required this.child});

  @override
  Widget build(BuildContext context) {
    if (border == null) return child;
    return Container(
      decoration: BoxDecoration(
        border: border,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: child,
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
