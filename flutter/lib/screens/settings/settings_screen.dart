import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../../core/widgets/app_components.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vet_provider.dart';
import '../reference/reference_screen.dart';

/// Экран «Ещё» — Настройки + VetLearn + О приложении
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _glmModel = 'glm-4-flash';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Settings loaded from ThemeProvider
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryTextColor = AppColorsResolver.textSecondary(context);
    final tertiaryTextColor = AppColorsResolver.textTertiary(context);
    final surfaceColor = AppColorsResolver.surface(context);
    final bgColor = AppColorsResolver.background(context);
    final primaryColor = AppColorsResolver.primary(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
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
              child: Text(
                'Ещё',
                style: AppTypography.largeTitle.copyWith(color: textColor),
              ),
            ),
          ),

          // Quick access cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                children: [
                  _buildNavCard(
                    icon: Icons.school_rounded,
                    iconColor: AppColors.systemBlue,
                    title: 'VetLearn',
                    subtitle: 'Обучающая платформа для ветеринаров',
                    onTap: () => _openVetLearn(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNavCard(
                    icon: Icons.visibility_rounded,
                    iconColor: AppColors.systemPurple,
                    title: 'VLM Диагностика',
                    subtitle: 'Быстрый доступ к анализу изображений',
                    onTap: () {
                      // Switch to AI tab and then VLM sub-tab
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Consumer<VetProvider>(
                    builder: (context, vet, _) {
                      final stats = vet.dbStats;
                      final total = stats.values.fold(0, (a, b) => a + b);
                      return _buildNavCard(
                        icon: Icons.menu_book_rounded,
                        iconColor: AppColors.primary,
                        title: 'Справочник',
                        subtitle: 'Все базы: $total записей (болезни, протоколы, взаимодействия, антидоты…)',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReferenceScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Appearance section
          SliverToBoxAdapter(
            child: _buildSection(
              title: 'Оформление',
              icon: Icons.palette_outlined,
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return Column(
                      children: [
                        _buildThemeOption('system', 'Системная', Icons.brightness_auto_outlined, themeProvider),
                        _buildThemeOption('light', 'Светлая', Icons.light_mode_outlined, themeProvider),
                        _buildThemeOption('dark', 'Тёмная', Icons.dark_mode_outlined, themeProvider),
                        _buildThemeOption('night', 'Ночной дежурный', Icons.nights_stay_outlined, themeProvider),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // AI section
          SliverToBoxAdapter(
            child: _buildSection(
              title: 'AI',
              icon: Icons.smart_toy_outlined,
              children: [
                _buildNavigationTile(
                  title: 'Модель GLM',
                  subtitle: _glmModel,
                  onTap: () => _showModelPicker(primaryColor, surfaceColor, textColor),
                ),
                _buildNavigationTile(
                  title: 'RAG API',
                  subtitle: '${ApiConfig.hfSpaceUrl}${ApiConfig.ragApiPath}',
                  onTap: () {
                    // TODO: Configure RAG endpoint
                  },
                ),
              ],
            ),
          ),

          // About section
          SliverToBoxAdapter(
            child: _buildSection(
              title: 'О приложении',
              icon: Icons.info_outline,
              children: [
                _buildInfoTile('Версия', AppConstants.appVersion),
                _buildInfoTile('Препаратов в реестре', '${AppConstants.totalRegistryDrugs}'),
                _buildInfoTile('Препаратов для калькулятора', '${AppConstants.totalCalcDrugs}'),
                _buildInfoTile('Болезней (инфекц.)', '${AppConstants.totalContagiousDiseases}'),
                _buildInfoTile('Болезней (незаразн.)', '${AppConstants.totalNonContagiousDiseases}'),
                _buildInfoTile('Протоколов лечения', '${AppConstants.totalProtocols}'),
                _buildInfoTile('Взаимодействий', '${AppConstants.totalInteractions}'),
                _buildInfoTile('Антидотов', '${AppConstants.totalAntidotes}'),
                _buildInfoTile('Экстренных протоколов', '${AppConstants.totalEmergencyProtocols}'),
                _buildInfoTile('Записей побочных эфф.', '${AppConstants.totalSideEffectEntries}'),
                _buildInfoTile('API', 'GLM-4-Flash + GLM-4.6V (Z AI)'),
                _buildInfoTile('RAG KB', '12 024 чанков, FAISS TF-IDF'),
              ],
            ),
          ),

          // Architecture info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppCard.tinted(
                tintColor: AppColorsResolver.tertiarySurface(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.architecture_rounded, size: 18, color: AppColors.systemPurple),
                        const SizedBox(width: 8),
                        Text(
                          'Архитектура VetEco',
                          style: AppTypography.headline.copyWith(color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'VetEco объединяет 4 модуля:\n'
                      '• Записи (голос → SOAP медкарта)\n'
                      '• Калькулятор дозировок (2401 препарат)\n'
                      '• AI (GLM-4-Flash + RAG + VLM-4V)\n'
                      '• VetLearn (обучающая платформа)\n\n'
                      'Zero Cost: GLM бесплатный тир, HF Spaces RAG',
                      style: AppTypography.footnote.copyWith(
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _openVetLearn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _VetLearnScreen(),
      ),
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryTextColor = AppColorsResolver.textSecondary(context);
    final tertiaryTextColor = AppColorsResolver.textTertiary(context);
    return AppCard.standard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.headline.copyWith(color: textColor)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.footnote.copyWith(color: secondaryTextColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: tertiaryTextColor),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final secondaryTextColor = AppColorsResolver.textSecondary(context);
    final surfaceColor = AppColorsResolver.surface(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(icon, size: 16, color: secondaryTextColor),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: AppTypography.caption1.copyWith(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard.standard(
            padding: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryTextColor = AppColorsResolver.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body.copyWith(color: textColor)),
                Text(subtitle, style: AppTypography.footnote.copyWith(color: secondaryTextColor)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryTextColor = AppColorsResolver.textSecondary(context);
    final tertiaryTextColor = AppColorsResolver.textTertiary(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body.copyWith(color: textColor)),
                  Text(
                    subtitle,
                    style: AppTypography.footnote.copyWith(color: secondaryTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: tertiaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondaryTextColor = AppColorsResolver.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.body.copyWith(color: textColor)),
          Text(value, style: AppTypography.body.copyWith(color: secondaryTextColor)),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String mode, String label, IconData icon, ThemeProvider provider) {
    final textColor = AppColorsResolver.textPrimary(context);
    final secondary = AppColorsResolver.textSecondary(context);
    final primary = AppColorsResolver.primary(context);
    final isSelected = provider.mode == mode;
    return InkWell(
      onTap: () => provider.setMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? primary : secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTypography.body.copyWith(color: textColor)),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 20, color: primary),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(Color primaryColor, Color surfaceColor, Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Выберите модель',
                style: AppTypography.headline.copyWith(color: textColor),
              ),
            ),
            ...['glm-4-flash', 'glm-4', 'glm-4v-flash'].map(
              (model) => ListTile(
                title: Text(model),
                trailing: _glmModel == model
                    ? Icon(Icons.check, color: primaryColor)
                    : null,
                onTap: () {
                  setState(() => _glmModel = model);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// Встроенный VetLearn экран
class _VetLearnScreen extends StatefulWidget {
  const _VetLearnScreen();

  @override
  State<_VetLearnScreen> createState() => _VetLearnScreenState();
}

class _VetLearnScreenState extends State<_VetLearnScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка загрузки: ${error.description}'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(ApiConfig.vetlearnUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VetLearn'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
