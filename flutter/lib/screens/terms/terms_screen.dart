import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../../core/widgets/app_components.dart';

/// Условия использования и дисклеймер — офлайн-версия для приложения.
/// Полная версия: https://shray77.github.io/terms.html (ред. от 30.10.2026).
///
/// Текст согласован с canonical-страницей экосистемы VetInSilico; здесь он
/// сжат до разделов, значимых для мобильного приложения (калькулятор,
/// AI-RAG, VLM-диагностика, локальные данные). Ред. 3 (Task 200):
/// + применимое право, ИС, статус издания — юр-слой v3 экосистемы.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const _fullVersionUrl = 'https://shray77.github.io/terms.html';

  @override
  Widget build(BuildContext context) {
    final secondary = AppColorsResolver.textSecondary(context);

    return Scaffold(
      backgroundColor: AppColorsResolver.background(context),
      appBar: AppBar(
        title: const Text('Условия и дисклеймер'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _Section(
            title: 'Коротко',
            highlight: true,
            children: [
              _bullet(context, 'Приложение — информационный сервис «как есть», без гарантий полноты, точности и доступности.'),
              _bullet(context, 'Это не ветеринарная консультация: решения принимайте только с ветеринарным врачом — даже если вы сами ветеринарный врач.'),
              _bullet(context, 'Данные и базы обрабатываются автоматически, возможны ошибки и пропуски — проверяйте по первоисточникам и инструкциям к препаратам.'),
              _bullet(context, 'Калькуляторы и расчёты — для проверки гипотез: перепроверяйте результаты вручную перед клиническим применением.'),
            ],
          ),
          _Section(
            title: 'Не ветеринарная консультация',
            children: [
              _para(context,
                  'Справочники, протоколы, RAG-ответы, VLM-анализ фотографий и медкарты не являются ветеринарной консультацией, диагнозом, назначением или схемой лечения. Решения о здоровье, лечении и содержании животных принимает только ветеринарный врач, осмотревший животное.'),
              _para(context,
                  'Консультируйтесь с ветеринарным врачом, даже если вы сами ветеринарный врач. Базы могут быть неполными, устаревшими или ошибочными и не заменяют клинический осмотр, лабораторную диагностику и профессиональное суждение.'),
            ],
          ),
          _Section(
            title: 'Расчёты и калькуляторы доз',
            children: [
              _para(context,
                  'Любые автоматические расчёты дозировок, инфузионной терапии и каренции предоставлены исключительно для ознакомления и проверки гипотез. Ошибка возможна и без ИИ — из-за опечатки в формуле, данных или конфигурации. Перепроверяйте все результаты вычислений вручную по официальным инструкциям к препаратам перед любым клиническим применением.'),
            ],
          ),
          _Section(
            title: 'Автоматическая обработка данных и ИИ',
            children: [
              _para(context,
                  'AI-ассистент (RAG-поиск, генерация медкарт) и VLM-диагностика изображений работают на моделях искусственного интеллекта. ИИ ошибается: возможны ложные срабатывания, пропуски значимых событий, неточности в пересказе и неверная привязка болезни, препарата или дозы. Результаты — метки внимания для быстрого просмотра, а не проверенные человеком утверждения.'),
            ],
          ),
          _Section(
            title: '«Как есть» и ограничение ответственности',
            children: [
              _para(context,
                  'Приложение предоставляется «как есть» и «как доступно». Автор не предоставляет никаких явных или подразумеваемых гарантий, включая гарантии товарной пригодности, соответствия конкретной цели, точности, полноты и бесперебойной работы.'),
              _para(context,
                  'Автор не несёт ответственности за любые прямые или косвенные убытки, упущенную выгоду, а также вред животным, людям или имуществу, возникшие в результате использования или неиспользования приложения — в максимальной степени, допускаемой применимым правом.'),
            ],
          ),
          _Section(
            title: 'Интеллектуальная собственность',
            children: [
              _para(context,
                  'Исходный код приложения и веб-сервиса публикуется в открытом репозитории под лицензией MIT (текст — в файле LICENSE). Модели ИИ (языковые, VLM, эмбеддинги) принадлежат их разработчикам и используются на условиях их лицензий. Состав справочных баз собран из открытых источников (реестры, инструкции, справочники) и принадлежит первоисточникам; приложение не передаёт и не лицензирует права на эти данные.'),
            ],
          ),
          _Section(
            title: 'Статус издания и реклама',
            children: [
              _para(context,
                  'Приложение не является средством массовой информации (сетевым изданием) в смысле Закона РФ «О СМИ». Проект некоммерческий: реклама, платные размещения и спонсорские публикации отсутствуют, товары и услуги не продаются; упоминания организаций, препаратов и продуктов носят информационный характер и рекламой не являются. Материалы ориентированы на специалистов ветеринарной медицины и смежных областей.'),
            ],
          ),
          _Section(
            title: 'Приватность',
            children: [
              _para(context,
                  'Записи, история расчётов, избранное и настройки хранятся локально на вашем устройстве и не покидают его. Для работы AI-функций текст запроса и изображения (при VLM-анализе) передаются на внешние сервисы обработки; не отправляйте в чат персональные данные, если это недопустимо в вашем случае. Доступ к внешним сервисам выполняется через ваш собственный API-ключ, хранящийся только на устройстве.'),
            ],
          ),
          _Section(
            title: 'Применимое право и споры',
            children: [
              _para(context,
                  'К настоящим условиям и использованию приложения применяется законодательство Российской Федерации. Замечания и возражения направляются автору через GitHub Issues репозитория; спор, не урегулированный перепиской, подлежит рассмотрению судом по месту нахождения ответчика. Признание отдельного положения недействительным не затрагивает остальных условий.'),
            ],
          ),
          _Section(
            title: 'Изменение условий',
            children: [
              _para(context,
                  'Условия могут быть изменены в любой момент без предварительного уведомления; актуальная версия — на странице полной версии. Продолжение использования приложения после обновления означает согласие с новыми условиями.'),
            ],
          ),
          _Section(
            title: 'Полная версия',
            children: [
              _para(context,
                  'Полные условия экосистемы VetInSilico (включая разделы об источниках данных, официальных решениях и ссылках на третьи стороны):'),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: _fullVersionUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ссылка скопирована'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_rounded, size: 16, color: AppColorsResolver.primary(context)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _fullVersionUrl,
                        style: AppTypography.footnote.copyWith(
                          color: AppColorsResolver.primary(context),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, size: 14, color: secondary),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Версия от 30.10.2026 (ред. 3) · VetInSilico',
                style: AppTypography.caption2.copyWith(color: secondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    final primary = AppColorsResolver.primary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColorsResolver.textPrimary(context),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _para(BuildContext context, String text) {
    return Text(
      text,
      style: AppTypography.bodyMedium.copyWith(
        color: AppColorsResolver.textSecondary(context),
        height: 1.5,
      ),
    );
  }
}

/// Секция условий — карточка с заголовком и содержимым.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool highlight;

  const _Section({
    required this.title,
    required this.children,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        backgroundColor: highlight
            ? (isDark
                ? AppColors.primaryContainerDark
                : AppColors.primaryContainer)
            : null,
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.sectionTitle.copyWith(
                color: AppColorsResolver.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}
