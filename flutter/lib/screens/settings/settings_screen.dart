import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/theme_provider.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final tertiaryTextColor = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

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
                  // VetLearn card
                  _buildNavCard(
                    icon: Icons.school,
                    iconColor: AppColors.systemBlue,
                    title: 'VetLearn',
                    subtitle: 'Обучающая платформа для ветеринаров',
                    onTap: () => _openVetLearn(),
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // VLM standalone
                  _buildNavCard(
                    icon: Icons.visibility,
                    iconColor: AppColors.systemPurple,
                    title: 'VLM Диагностика',
                    subtitle: 'Быстрый доступ к анализу изображений',
                    onTap: () {
                      // Switch to AI tab and then VLM sub-tab
                      // This is handled by the main navigation
                    },
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    isDark: isDark,
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
              surfaceColor: surfaceColor,
              secondaryTextColor: secondaryTextColor,
              isDark: isDark,
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return _buildSwitchTile(
                      title: 'Тёмная тема',
                      subtitle: 'Переключить на тёмную тему',
                      value: themeProvider.isDarkMode,
                      onChanged: (v) => themeProvider.setDarkMode(v),
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      primaryColor: primaryColor,
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
              surfaceColor: surfaceColor,
              secondaryTextColor: secondaryTextColor,
              isDark: isDark,
              children: [
                _buildNavigationTile(
                  title: 'Модель GLM',
                  subtitle: _glmModel,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  tertiaryTextColor: tertiaryTextColor,
                  onTap: () => _showModelPicker(primaryColor, surfaceColor, textColor),
                ),
                _buildNavigationTile(
                  title: 'RAG API',
                  subtitle: '${ApiConfig.hfSpaceUrl}${ApiConfig.ragApiPath}',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  tertiaryTextColor: tertiaryTextColor,
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
              surfaceColor: surfaceColor,
              secondaryTextColor: secondaryTextColor,
              isDark: isDark,
              children: [
                _buildInfoTile('Версия', AppConstants.appVersion, textColor, secondaryTextColor),
                _buildInfoTile('Препаратов в реестре', '${AppConstants.totalRegistryDrugs}', textColor, secondaryTextColor),
                _buildInfoTile('Болезней', '${AppConstants.totalDiseases}', textColor, secondaryTextColor),
                _buildInfoTile('API', 'GLM-4-Flash (бесплатно)', textColor, secondaryTextColor),
              ],
            ),
          ),

          // Architecture info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Card(
                color: surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.architecture, size: 18, color: AppColors.systemPurple),
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
                        style: AppTypography.footnote.copyWith(color: secondaryTextColor),
                      ),
                    ],
                  ),
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
    required Color surfaceColor,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
    return Card(
      color: surfaceColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(15),
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
                    Text(subtitle, style: AppTypography.footnote.copyWith(color: secondaryTextColor)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required Color surfaceColor,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
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
          Card(
            color: surfaceColor,
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
    required Color textColor,
    required Color secondaryTextColor,
    required Color primaryColor,
  }) {
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
            activeColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textColor,
    required Color secondaryTextColor,
    required Color tertiaryTextColor,
  }) {
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
            Icon(Icons.chevron_right, size: 18, color: tertiaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, Color textColor, Color secondaryTextColor) {
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
