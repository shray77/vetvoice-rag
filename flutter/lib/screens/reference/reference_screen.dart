import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/vet_provider.dart';
import '../../models/drug_models.dart';

/// Экран «Справочник» — агрегирует все 18 источников данных приложения.
///
/// Пользователь может:
///   - видеть статистику по всем БД
///   - искать болезни, протоколы, взаимодействия, побочки, антидоты, периоды ожидания
///   - листать все 169 болезней, 154 протокола, 73 взаимодействия, 16 экстренных протоколов,
///     17 антидотов, 20 побочных эффектов, 5 формул жидкости, 5 коррекций дозы, 7 эталонных
///     дозировок, 27 эталонных дозировок из справочника
class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _searchCtrl.addListener(() {
      if (_searchCtrl.text != _searchQuery) {
        setState(() => _searchQuery = _searchCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with title
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.lg,
                AppSpacing.screenPadding,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Справочник',
                    style: AppTypography.largeTitle.copyWith(color: textColor),
                  ),
                  const Spacer(),
                  Consumer<VetProvider>(
                    builder: (context, vet, _) {
                      final stats = vet.dbStats;
                      final total = stats.values.fold(0, (a, b) => a + b);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.primaryLight : AppColors.primary).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$total записей',
                          style: AppTypography.caption.copyWith(
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Поиск по болезням, протоколам, препаратам…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: surfaceColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Tab bar — scrollable for 8 tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Болезни'),
                Tab(text: 'Протоколы'),
                Tab(text: 'Взаимодействия'),
                Tab(text: 'Побочные'),
                Tab(text: 'Антидоты'),
                Tab(text: 'Экстренные'),
                Tab(text: 'Жидкости'),
                Tab(text: 'Статистика'),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DiseasesTab(query: _searchQuery),
                  _ProtocolsTab(query: _searchQuery),
                  _InteractionsTab(query: _searchQuery),
                  _SideEffectsTab(query: _searchQuery),
                  _AntidotesTab(query: _searchQuery),
                  _EmergencyTab(query: _searchQuery),
                  _FluidTab(query: _searchQuery),
                  const _StatsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 1: Болезни (contagious + non-contagious) — 169 entries
// ═══════════════════════════════════════════════════════════════════════

class _DiseasesTab extends StatelessWidget {
  final String query;
  const _DiseasesTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Consumer<VetProvider>(
      builder: (context, vet, _) {
        final diseases = vet.searchDiseases(query);
        if (diseases.isEmpty) {
          return _EmptyState(query: query);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: diseases.length,
          itemBuilder: (context, i) {
            final d = diseases[i];
            return Card(
              color: surfaceColor,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                title: Text(
                  d.name,
                  style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Chip(d.code, color: AppColors.systemBlue),
                        _Chip(d.categoryRu, color: d.isContagious ? AppColors.systemRed : AppColors.systemGreen),
                        ...d.animals.map((a) => _Chip(a, color: AppColors.systemIndigo)),
                      ],
                    ),
                  ],
                ),
                trailing: Text(
                  '#${d.id}',
                  style: AppTypography.caption.copyWith(color: secondary),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 2: Протоколы лечения (contagious + non-contagious) — 154 entries
// ═══════════════════════════════════════════════════════════════════════

class _ProtocolsTab extends StatelessWidget {
  final String query;
  const _ProtocolsTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Consumer<VetProvider>(
      builder: (context, vet, _) {
        var protocols = vet.allProtocols;
        if (query.isNotEmpty) {
          final lower = query.toLowerCase();
          protocols = protocols.where((p) =>
            p.diagnosis.toLowerCase().contains(lower) ||
            p.code.toLowerCase().contains(lower)
          ).toList();
        }

        if (protocols.isEmpty) {
          return _EmptyState(query: query);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: protocols.length,
          itemBuilder: (context, i) {
            final p = protocols[i];
            return Card(
              color: surfaceColor,
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  p.diagnosis,
                  style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Chip(p.code, color: AppColors.systemBlue),
                        _Chip(p.categoryName.isEmpty ? p.category : p.categoryName, color: AppColors.systemIndigo),
                        _Chip('Тяжесть: ${p.severity}', color: _severityColor(p.severity)),
                        ...p.species.take(3).map((s) => _Chip(s, color: AppColors.systemTeal)),
                      ],
                    ),
                    if (p.pathogenType.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          p.pathogenType,
                          style: AppTypography.caption.copyWith(color: secondary),
                        ),
                      ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final tier in p.sortedTiers) ...[
                          Text(
                            _tierLabel(tier.key),
                            style: AppTypography.headline.copyWith(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          for (final drug in tier.value.drugs) ...[
                            _DrugLine(drug: drug, textColor: textColor, secondary: secondary),
                            const SizedBox(height: 4),
                          ],
                          if (tier.value.notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Text(
                                'Заметки: ${tier.value.notes}',
                                style: AppTypography.caption.copyWith(color: secondary),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                        if (p.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Общие заметки: ${p.notes}',
                              style: AppTypography.caption.copyWith(color: secondary),
                            ),
                          ),
                        if (p.warnings.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.systemRed.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ВНИМАНИЕ: ${p.warnings}',
                                style: AppTypography.caption.copyWith(color: AppColors.systemRed),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _tierLabel(String key) {
    switch (key) {
      case 'primary':    return 'Основное лечение';
      case 'secondary':  return 'Дополнительное';
      case 'supportive': return 'Поддерживающее';
      case 'symptomatic':return 'Симптоматическое';
      default:           return key[0].toUpperCase() + key.substring(1);
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':     return AppColors.systemRed;
      case 'moderate':   return AppColors.systemOrange;
      case 'mild':       return AppColors.systemGreen;
      default:           return AppColors.systemGrey;
    }
  }
}

class _DrugLine extends StatelessWidget {
  final ProtocolDrug drug;
  final Color textColor;
  final Color secondary;
  const _DrugLine({required this.drug, required this.textColor, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            drug.name + (drug.inn.isNotEmpty ? ' (${drug.inn})' : ''),
            style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (drug.dose.isNotEmpty || drug.route.isNotEmpty || drug.frequency.isNotEmpty)
            Text(
              [
                if (drug.dose.isNotEmpty) 'Доза: ${drug.dose}',
                if (drug.route.isNotEmpty) 'Путь: ${drug.route}',
                if (drug.frequency.isNotEmpty) 'Кратность: ${drug.frequency}',
                if (drug.duration.isNotEmpty) 'Длительность: ${drug.duration}',
              ].join(' • '),
              style: AppTypography.caption.copyWith(color: secondary, fontSize: 11),
            ),
          if (drug.waitingPeriod.isNotEmpty)
            Text(
              'Период ожидания: ${drug.waitingPeriod}',
              style: AppTypography.caption.copyWith(color: AppColors.systemOrange, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 3: Взаимодействия — 73 entries
// ═══════════════════════════════════════════════════════════════════════

class _InteractionsTab extends StatelessWidget {
  final String query;
  const _InteractionsTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Consumer<VetProvider>(
      builder: (context, vet, _) {
        var list = vet.interactions;
        if (query.isNotEmpty) {
          final lower = query.toLowerCase();
          list = list.where((i) =>
            i.drug1.toLowerCase().contains(lower) ||
            i.drug2.toLowerCase().contains(lower) ||
            i.effect.toLowerCase().contains(lower)
          ).toList();
        }

        if (list.isEmpty) return _EmptyState(query: query);

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final it = list[i];
            return Card(
              color: surfaceColor,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${it.drug1} + ${it.drug2}',
                            style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                        _Chip(it.severityRu, color: _sevColor(it.severity)),
                      ],
                    ),
                    if (it.effect.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Эффект: ${it.effect}', style: AppTypography.caption.copyWith(color: secondary)),
                    ],
                    if (it.consequence.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Последствие: ${it.consequence}', style: AppTypography.caption.copyWith(color: AppColors.systemRed)),
                    ],
                    if (it.recommendation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Рекомендация: ${it.recommendation}', style: AppTypography.caption.copyWith(color: textColor)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _sevColor(String sev) {
    switch (sev.toLowerCase()) {
      case 'critical': return AppColors.systemRed;
      case 'warning':  return AppColors.systemOrange;
      case 'moderate': return AppColors.systemYellow;
      case 'info':     return AppColors.systemBlue;
      default:         return AppColors.systemGrey;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 4: Побочные эффекты — 20 entries
// ═══════════════════════════════════════════════════════════════════════

class _SideEffectsTab extends StatelessWidget {
  final String query;
  const _SideEffectsTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Consumer<VetProvider>(
      builder: (context, vet, _) {
        var list = vet.sideEffects;
        if (query.isNotEmpty) {
          final lower = query.toLowerCase();
          list = list.where((e) =>
            e.drugName.toLowerCase().contains(lower) ||
            e.effects.any((f) => f.effect.toLowerCase().contains(lower))
          ).toList();
        }

        if (list.isEmpty) return _EmptyState(query: query);

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final entry = list[i];
            return Card(
              color: surfaceColor,
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  entry.drugName,
                  style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${entry.effects.length} эффект(ов)',
                  style: AppTypography.caption.copyWith(color: secondary),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in entry.effects) ...[
                          _SideEffectLine(item: e, textColor: textColor, secondary: secondary),
                          const SizedBox(height: 6),
                        ],
                        if (entry.monitoring.isNotEmpty)
                          Text(
                            'Мониторинг: ${entry.monitoring}',
                            style: AppTypography.caption.copyWith(color: AppColors.systemBlue),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SideEffectLine extends StatelessWidget {
  final SideEffectItem item;
  final Color textColor;
  final Color secondary;
  const _SideEffectLine({required this.item, required this.textColor, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.systemOrange.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.effect,
            style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (item.age.isNotEmpty || item.dose.isNotEmpty || item.condition.isNotEmpty || item.frequency.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (item.age.isNotEmpty) 'Возраст: ${item.age}',
                  if (item.dose.isNotEmpty) 'Доза: ${item.dose}',
                  if (item.condition.isNotEmpty) 'Условие: ${item.condition}',
                  if (item.frequency.isNotEmpty) 'Частота: ${item.frequency}',
                ].join(' • '),
                style: AppTypography.caption.copyWith(color: secondary, fontSize: 11),
              ),
            ),
          if (item.action.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Действие: ${item.action}',
                style: AppTypography.caption.copyWith(color: textColor, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 5: Антидоты — 17 entries
// ═══════════════════════════════════════════════════════════════════════

class _AntidotesTab extends StatelessWidget {
  final String query;
  const _AntidotesTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Consumer<VetProvider>(
      builder: (context, vet, _) {
        var list = vet.antidotes;
        if (query.isNotEmpty) {
          final lower = query.toLowerCase();
          list = list.where((a) =>
            a.toxin.toLowerCase().contains(lower) ||
            a.antidote.toLowerCase().contains(lower) ||
            a.commonNames.any((n) => n.toLowerCase().contains(lower))
          ).toList();
        }

        if (list.isEmpty) return _EmptyState(query: query);

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final a = list[i];
            return Card(
              color: surfaceColor,
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  a.toxin,
                  style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Антидот: ${a.antidote}',
                  style: AppTypography.caption.copyWith(color: AppColors.systemGreen),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a.commonNames.isNotEmpty)
                          _LabeledRow(label: 'Синонимы', value: a.commonNames.join(', '), textColor: textColor, secondary: secondary),
                        if (a.symptoms.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _LabeledRow(label: 'Симптомы', value: a.symptoms.join(', '), textColor: textColor, secondary: secondary),
                        ],
                        if (a.antidoteDose.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _LabeledRow(label: 'Доза антидота', value: a.antidoteDose, textColor: textColor, secondary: secondary),
                        ],
                        if (a.alternative.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _LabeledRow(label: 'Альтернатива', value: a.alternative, textColor: textColor, secondary: secondary),
                        ],
                        if (a.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.systemRed.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ВНИМАНИЕ: ${a.notes}',
                              style: AppTypography.caption.copyWith(color: AppColors.systemRed),
                            ),
                          ),
                        ],
                        if (a.prognosis.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _LabeledRow(label: 'Прогноз', value: a.prognosis, textColor: textColor, secondary: secondary),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 6: Экстренные протоколы — 16 entries
// ═══════════════════════════════════════════════════════════════════════

class _EmergencyTab extends StatelessWidget {
  final String query;
  const _EmergencyTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Consumer<VetProvider>(
      builder: (context, vet, _) {
        var list = vet.emergencyProtocols;
        if (query.isNotEmpty) {
          final lower = query.toLowerCase();
          list = list.where((e) =>
            e.name.toLowerCase().contains(lower) ||
            e.indication.toLowerCase().contains(lower)
          ).toList();
        }

        if (list.isEmpty) return _EmptyState(query: query);

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final e = list[i];
            return Card(
              color: surfaceColor,
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.systemRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.name,
                        style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  e.indication,
                  style: AppTypography.caption.copyWith(color: secondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Алгоритм:', style: AppTypography.headline.copyWith(color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        for (final step in e.algorithm) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${step.step}. ${step.action}',
                                  style: AppTypography.body.copyWith(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                if (step.detail.isNotEmpty)
                                  Text(
                                    step.detail,
                                    style: AppTypography.caption.copyWith(color: secondary, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (e.drugs.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Препараты:', style: AppTypography.headline.copyWith(color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          for (final d in e.drugs) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 4),
                              child: Text(
                                '${d.drug}: ${d.dose} ${d.route} — ${d.frequency}',
                                style: AppTypography.caption.copyWith(color: textColor, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                        if (e.monitoring.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Мониторинг: ${e.monitoring.join(', ')}',
                              style: AppTypography.caption.copyWith(color: AppColors.systemBlue, fontSize: 12)),
                        ],
                        if (e.termination.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.systemRed.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Критерии прекращения: ${e.termination}',
                              style: AppTypography.caption.copyWith(color: AppColors.systemRed, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 7: Жидкостная терапия + Коррекция дозы + Периоды ожидания
// ═══════════════════════════════════════════════════════════════════════

class _FluidTab extends StatelessWidget {
  final String query;
  const _FluidTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Consumer<VetProvider>(
      builder: (context, vet, _) {
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            // Fluid formulas
            Text('Формулы жидкостной терапии', style: AppTypography.headline.copyWith(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final f in vet.fluidFormulas) ...[
              Card(
                color: surfaceColor,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name, style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Формула: ${f.formula}', style: AppTypography.caption.copyWith(color: secondary)),
                      if (f.example.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Пример: ${f.example}', style: AppTypography.caption.copyWith(color: AppColors.systemBlue)),
                      ],
                      if (f.dehydrationLevels.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: f.dehydrationLevels.entries.map((e) =>
                            _Chip('${e.key}: ${e.value.percent}% — ${e.value.signs}', color: AppColors.systemTeal)
                          ).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Dose adjustments
            Text('Коррекция дозы', style: AppTypography.headline.copyWith(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final entry in vet.doseAdjustments.entries) ...[
              Card(
                color: surfaceColor,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adjustmentLabel(entry.key),
                        style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600),
                      ),
                      if (entry.value.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Описание: ${entry.value.description}', style: AppTypography.caption.copyWith(color: secondary)),
                      ],
                      if (entry.value.generalRule.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Правило: ${entry.value.generalRule}', style: AppTypography.caption.copyWith(color: textColor)),
                      ],
                      if (entry.value.issues.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Проблемы: ${entry.value.issues.join(', ')}', style: AppTypography.caption.copyWith(color: AppColors.systemOrange, fontSize: 11)),
                      ],
                      if (entry.value.drugsCareful.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Осторожно с: ${entry.value.drugsCareful.join(', ')}', style: AppTypography.caption.copyWith(color: AppColors.systemRed, fontSize: 11)),
                      ],
                      if (entry.value.monitoring.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Мониторинг: ${entry.value.monitoring.join(', ')}', style: AppTypography.caption.copyWith(color: AppColors.systemBlue, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Withdrawals
            Text('Периоды ожидания', style: AppTypography.headline.copyWith(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final w in vet.withdrawals) ...[
              Card(
                color: surfaceColor,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.inn, style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Table(
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        children: [
                          TableRow(
                            children: [
                              Padding(padding: EdgeInsets.only(right: 12), child: Text('Животное', style: AppTypography.caption.copyWith(color: secondary, fontWeight: FontWeight.w600))),
                              Padding(padding: EdgeInsets.only(right: 12), child: Text('Мясо', style: AppTypography.caption.copyWith(color: secondary, fontWeight: FontWeight.w600))),
                              Padding(padding: EdgeInsets.only(right: 12), child: Text('Молоко', style: AppTypography.caption.copyWith(color: secondary, fontWeight: FontWeight.w600))),
                              Padding(padding: EdgeInsets.only(right: 12), child: Text('Яйца', style: AppTypography.caption.copyWith(color: secondary, fontWeight: FontWeight.w600))),
                            ],
                          ),
                          for (final e in w.products.entries)
                            TableRow(
                              children: [
                                Padding(padding: EdgeInsets.only(top: 2, right: 12), child: Text(e.key, style: AppTypography.caption.copyWith(color: textColor))),
                                Padding(padding: EdgeInsets.only(top: 2, right: 12), child: Text(e.value.meatLabel, style: AppTypography.caption.copyWith(color: textColor))),
                                Padding(padding: EdgeInsets.only(top: 2, right: 12), child: Text(e.value.milkLabel, style: AppTypography.caption.copyWith(color: textColor))),
                                Padding(padding: EdgeInsets.only(top: 2, right: 12), child: Text(e.value.eggsLabel, style: AppTypography.caption.copyWith(color: textColor))),
                              ],
                            ),
                        ],
                      ),
                      if (w.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Заметки: ${w.notes}', style: AppTypography.caption.copyWith(color: AppColors.systemOrange)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _adjustmentLabel(String key) {
    switch (key) {
      case 'age_adjustments':       return 'Возрастная коррекция';
      case 'renal_adjustment':      return 'Почечная недостаточность';
      case 'hepatic_adjustment':    return 'Печёночная недостаточность';
      case 'cardiac_adjustment':    return 'Сердечная недостаточность';
      case 'pregnancy_lactation':   return 'Беременность и лактация';
      default:                      return key;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 8: Статистика
// ═══════════════════════════════════════════════════════════════════════

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Consumer<VetProvider>(
      builder: (context, vet, _) {
        final stats = vet.dbStats;
        final entries = <_StatRow>[
          _StatRow('Калькулятор препаратов', stats['calcDrugs'] ?? 0, 'drugs_calc.json', AppColors.systemBlue),
          _StatRow('Реестр препаратов', stats['registryDrugs'] ?? 0, 'drugs_registry.json', AppColors.systemIndigo),
          _StatRow('Инфекционные болезни', stats['diseases'] ?? 0, 'diseases.json', AppColors.systemRed),
          _StatRow('Незаразные болезни', stats['nonContagiousDiseases'] ?? 0, 'non_contagious_diseases.json', AppColors.systemGreen),
          _StatRow('Протоколы лечения', stats['treatmentProtocols'] ?? 0, 'treatment_protocols.json', AppColors.systemOrange),
          _StatRow('Незаразные протоколы', stats['nonContagiousProtocols'] ?? 0, 'non_contagious_protocols.json', AppColors.systemTeal),
          _StatRow('Взаимодействия', stats['interactions'] ?? 0, 'drug_interactions.json', AppColors.systemYellow),
          _StatRow('Побочные эффекты', stats['sideEffects'] ?? 0, 'side_effects.json', AppColors.systemPink),
          _StatRow('Антидоты', stats['antidotes'] ?? 0, 'antidotes.json', AppColors.systemGreen),
          _StatRow('Экстренные протоколы', stats['emergencyProtocols'] ?? 0, 'emergency_protocols.json', AppColors.systemRed),
          _StatRow('Формулы жидкостной терапии', stats['fluidFormulas'] ?? 0, 'fluid_therapy.json', AppColors.systemCyan),
          _StatRow('Периоды ожидания', stats['withdrawals'] ?? 0, 'withdrawal_by_product.json', AppColors.systemBrown),
          _StatRow('Коррекции дозы', stats['doseAdjustments'] ?? 0, 'dose_adjustments.json', AppColors.systemPurple),
          _StatRow('Эталонные дозировки (verified)', stats['verifiedDosages'] ?? 0, 'verified_dosages.json', AppColors.systemBlue),
          _StatRow('Эталонные дозировки (reference)', stats['correctDosages'] ?? 0, 'correct_dosages_reference.json', AppColors.systemBlue),
          _StatRow('База дозировок', stats['dosageDatabase'] ?? 0, 'dosage_database.json', AppColors.systemGrey),
          _StatRow('Неофициальные протоколы', stats['unofficialProtocols'] ?? 0, 'unofficial_protocols.json', AppColors.systemGrey),
        ];

        final total = entries.fold(0, (a, e) => a + e.count);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Card(
              color: surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Всего записей', style: AppTypography.caption.copyWith(color: secondary)),
                    const SizedBox(height: 4),
                    Text(
                      '$total',
                      style: AppTypography.largeTitle.copyWith(color: textColor, fontSize: 36, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'из 17 источников данных',
                      style: AppTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final e in entries) ...[
              Card(
                color: surfaceColor,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: e.color.withAlpha(30),
                    child: Text('${e.count}', style: TextStyle(color: e.color, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(e.title, style: AppTypography.body.copyWith(color: textColor, fontWeight: FontWeight.w500)),
                  subtitle: Text(e.source, style: AppTypography.caption.copyWith(color: secondary, fontSize: 11)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              color: surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RAG Knowledge Base', style: AppTypography.headline.copyWith(color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Локальный FAISS-индекс: 12 024 чанков, 8 000-мерный TF-IDF.\n'
                      'Источники: те же 17 JSON-файлов + advanced/*\n'
                      'Поиск: hybrid (TF-IDF + keyword boost + bilingual EN/RU translation)',
                      style: AppTypography.caption.copyWith(color: secondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

class _StatRow {
  final String title;
  final int count;
  final String source;
  final Color color;
  const _StatRow(this.title, this.count, this.source, this.color);
}

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.systemGrey),
            const SizedBox(height: 12),
            Text(
              query.isEmpty ? 'Нет данных' : 'Ничего не найдено по запросу «$query»',
              style: AppTypography.body.copyWith(color: secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color secondary;
  const _LabeledRow({required this.label, required this.value, required this.textColor, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTypography.caption.copyWith(fontSize: 12),
        children: [
          TextSpan(text: '$label: ', style: TextStyle(color: secondary, fontWeight: FontWeight.w600)),
          TextSpan(text: value, style: TextStyle(color: textColor)),
        ],
      ),
    );
  }
}
