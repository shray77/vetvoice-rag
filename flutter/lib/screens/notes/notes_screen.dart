import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../../core/utils/voice_parser.dart';
import '../../core/widgets/app_components.dart';
import '../../providers/notes_provider.dart';
import '../../models/vet_record_model.dart';

/// Экран структурированных ветеринарных записей.
/// Голос → AI Parse → SOAP Card → Save
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsResolver.background(context),
      body: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Новая запись'),
              Tab(text: 'Архив'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNewRecordTab(),
                _buildArchiveTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
            'Записи',
            style: AppTypography.largeTitle.copyWith(
              color: AppColorsResolver.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Надиктуйте — AI заполнит карточку',
            style: AppTypography.subheadline.copyWith(
              color: AppColorsResolver.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // НОВАЯ ЗАПИСЬ
  // ==========================================

  Widget _buildNewRecordTab() {
    final provider = context.watch<NotesProvider>();
    if (provider.currentRecord != null) {
      return _buildRecordPreview(provider);
    }
    return _buildDictationInput(provider);
  }

  Widget _buildDictationInput(NotesProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVoiceButton(provider),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Или введите текст вручную',
            style: AppTypography.subheadline.copyWith(
              color: AppColorsResolver.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _textController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Корова 500 кг, холмогорская, температура 39.8, '
                  'снижен аппетит, хромает на правую заднюю, подозрение на '
                  'травматический ретикулит. Назначен энрофлоксацин 5 мг/кг '
                  'внутримышечно 5 дней, новокаиновая блокада...',
              hintStyle: AppTypography.body.copyWith(
                color: AppColorsResolver.textTertiary(context),
                height: 1.4,
              ),
            ),
            style: AppTypography.body.copyWith(
              color: AppColorsResolver.textPrimary(context),
            ),
            onChanged: (text) => provider.updateDictationText(text),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.dictationText.isNotEmpty)
            FilledButton.icon(
              onPressed: provider.isParsing ? null : () => _parseDictation(provider),
              icon: provider.isParsing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high_rounded, size: 20),
              label: Text(provider.isParsing ? 'Обработка…' : 'Структурировать'),
            ),
          if (provider.parseError.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              backgroundColor: AppColors.dangerContainer,
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.parseError,
                      style: AppTypography.footnote.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _buildExampleCard(),
        ],
      ),
    );
  }

  Widget _buildVoiceButton(NotesProvider provider) {
    final isListening = provider.isListening;
    final primary = AppColorsResolver.primary(context);
    final textColor = AppColorsResolver.textPrimary(context);
    final tertiary = AppColorsResolver.textTertiary(context);

    return GestureDetector(
      onTap: () => _toggleVoiceInput(provider),
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: AppCurves.decelerate,
        height: 180,
        decoration: BoxDecoration(
          color: isListening
              ? AppColorsResolver.primaryContainer(context)
              : AppColorsResolver.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isListening ? primary : AppColorsResolver.separator(context),
            width: isListening ? 2 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isListening ? 1.15 : 1.0,
              duration: AppDurations.fast,
              curve: AppCurves.spring,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isListening ? primary : primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: isListening
                      ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4)]
                      : null,
                ),
                child: Icon(
                  isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: isListening ? Colors.white : primary,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isListening ? 'Слушаю…' : 'Нажмите для диктовки',
              style: AppTypography.headline.copyWith(
                color: isListening ? primary : textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isListening
                  ? 'Говорите чётко, называйте препараты и дозы'
                  : 'Голосом или текстом',
              style: AppTypography.footnote.copyWith(color: tertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleCard() {
    return AppCard.tinted(
      tintColor: AppColors.infoContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.info),
              const SizedBox(width: 6),
              Text(
                'Пример диктовки',
                style: AppTypography.headline.copyWith(color: AppColors.info),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '«Собака, ротвейлер, 35 килограмм, 5 лет, кобель. Жалоба: '
            'хромота на правую переднюю лапу три дня. Аппетит снижен. '
            'Температура 39.2. При осмотре: болезненность в области '
            'правого локтевого сустава, отёк. Диагноз: травматический '
            'артрит. Назначен мелоксикам 0.1 мг/кг внутрь 7 дней, '
            'хондроитин 15 мг/кг. Повторный осмотр через неделю.»',
            style: AppTypography.callout.copyWith(
              color: AppColorsResolver.textSecondary(context),
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SOAP КАРТОЧКА
  // ==========================================

  Widget _buildRecordPreview(NotesProvider provider) {
    final record = provider.currentRecord!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompletenessBar(record),
          const SizedBox(height: AppSpacing.md),

          // Animal info
          _buildSectionCard(
            icon: Icons.pets_rounded,
            title: 'Животное',
            color: AppColorsResolver.primary(context),
            children: [
              _buildInfoRow('Вид', record.animalType),
              if (record.animalBreed != null) _buildInfoRow('Порода', record.animalBreed!),
              if (record.animalWeight != null) _buildInfoRow('Вес', '${record.animalWeight} кг'),
              if (record.animalAge != null) _buildInfoRow('Возраст', '${record.animalAge} ${record.animalAgeUnit ?? 'лет'}'),
              if (record.animalGender != null) _buildInfoRow('Пол', record.animalGender!),
              if (record.animalId != null) _buildInfoRow('Идентификация', record.animalId!),
            ],
          ),

          if (record.complaint != null || record.anamnesis != null)
            _buildSectionCard(
              icon: Icons.record_voice_over_rounded,
              title: 'S — Субъективно',
              color: AppColors.info,
              children: [
                if (record.complaint != null) _buildInfoRow('Жалоба', record.complaint!),
                if (record.anamnesis != null) _buildInfoRow('Анамнез', record.anamnesis!),
              ],
            ),

          if (record.temperature != null || record.heartRate != null ||
              record.respiratoryRate != null || record.physicalExam != null ||
              record.mucousMembranes != null || record.lymphNodes != null ||
              record.skinCoat != null)
            _buildSectionCard(
              icon: Icons.assignment_rounded,
              title: 'O — Объективно',
              color: AppColors.warning,
              children: [
                if (record.temperature != null) _buildInfoRow('Температура', '${record.temperature} °C'),
                if (record.heartRate != null) _buildInfoRow('ЧСС', '${record.heartRate} уд/мин'),
                if (record.respiratoryRate != null) _buildInfoRow('ЧДД', '${record.respiratoryRate} /мин'),
                if (record.physicalExam != null) _buildInfoRow('Осмотр', record.physicalExam!),
                if (record.mucousMembranes != null) _buildInfoRow('Слизистые', record.mucousMembranes!),
                if (record.lymphNodes != null) _buildInfoRow('Лимфоузлы', record.lymphNodes!),
                if (record.skinCoat != null) _buildInfoRow('Кожа/шерсть', record.skinCoat!),
              ],
            ),

          if (record.diagnosis != null || record.differentialDx != null)
            _buildSectionCard(
              icon: Icons.psychology_rounded,
              title: 'A — Оценка',
              color: AppColors.systemPurple,
              children: [
                if (record.diagnosis != null) _buildInfoRow('Диагноз', record.diagnosis!),
                if (record.differentialDx != null) _buildInfoRow('Дифф. диагноз', record.differentialDx!),
                if (record.diseaseSeverity != null) _buildInfoRow('Тяжесть', record.diseaseSeverity!),
              ],
            ),

          if (record.prescribedDrugs.isNotEmpty || record.procedures != null ||
              record.diet != null || record.followUp != null)
            _buildSectionCard(
              icon: Icons.medication_rounded,
              title: 'P — План',
              color: AppColors.danger,
              children: [
                if (record.prescribedDrugs.isNotEmpty) ...[
                  _buildInfoRow('Препараты', ''),
                  for (final drug in record.prescribedDrugs)
                    _buildDrugRow(drug),
                ],
                if (record.procedures != null) _buildInfoRow('Процедуры', record.procedures!),
                if (record.diet != null) _buildInfoRow('Содержание', record.diet!),
                if (record.followUp != null) _buildInfoRow('Контроль', record.followUp!),
              ],
            ),

          if (record.notes != null)
            _buildSectionCard(
              icon: Icons.note_rounded,
              title: 'Заметки',
              color: AppColorsResolver.textTertiary(context),
              children: [_buildInfoRow('Дополнительно', record.notes!)],
            ),

          if (record.rawDictation != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ExpansionTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              title: Text(
                'Оригинал диктовки',
                style: AppTypography.subheadline.copyWith(
                  color: AppColorsResolver.textSecondary(context),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    record.rawDictation!,
                    style: AppTypography.callout.copyWith(
                      color: AppColorsResolver.textTertiary(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => provider.discardCurrentRecord(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Заново'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _saveRecord(provider),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Сохранить'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCompletenessBar(VetRecord record) {
    final completeness = record.completeness;
    final percent = (completeness * 100).toInt();
    final color = completeness > 0.7
        ? AppColors.success
        : completeness > 0.4
            ? AppColors.warning
            : AppColors.danger;

    return AppCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Заполненность записи',
                style: AppTypography.subheadline.copyWith(
                  color: AppColorsResolver.textSecondary(context),
                ),
              ),
              Text(
                '$percent%',
                style: AppTypography.headline.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: completeness,
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard.standard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.card),
                  topRight: Radius.circular(AppRadius.card),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: AppTypography.headline.copyWith(color: color),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.footnote.copyWith(
                color: AppColorsResolver.textTertiary(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTypography.callout.copyWith(
                color: AppColorsResolver.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrugRow(PrescribedDrug drug) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard.tinted(
        tintColor: AppColors.dangerContainer,
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              drug.name,
              style: AppTypography.headline.copyWith(
                color: AppColorsResolver.textPrimary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              drug.shortDescription,
              style: AppTypography.footnote.copyWith(
                color: AppColorsResolver.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // АРХИВ
  // ==========================================

  Widget _buildArchiveTab() {
    final provider = context.watch<NotesProvider>();
    final records = provider.filteredRecords;

    if (records.isEmpty) {
      return AppEmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Записей пока нет',
        subtitle: 'Надиктуйте первую запись на вкладке «Новая запись»',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: AppSearchBar(
            controller: _searchController,
            hintText: 'Поиск по записям…',
            onChanged: (v) => provider.setSearchQuery(v),
            onClear: () => provider.setSearchQuery(''),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            itemCount: records.length,
            itemBuilder: (context, index) => _buildRecordListTile(records[index], provider),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordListTile(VetRecord record, NotesProvider provider) {
    final severityColor = record.diseaseSeverity == 'тяжёлая'
        ? AppColors.danger
        : record.diseaseSeverity == 'средняя'
            ? AppColors.warning
            : AppColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Dismissible(
        key: ValueKey(record.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.dangerContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
        ),
        onDismissed: (_) => provider.deleteRecord(record.id),
        child: AppCard.standard(
          onTap: () {
            HapticHelper.selection();
            provider.openRecord(record);
            _tabController.animateTo(0);
          },
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pets_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        record.animalType.isNotEmpty ? record.animalType : 'Не указано',
                        style: AppTypography.headline.copyWith(
                          color: AppColorsResolver.textPrimary(context),
                        ),
                      ),
                      if (record.animalWeight != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${record.animalWeight} кг',
                          style: AppTypography.footnote.copyWith(
                            color: AppColorsResolver.textSecondary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _fmtDate(record.createdAt),
                    style: AppTypography.caption1.copyWith(
                      color: AppColorsResolver.textTertiary(context),
                    ),
                  ),
                ],
              ),
              if (record.diagnosis != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (record.diseaseSeverity != null)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: severityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        record.diagnosis!,
                        style: AppTypography.callout.copyWith(
                          color: AppColorsResolver.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (record.prescribedDrugs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.medication_rounded, size: 14, color: AppColors.danger),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${record.prescribedDrugs.length} препарат(ов): '
                        '${record.prescribedDrugs.map((d) => d.name).take(3).join(", ")}',
                        style: AppTypography.caption1.copyWith(
                          color: AppColorsResolver.textTertiary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildStatusBadge(record.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: record.completeness,
                        minHeight: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          record.completeness > 0.7 ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(VetRecordStatus status) {
    final (label, variant) = switch (status) {
      VetRecordStatus.draft  => ('Черновик', AppBadgeVariant.neutral),
      VetRecordStatus.parsed => ('AI', AppBadgeVariant.info),
      VetRecordStatus.edited => ('Правки', AppBadgeVariant.primary),
      VetRecordStatus.saved  => ('Сохранено', AppBadgeVariant.mild),
    };
    return AppBadge(label: label, variant: variant);
  }

  // ==========================================
  // ACTIONS
  // ==========================================

  void _toggleVoiceInput(NotesProvider provider) {
    if (provider.isListening) {
      provider.setListening(false);
      if (provider.dictationText.isNotEmpty) {
        _parseDictation(provider);
      }
    } else {
      provider.setListening(true);
      HapticHelper.medium();
    }
  }

  Future<void> _parseDictation(NotesProvider provider) async {
    HapticHelper.medium();
    await provider.parseDictation();
  }

  Future<void> _saveRecord(NotesProvider provider) async {
    HapticHelper.heavy();
    await provider.saveCurrentRecord();
    _textController.clear();
    _tabController.animateTo(1);
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
