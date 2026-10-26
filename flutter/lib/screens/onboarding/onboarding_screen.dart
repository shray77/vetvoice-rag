import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../terms/terms_screen.dart';
import '../../theme/ds.dart';

/// Onboarding экран — показывается ОДИН раз при первом запуске.
/// Флаг 'onboarding_complete' сохраняется в SharedPreferences.
/// Последняя страница — юридическая: без чекбокса согласия кнопка
/// «Принять и начать» неактивна, «Пропустить» убран (иначе согласие
/// обходилось молча — юр-слой терял смысл).
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _animController;
  int _currentPage = 0;
  bool _acceptedTerms = false;

  /// Число фич-слайдов; последний индекс — слайд согласия с условиями.
  int get _featurePages => _pages.length;
  int get _lastIndex => _pages.length; // + 1 юридический слайд

  static const _pages = [
    _OnboardingPage(
      icon: Icons.pets_rounded,
      title: 'Животные',
      subtitle: 'Выберите вид — КРС, собаки, кошки, птица и другие',
      color: AppColors.primary,
    ),
    _OnboardingPage(
      icon: Icons.calculate_rounded,
      title: 'Калькулятор доз',
      subtitle: '2 401 препарат с автоматическим расчётом по весу',
      color: AppColors.systemBlue,
    ),
    _OnboardingPage(
      icon: Icons.smart_toy_rounded,
      title: 'AI-ассистент',
      subtitle: 'RAG-поиск по 12 000 чанков + VLM-диагностика изображений',
      color: AppColors.systemPurple,
    ),
    _OnboardingPage(
      icon: Icons.menu_book_rounded,
      title: 'Справочник',
      subtitle: '187 болезней, 154 протокола, 73 взаимодействия, 17 антидотов',
      color: AppColors.systemOrange,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    widget.onComplete();
  }

  void _nextPage() {
    if (_currentPage < _lastIndex) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: AppCurves.decelerate,
      );
    } else if (_acceptedTerms) {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColorsResolver.primary(context);
    final textColor = AppColorsResolver.textPrimary(context);
    final secondary = AppColorsResolver.textSecondary(context);

    return Scaffold(
      backgroundColor: AppColorsResolver.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _featurePages + 1,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  _animController.reset();
                  _animController.forward();
                },
                itemBuilder: (context, i) {
                  if (i >= _featurePages) return _buildTermsPage(context);
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: CurvedAnimation(
                            parent: _animController,
                            curve: AppCurves.decelerate,
                          ),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: page.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(page.icon, size: 56, color: page.color),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          page.title,
                          style: AppTypography.largeTitle.copyWith(color: textColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          page.subtitle,
                          style: AppTypography.body.copyWith(color: secondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_featurePages + 1, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? primary : primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                0,
                AppSpacing.screenPadding,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: AppCurves.decelerate,
                      ),
                      child: Text('Назад', style: AppTypography.body.copyWith(color: secondary)),
                    ),
                  const Spacer(),
                  FilledButton(
                    // На юридическом слайде кнопка неактивна, пока не отмечено согласие.
                    onPressed: (_currentPage == _lastIndex && !_acceptedTerms)
                        ? null
                        : _nextPage,
                    child: Text(
                      _currentPage == _lastIndex
                          ? (_acceptedTerms ? 'Принять и начать' : 'Отметьте согласие')
                          : 'Далее',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Юридический слайд: краткий дисклеймер + чекбокс согласия +
  /// ссылка на полный текст условий (экран TermsScreen).
  Widget _buildTermsPage(BuildContext context) {
    final primary = AppColorsResolver.primary(context);
    final textColor = AppColorsResolver.textPrimary(context);
    final secondary = AppColorsResolver.textSecondary(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.health_and_safety_rounded,
                size: 46, color: AppColors.warning),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Важно знать',
            style: AppTypography.title2.copyWith(color: textColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ВетЭко — информационный сервис «как есть». Ответы AI, справочники и расчёты доз не являются диагнозом или назначением. ИИ может ошибаться: проверяйте результаты по официальным инструкциям и консультируйтесь с ветеринарным врачом — даже если вы сами ветеринарный врач.',
            style: AppTypography.body.copyWith(color: secondary, height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          InkWell(
            onTap: () {
              Navigator.of(context).push(DsRoute<void>(
                builder: (_) => const TermsScreen(),
              ));
            },
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_rounded, size: 18, color: primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Условия использования и дисклеймер',
                        style: AppTypography.callout.copyWith(
                          color: primary,
                          decoration: TextDecoration.underline,
                          decorationColor: primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          InkWell(
            onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) =>
                          setState(() => _acceptedTerms = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Я принимаю условия использования и дисклеймер',
                      style: AppTypography.bodyMedium.copyWith(color: textColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

/// Проверяет, нужно ли показать onboarding.
Future<bool> shouldShowOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool('onboarding_complete') ?? false);
}
