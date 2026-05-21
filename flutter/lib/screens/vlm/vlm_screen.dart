import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/vlm_provider.dart';

/// Экран VLM — ветеринарное зрение (фото + AI анализ)
/// После загрузки фото автоматически анализирует и показывает результат
class VlmScreen extends StatefulWidget {
  const VlmScreen({super.key});

  @override
  State<VlmScreen> createState() => _VlmScreenState();
}

class _VlmScreenState extends State<VlmScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Str = base64Encode(bytes);
        if (mounted) {
          // setImage с autoAnalyze=true автоматически запустит анализ
          context.read<VlmProvider>().setImage(base64Str, path: image.path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VlmProvider>();

    // Автопереход на страницу результатов когда анализ завершён
    if (provider.hasResult && !provider.isAnalyzing) {
      // Показываем результат прямо на этом экране
      return _buildResultView(provider);
    }

    // Основной экран выбора фото
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.lg,
                AppSpacing.screenPadding,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VetEco Vision',
                    style: AppTypography.largeTitle.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GLM-4V + RAG — загрузите фото для диагностики',
                    style: AppTypography.subheadline.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Анализируем? Показываем лоадер
          if (provider.isAnalyzing)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        if (provider.imagePath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            child: Image.file(
                              File(provider.imagePath!),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Анализирую изображение...',
                          style: AppTypography.headline.copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _modeLabel(provider.mode),
                          style: AppTypography.footnote.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else ...[
            // Image preview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: _buildImageArea(provider),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

            // Analysis mode selector
            if (provider.hasImage)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  child: _buildModeSelector(provider),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

            // Action buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: _buildActionButtons(provider),
              ),
            ),
          ],

          // Info card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: _buildInfoCard(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  /// Страница результатов — автоматически показывается после анализа
  Widget _buildResultView(VlmProvider provider) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Результат анализа'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // TODO: Share result
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Фото пациента
          if (provider.imagePath != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: Image.file(
                    File(provider.imagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          // Модель и режим
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.smart_toy, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          provider.modelUsed,
                          style: AppTypography.caption2.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.systemBlue.withAlpha(15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      _modeLabel(provider.mode),
                      style: AppTypography.caption2.copyWith(color: AppColors.systemBlue),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Результат анализа (основной контент)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Анализ AI',
                            style: AppTypography.headline.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(5),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: SelectableText(
                          provider.analysisResult,
                          style: AppTypography.callout.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Дисклеймер
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(10),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(color: Colors.orange.withAlpha(30)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Это AI-ассистированный анализ, не ветеринарный диагноз. Обратитесь к лицензированному ветеринару.',
                        style: AppTypography.caption1.copyWith(color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Кнопки действий
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => provider.analyzeImage(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Повторный анализ'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: provider.reset,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: const Text('Новое фото'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildImageArea(VlmProvider provider) {
    return Card(
      child: Container(
        height: 260,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: provider.hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  if (provider.imagePath != null)
                    Image.file(
                      File(provider.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(true),
                    )
                  else
                    _buildImagePlaceholder(true),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: provider.reset,
                      ),
                    ),
                  ),
                ],
              )
            : _buildImagePlaceholder(false),
      ),
    );
  }

  Widget _buildImagePlaceholder(bool hasImage) {
    if (hasImage) {
      return Container(
        color: AppColors.secondarySurface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 48, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                'Фото загружено — анализ начнётся автоматически',
                style: AppTypography.headline.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppColors.secondarySurface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Загрузите фото',
              style: AppTypography.headline.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Кожа, уши, глаза, лапы — AI определит заболевание',
              style: AppTypography.footnote.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(VlmProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Режим анализа',
              style: AppTypography.headline.copyWith(color: AppColors.textPrimary),
            ),
            // Переключатель авто-анализа
            Row(
              children: [
                Text(
                  'Авто',
                  style: AppTypography.caption1.copyWith(color: AppColors.textSecondary),
                ),
                Switch(
                  value: provider.autoAnalyze,
                  onChanged: provider.setAutoAnalyze,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: VlmAnalysisMode.values.map((mode) {
            final isSelected = provider.mode == mode;
            final (icon, label) = _modeInfo(mode);
            return ChoiceChip(
              avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => provider.setMode(mode),
              selectedColor: AppColors.primary,
              labelStyle: AppTypography.footnote.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(VlmProvider provider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text('Галерея'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            label: const Text('Камера'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
          ),
        ),
        if (!provider.autoAnalyze) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: provider.hasImage && !provider.isAnalyzing
                  ? () => provider.analyzeImage()
                  : null,
              icon: const Icon(Icons.auto_fix_high, size: 20),
              label: const Text('Анализ'),
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
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.systemBlue),
                const SizedBox(width: 8),
                Text(
                  'О модели',
                  style: AppTypography.headline.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'GLM-4V Flash — Vision Language Model с поддержкой RAG. '
              'Анализирует фотографии кожных поражений, ушных инфекций, глазных '
              'патологий. Результаты дополняются контекстом из базы ветеринарных '
              'знаний (1409 чанков). Автоматический fallback на прямой GLM-4V '
              'если HF Space недоступен.',
              style: AppTypography.footnote.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String) _modeInfo(VlmAnalysisMode mode) {
    return switch (mode) {
      VlmAnalysisMode.diagnose => (Icons.local_hospital, 'Диагноз'),
      VlmAnalysisMode.describe => (Icons.description, 'Описание'),
      VlmAnalysisMode.severity => (Icons.speed, 'Тяжесть'),
      VlmAnalysisMode.treatment => (Icons.medication, 'Лечение'),
      VlmAnalysisMode.skin => (Icons.healing, 'Дерма'),
    };
  }

  String _modeLabel(VlmAnalysisMode mode) {
    return switch (mode) {
      VlmAnalysisMode.diagnose => 'Режим: Диагноз',
      VlmAnalysisMode.describe => 'Режим: Описание',
      VlmAnalysisMode.severity => 'Режим: Тяжесть',
      VlmAnalysisMode.treatment => 'Режим: Лечение',
      VlmAnalysisMode.skin => 'Режим: Дерматология',
    };
  }
}
