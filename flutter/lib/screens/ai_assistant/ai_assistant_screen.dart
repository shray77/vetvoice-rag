import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/ai_provider.dart';
import '../../providers/vlm_provider.dart';
import '../../models/drug_models.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

/// Экран AI-хаба: Чат (RAG) + VLM (Зрение) с табами
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header with tabs
          Container(
            color: surfaceColor,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.md,
                      AppSpacing.screenPadding,
                      0,
                    ),
                    child: Text(
                      'VetEco AI',
                      style: AppTypography.largeTitle.copyWith(color: textColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    child: Text(
                      'Диагностика, поиск, анализ',
                      style: AppTypography.subheadline.copyWith(color: secondaryTextColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TabBar(
                    controller: _tabController,
                    labelColor: primaryColor,
                    unselectedLabelColor: secondaryTextColor,
                    indicatorColor: primaryColor,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: AppTypography.headline,
                    unselectedLabelStyle: AppTypography.subheadline,
                    tabs: const [
                      Tab(text: 'Чат RAG'),
                      Tab(text: 'Зрение VLM'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(primaryColor, surfaceColor, bgColor, textColor, secondaryTextColor, isDark),
                _buildVlmTab(primaryColor, surfaceColor, bgColor, textColor, secondaryTextColor, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: Чат RAG
  // ==========================================
  Widget _buildChatTab(Color primaryColor, Color surfaceColor, Color bgColor,
      Color textColor, Color secondaryTextColor, bool isDark) {
    final provider = context.watch<AiProvider>();

    return Column(
      children: [
        // Messages
        Expanded(
          child: provider.messages.isEmpty
              ? _buildChatEmptyState(primaryColor, secondaryTextColor)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  itemCount: provider.messages.length + (provider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.messages.length) {
                      return _buildTypingIndicator(surfaceColor, secondaryTextColor);
                    }
                    return _buildMessageBubble(
                      provider.messages[index],
                      primaryColor,
                      surfaceColor,
                      textColor,
                      isDark,
                    );
                  },
                ),
        ),

        // Error
        if (provider.error.isNotEmpty)
          Container(
            color: AppColors.error.withAlpha(10),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.error,
                    style: AppTypography.caption1.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),

        // Input bar
        _buildChatInputBar(provider, primaryColor, surfaceColor, bgColor),
      ],
    );
  }

  Widget _buildChatEmptyState(Color primaryColor, Color secondaryTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ветеринарный AI-ассистент',
              style: AppTypography.title3.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Задайте вопрос о дозировках, лечении, диагнозах или взаимодействиях препаратов',
              style: AppTypography.subheadline.copyWith(color: secondaryTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickChip('Дозировка энрофлоксацина для собак', primaryColor),
                _quickChip('Взаимодействие фторхинолонов', primaryColor),
                _quickChip('Лечение лептоспироза у КРС', primaryColor),
                _quickChip('Противопоказания при беременности', primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(String text, Color primaryColor) {
    return ActionChip(
      label: Text(
        text,
        style: AppTypography.caption1.copyWith(color: primaryColor),
      ),
      backgroundColor: primaryColor.withAlpha(10),
      side: BorderSide(color: primaryColor, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
      onPressed: () {
        _chatController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, Color primaryColor,
      Color surfaceColor, Color textColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: message.isUser ? primaryColor : surfaceColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.large),
              topRight: const Radius.circular(AppRadius.large),
              bottomLeft: message.isUser
                  ? const Radius.circular(AppRadius.large)
                  : const Radius.circular(4),
              bottomRight: message.isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(AppRadius.large),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: SelectableText(
            message.content,
            style: AppTypography.subheadline.copyWith(
              color: message.isUser ? Colors.white : textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(Color surfaceColor, Color secondaryTextColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary.withAlpha(100)),
              ),
              const SizedBox(width: 8),
              Text(
                'Думаю...',
                style: AppTypography.caption1.copyWith(color: secondaryTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatInputBar(AiProvider provider, Color primaryColor,
      Color surfaceColor, Color bgColor) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                decoration: InputDecoration(
                  hintText: 'Спросите о ветеринарии...',
                  filled: true,
                  fillColor: bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !provider.isLoading,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: provider.isLoading ? AppColors.textTertiary : primaryColor,
              child: IconButton(
                icon: Icon(
                  provider.isLoading ? Icons.hourglass_empty : Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: provider.isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    context.read<AiProvider>().sendMessage(text);
    _chatController.clear();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================
  // TAB 2: VLM Зрение
  // ==========================================
  Widget _buildVlmTab(Color primaryColor, Color surfaceColor, Color bgColor,
      Color textColor, Color secondaryTextColor, bool isDark) {
    final provider = context.watch<VlmProvider>();

    // Если есть результат — показать его
    if (provider.hasResult && !provider.isAnalyzing) {
      return _buildVlmResultView(provider, primaryColor, surfaceColor, bgColor, textColor, secondaryTextColor, isDark);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image area
          _buildVlmImageArea(provider, primaryColor, surfaceColor, secondaryTextColor, isDark),

          const SizedBox(height: AppSpacing.md),

          // Mode selector
          if (provider.hasImage) ...[
            _buildVlmModeSelector(provider, primaryColor, textColor, secondaryTextColor),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Action buttons
          _buildVlmActionButtons(provider, primaryColor),

          const SizedBox(height: AppSpacing.lg),

          // Analyzing indicator
          if (provider.isAnalyzing)
            Card(
              color: surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    if (provider.imagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        child: Image.file(
                          File(provider.imagePath!),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Анализирую изображение...',
                      style: AppTypography.headline.copyWith(color: textColor),
                    ),
                  ],
                ),
              ),
            ),

          // Error
          if (provider.error.isNotEmpty) ...[
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
                      provider.error,
                      style: AppTypography.footnote.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Info
          const SizedBox(height: AppSpacing.lg),
          Card(
            color: surfaceColor,
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
                        style: AppTypography.headline.copyWith(color: textColor),
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
                    style: AppTypography.footnote.copyWith(color: secondaryTextColor),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildVlmImageArea(VlmProvider provider, Color primaryColor,
      Color surfaceColor, Color secondaryTextColor, bool isDark) {
    return Card(
      color: surfaceColor,
      child: Container(
        height: 240,
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
                      errorBuilder: (_, __, ___) => _buildVlmPlaceholder(true, primaryColor, surfaceColor, secondaryTextColor),
                    )
                  else
                    _buildVlmPlaceholder(true, primaryColor, surfaceColor, secondaryTextColor),
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
            : _buildVlmPlaceholder(false, primaryColor, surfaceColor, secondaryTextColor),
      ),
    );
  }

  Widget _buildVlmPlaceholder(bool hasImage, Color primaryColor,
      Color surfaceColor, Color secondaryTextColor) {
    final bgColor = hasImage ? surfaceColor : AppColors.secondarySurface;
    return Container(
      color: bgColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasImage ? Icons.check_circle : Icons.add_photo_alternate_outlined,
              size: 48,
              color: hasImage ? primaryColor : AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              hasImage ? 'Фото загружено — анализ начнётся автоматически' : 'Загрузите фото',
              style: AppTypography.headline.copyWith(
                color: hasImage ? primaryColor : secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVlmModeSelector(VlmProvider provider, Color primaryColor,
      Color textColor, Color secondaryTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Режим анализа',
              style: AppTypography.headline.copyWith(color: textColor),
            ),
            Row(
              children: [
                Text('Авто', style: AppTypography.caption1.copyWith(color: secondaryTextColor)),
                Switch(
                  value: provider.autoAnalyze,
                  onChanged: provider.setAutoAnalyze,
                  activeColor: primaryColor,
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
              avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : secondaryTextColor),
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => provider.setMode(mode),
              selectedColor: primaryColor,
              labelStyle: AppTypography.footnote.copyWith(
                color: isSelected ? Colors.white : secondaryTextColor,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVlmActionButtons(VlmProvider provider, Color primaryColor) {
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
                backgroundColor: primaryColor,
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

  /// Страница результатов VLM
  Widget _buildVlmResultView(VlmProvider provider, Color primaryColor,
      Color surfaceColor, Color bgColor, Color textColor,
      Color secondaryTextColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Фото пациента
          if (provider.imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: Image.file(
                File(provider.imagePath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          const SizedBox(height: AppSpacing.sm),

          // Модель и режим
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.smart_toy, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      provider.modelUsed,
                      style: AppTypography.caption2.copyWith(color: primaryColor),
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

          const SizedBox(height: AppSpacing.md),

          // Результат
          Card(
            color: surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Анализ AI', style: AppTypography.headline.copyWith(color: textColor)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(5),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: SelectableText(
                      provider.analysisResult,
                      style: AppTypography.callout.copyWith(color: textColor, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Дисклеймер
          Container(
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

          const SizedBox(height: AppSpacing.md),

          // Кнопки
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => provider.analyzeImage(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Повторный анализ'),
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
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

          const SizedBox(height: 100),
        ],
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
      VlmAnalysisMode.diagnose => 'Диагноз',
      VlmAnalysisMode.describe => 'Описание',
      VlmAnalysisMode.severity => 'Тяжесть',
      VlmAnalysisMode.treatment => 'Лечение',
      VlmAnalysisMode.skin => 'Дерматология',
    };
  }
}
