import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';

import '../../providers/notes_provider.dart';
import '../../models/vet_record_model.dart';

/// Экран структурированных ветеринарных записей
/// Голос → AI Parse → SOAP Card → Save
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsResolver.background(context),
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Tab bar
          Container(
            color: AppColorsResolver.surface(context),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: AppTypography.headline,
              unselectedLabelStyle: AppTypography.subheadline,
              tabs: const [
                Tab(text: 'Новая запись'),
                Tab(text: 'Архив'),
              ],
            ),
          ),

          // Content
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
    return Container(
      color: AppColorsResolver.surface(context),
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
            style: AppTypography.largeTitle.copyWith(color: AppColorsResolver.textPrimary(context)),
          ),
          const SizedBox(height: 4),
          Text(
            'Надиктуйте — AI заполнит карточку',
            style: AppTypography.subheadline.copyWith(color: AppColorsResolver.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // НОВАЯ ЗАПИСЬ — голос / текст → AI → карточка
  // ==========================================

  Widget _buildNewRecordTab() {
    final provider = context.watch<NotesProvider>();

    // Если есть распарсенная запись — показать карточку
    if (provider.currentRecord != null) {
      return _buildRecordPreview(provider);
    }

    // Иначе — экран диктовки
    return _buildDictationInput(provider);
  }

  /// Экран ввода диктовки (голос или текст)
  Widget _buildDictationInput(NotesProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Большая кнопка голосового ввода
          _buildVoiceButton(provider),

          const SizedBox(height: AppSpacing.lg),

          // Текстовое поле для диктовки
          Text(
            'Или введите текст вручную',
            style: AppTypography.subheadline.copyWith(color: AppColorsResolver.textSecondary(context)),
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
              hintStyle: AppTypography.callout.copyWith(color: AppColors.textPlaceholder),
              alignLabelWithHint: true,
            ),
            onChanged: (text) => provider.updateDictationText(text),
          ),

          const SizedBox(height: AppSpacing.md),

          // Кнопка парсинга
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
                  : const Icon(Icons.auto_fix_high, size: 20),
              label: Text(provider.isParsing ? 'Обработка...' : 'Структурировать'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
            ),

          // Ошибка парсинга
          if (provider.parseError.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(10),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.error.withAlpha(30)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.parseError,
                      style: AppTypography.footnote.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Пример диктовки
          const SizedBox(height: AppSpacing.xl),
          _buildExampleCard(),
        ],
      ),
    );
  }

  /// Большая кнопка голосового ввода (Apple HIG style)
  Widget _buildVoiceButton(NotesProvider provider) {
    final isListening = provider.isListening;

    return GestureDetector(
      onTap: () => _toggleVoiceInput(provider),
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: Curves.easeInOut,
        height: 160,
        decoration: BoxDecoration(
          color: isListening
              ? AppColors.primary.withAlpha(15)
              : AppColorsResolver.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isListening ? AppColors.primary : AppColors.separator,
            width: isListening ? 2 : 1,
          ),
          boxShadow: isListening
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(30),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mic icon with animation
            AnimatedScale(
              scale: isListening ? 1.15 : 1.0,
              duration: AppDurations.fast,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isListening ? AppColors.primary : AppColors.primary.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: isListening ? Colors.white : AppColors.primary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isListening ? 'Слушаю...' : 'Нажмите для диктовки',
              style: AppTypography.headline.copyWith(
                color: isListening ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isListening ? 'Говорите чётко, называйте препараты и дозы' : 'Голосом или текстом',
              style: AppTypography.footnote.copyWith(color: AppColorsResolver.textTertiary(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка с примером диктовки
  Widget _buildExampleCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.systemBlue.withAlpha(8),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.systemBlue.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.systemBlue),
              const SizedBox(width: 6),
              Text(
                'Пример диктовки',
                style: AppTypography.headline.copyWith(color: AppColors.systemBlue),
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
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Превью распарсенной записи (SOAP карточка)
  Widget _buildRecordPreview(NotesProvider provider) {
    final record = provider.currentRecord!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Completeness indicator
          _buildCompletenessBar(record),
          const SizedBox(height: AppSpacing.md),

          // Animal info card
          _buildSectionCard(
            icon: Icons.pets,
            title: 'Животное',
            color: AppColors.primary,
            children: [
              _buildInfoRow('Вид', record.animalType),
              if (record.animalBreed != null) _buildInfoRow('Порода', record.animalBreed!),
              if (record.animalWeight != null) _buildInfoRow('Вес', '${record.animalWeight} кг'),
              if (record.animalAge != null) _buildInfoRow('Возраст', '${record.animalAge} ${record.animalAgeUnit ?? 'лет'}'),
              if (record.animalGender != null) _buildInfoRow('Пол', record.animalGender!),
              if (record.animalId != null) _buildInfoRow('Идентификация', record.animalId!),
            ],
          ),

          // Subjective (S)
          if (record.complaint != null || record.anamnesis != null)
            _buildSectionCard(
              icon: Icons.record_voice_over,
              title: 'S — Субъективно',
              color: AppColors.systemBlue,
              children: [
                if (record.complaint != null) _buildInfoRow('Жалоба', record.complaint!),
                if (record.anamnesis != null) _buildInfoRow('Анамнез', record.anamnesis!),
              ],
            ),

          // Objective (O)
          if (record.temperature != null || record.heartRate != null ||
              record.respiratoryRate != null || record.physicalExam != null ||
              record.mucousMembranes != null || record.lymphNodes != null ||
              record.skinCoat != null)
            _buildSectionCard(
              icon: Icons.assignment,
              title: 'O — Объективно',
              color: AppColors.systemOrange,
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

          // Assessment (A)
          if (record.diagnosis != null || record.differentialDx != null)
            _buildSectionCard(
              icon: Icons.psychology,
              title: 'A — Оценка',
              color: AppColors.systemPurple,
              children: [
                if (record.diagnosis != null) _buildInfoRow('Диагноз', record.diagnosis!),
                if (record.differentialDx != null) _buildInfoRow('Дифф. диагноз', record.differentialDx!),
                if (record.diseaseSeverity != null) _buildInfoRow('Тяжесть', record.diseaseSeverity!),
              ],
            ),

          // Plan (P)
          if (record.prescribedDrugs.isNotEmpty || record.procedures != null ||
              record.diet != null || record.followUp != null)
            _buildSectionCard(
              icon: Icons.medication,
              title: 'P — План',
              color: AppColors.systemRed,
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

          // Notes
          if (record.notes != null)
            _buildSectionCard(
              icon: Icons.note,
              title: 'Заметки',
              color: AppColors.textTertiary,
              children: [
                _buildInfoRow('Дополнительно', record.notes!),
              ],
            ),

          // Raw dictation (collapsible)
          if (record.rawDictation != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ExpansionTile(
              backgroundColor: AppColorsResolver.surface(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              title: Text(
                'Оригинал диктовки',
                style: AppTypography.subheadline.copyWith(color: AppColorsResolver.textSecondary(context)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    record.rawDictation!,
                    style: AppTypography.callout.copyWith(
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => provider.discardCurrentRecord(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Заново'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _saveRecord(provider),
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('Сохранить'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  /// Бар заполненности записи
  Widget _buildCompletenessBar(VetRecord record) {
    final completeness = record.completeness;
    final percent = (completeness * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColorsResolver.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Заполненность записи',
                style: AppTypography.subheadline.copyWith(color: AppColorsResolver.textSecondary(context)),
              ),
              Text(
                '$percent%',
                style: AppTypography.headline.copyWith(
                  color: completeness > 0.7
                      ? AppColors.success
                      : completeness > 0.4
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: completeness,
              minHeight: 6,
              backgroundColor: AppColors.fillPrimary,
              valueColor: AlwaysStoppedAnimation<Color>(
                completeness > 0.7
                    ? AppColors.success
                    : completeness > 0.4
                        ? AppColors.warning
                        : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Секция SOAP карточки
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColorsResolver.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: color.withAlpha(8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.medium),
                  topRight: Radius.circular(AppRadius.medium),
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
            // Section content
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }

  /// Строка информации в карточке
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
              style: AppTypography.footnote.copyWith(color: AppColorsResolver.textTertiary(context)),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTypography.callout.copyWith(color: AppColorsResolver.textPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }

  /// Строка назначенного препарата
  Widget _buildDrugRow(PrescribedDrug drug) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.systemRed.withAlpha(6),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: AppColors.systemRed.withAlpha(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              drug.name,
              style: AppTypography.headline.copyWith(color: AppColorsResolver.textPrimary(context)),
            ),
            const SizedBox(height: 2),
            Text(
              drug.shortDescription,
              style: AppTypography.footnote.copyWith(color: AppColorsResolver.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // АРХИВ ЗАПИСЕЙ
  // ==========================================

  Widget _buildArchiveTab() {
    final provider = context.watch<NotesProvider>();
    final records = provider.filteredRecords;

    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Записей пока нет',
                style: AppTypography.title3.copyWith(color: AppColorsResolver.textPrimary(context)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Надиктуйте первую запись на вкладке «Новая запись»',
                style: AppTypography.subheadline.copyWith(color: AppColorsResolver.textSecondary(context)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Поиск по записям...',
              prefixIcon: const Icon(Icons.search, color: AppColorsResolver.textTertiary(context)),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColorsResolver.textTertiary(context)),
                      onPressed: () => provider.setSearchQuery(''),
                    )
                  : null,
              filled: true,
              fillColor: AppColorsResolver.surface(context),
            ),
            onChanged: (value) => provider.setSearchQuery(value),
          ),
        ),

        // Records list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            itemCount: records.length,
            itemBuilder: (context, index) {
              return _buildRecordListTile(records[index], provider);
            },
          ),
        ),
      ],
    );
  }

  /// Карточка записи в списке архива
  Widget _buildRecordListTile(VetRecord record, NotesProvider provider) {
    final severityColor = record.diseaseSeverity == 'тяжёлая'
        ? AppColors.error
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
            color: AppColors.error.withAlpha(15),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: const Icon(Icons.delete_outline, color: AppColors.error),
        ),
        onDismissed: (_) => provider.deleteRecord(record.id),
        child: Card(
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              provider.openRecord(record);
              _tabController.animateTo(0);
            },
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Animal + Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pets, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            record.animalType.isNotEmpty ? record.animalType : 'Не указано',
                            style: AppTypography.headline.copyWith(color: AppColorsResolver.textPrimary(context)),
                          ),
                          if (record.animalWeight != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${record.animalWeight} кг',
                              style: AppTypography.footnote.copyWith(color: AppColorsResolver.textSecondary(context)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _fmtDate(record.createdAt),
                        style: AppTypography.caption1.copyWith(color: AppColorsResolver.textTertiary(context)),
                      ),
                    ],
                  ),

                  // Row 2: Diagnosis
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
                            style: AppTypography.callout.copyWith(color: AppColorsResolver.textSecondary(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Row 3: Drugs count
                  if (record.prescribedDrugs.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.medication, size: 14, color: AppColors.systemRed),
                        const SizedBox(width: 4),
                        Text(
                          '${record.prescribedDrugs.length} препарат(ов): '
                          '${record.prescribedDrugs.map((d) => d.name).take(3).join(", ")}',
                          style: AppTypography.caption1.copyWith(color: AppColorsResolver.textTertiary(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],

                  // Status badge
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildStatusBadge(record.status),
                      const SizedBox(width: 8),
                      // Completeness mini bar
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          child: LinearProgressIndicator(
                            value: record.completeness,
                            minHeight: 3,
                            backgroundColor: AppColors.fillPrimary,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              record.completeness > 0.7
                                  ? AppColors.success
                                  : AppColors.warning,
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
        ),
      ),
    );
  }

  Widget _buildStatusBadge(VetRecordStatus status) {
    final (label, color) = switch (status) {
      VetRecordStatus.draft => ('Черновик', AppColors.textTertiary),
      VetRecordStatus.parsed => ('AI', AppColors.systemPurple),
      VetRecordStatus.edited => ('Правки', AppColors.systemBlue),
      VetRecordStatus.saved => ('Сохранено', AppColors.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTypography.caption2.copyWith(color: color),
      ),
    );
  }

  // ==========================================
  // ACTIONS
  // ==========================================

  void _toggleVoiceInput(NotesProvider provider) {
    // TODO: Подключить speech_to_text
    // Пока — toggle состояния для UI
    if (provider.isListening) {
      provider.setListening(false);
      // После остановки — автоматически парсим
      if (provider.dictationText.isNotEmpty) {
        _parseDictation(provider);
      }
    } else {
      provider.setListening(true);
      // TODO: Запустить SpeechRecognition
      // Временная заглушка — добавляем текст в поле
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _parseDictation(NotesProvider provider) async {
    HapticFeedback.mediumImpact();
    await provider.parseDictation();
  }

  Future<void> _saveRecord(NotesProvider provider) async {
    HapticFeedback.heavyImpact();
    await provider.saveCurrentRecord();
    _textController.clear();
    _tabController.animateTo(1); // Переключаемся на архив
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
