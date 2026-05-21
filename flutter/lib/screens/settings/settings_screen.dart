import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

/// Экран настроек
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSpeak = true;
  bool _wakeWord = false;
  bool _darkMode = false;
  String _glmModel = 'glm-4-flash';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSpeak = prefs.getBool('auto_speak') ?? true;
      _wakeWord = prefs.getBool('wake_word') ?? false;
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _glmModel = prefs.getString('glm_model') ?? 'glm-4-flash';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                'Настройки',
                style: AppTypography.largeTitle.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),

          // Voice section
          SliverToBoxAdapter(
            child: _buildSection(
              title: 'Голос',
              icon: Icons.mic_outlined,
              children: [
                _buildSwitchTile(
                  title: 'Автоозвучивание',
                  subtitle: 'Озвучивать результат расчёта',
                  value: _autoSpeak,
                  onChanged: (v) {
                    setState(() => _autoSpeak = v);
                    _saveSetting('auto_speak', v);
                  },
                ),
                _buildSwitchTile(
                  title: 'Wake Word «ВетВойс»',
                  subtitle: 'Активация голосом как Ok Google',
                  value: _wakeWord,
                  onChanged: (v) {
                    setState(() => _wakeWord = v);
                    _saveSetting('wake_word', v);
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
                  onTap: () => _showModelPicker(),
                ),
                _buildNavigationTile(
                  title: 'RAG Endpoint',
                  subtitle: ApiConfig.ragEndpoint.isEmpty
                      ? 'Не настроен'
                      : ApiConfig.ragEndpoint,
                  onTap: () {
                    // TODO: Configure RAG endpoint
                  },
                ),
                _buildNavigationTile(
                  title: 'VLM Endpoint',
                  subtitle: ApiConfig.vlmEndpoint.isEmpty
                      ? 'Не настроен'
                      : ApiConfig.vlmEndpoint,
                  onTap: () {
                    // TODO: Configure VLM endpoint
                  },
                ),
              ],
            ),
          ),

          // Appearance section
          SliverToBoxAdapter(
            child: _buildSection(
              title: 'Оформление',
              icon: Icons.palette_outlined,
              children: [
                _buildSwitchTile(
                  title: 'Тёмная тема',
                  subtitle: 'Переключить на тёмную тему',
                  value: _darkMode,
                  onChanged: (v) {
                    setState(() => _darkMode = v);
                    _saveSetting('dark_mode', v);
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
                _buildInfoTile('Болезней', '${AppConstants.totalDiseases}'),
                _buildInfoTile('API', 'GLM-4-Flash (бесплатно)'),
              ],
            ),
          ),

          // Architecture info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Card(
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
                            'Архитектура экосистемы',
                            style: AppTypography.headline.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'VetEcosystem объединяет 4 модуля:\n'
                        '• Калькулятор дозировок (голосовой)\n'
                        '• AI-ассистент (GLM + RAG)\n'
                        '• VetLearn (WebView)\n'
                        '• VLM диагностика (GLM-4V / HF Spaces)\n\n'
                        'Zero Cost: GLM бесплатный тир, HF Spaces, Kaggle GPU',
                        style: AppTypography.footnote.copyWith(color: AppColors.textSecondary),
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: AppTypography.caption1.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
                Text(subtitle, style: AppTypography.footnote.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
                  Text(subtitle, style: AppTypography.footnote.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
          Text(value, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
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
                style: AppTypography.headline.copyWith(color: AppColors.textPrimary),
              ),
            ),
            ...['glm-4-flash', 'glm-4', 'glm-4v-flash'].map(
              (model) => ListTile(
                title: Text(model),
                trailing: _glmModel == model
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _glmModel = model);
                  _saveSetting('glm_model', model);
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
