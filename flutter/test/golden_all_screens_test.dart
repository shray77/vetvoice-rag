// Golden-рендер всех экранов VetEco для визуального аудита.
// Запуск (создание/обновление PNG): flutter test --update-goldens test/golden_all_screens_test.dart
// PNG складываются в test/golden/.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:veteco/core/theme/app_theme.dart';
import 'package:veteco/services/data_load_service.dart';
import 'package:veteco/providers/vet_provider.dart';
import 'package:veteco/providers/ai_provider.dart';
import 'package:veteco/providers/vlm_provider.dart';
import 'package:veteco/providers/notes_provider.dart';
import 'package:veteco/providers/theme_provider.dart';
import 'package:veteco/providers/navigation_provider.dart';
import 'package:veteco/screens/notes/notes_screen.dart';
import 'package:veteco/screens/dose_calc/dose_calc_screen.dart';
import 'package:veteco/screens/ai_assistant/ai_assistant_screen.dart';
import 'package:veteco/screens/settings/settings_screen.dart';
import 'package:veteco/screens/onboarding/onboarding_screen.dart';
import 'package:veteco/screens/reference/reference_screen.dart';
import 'package:veteco/screens/terms/terms_screen.dart';
import 'package:veteco/main.dart';

enum _Flavor { light, dark, night }

Widget _wrap(Widget screen, {required _Flavor flavor}) {
  final dark = flavor != _Flavor.light;
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => VetProvider()..initialize()),
      ChangeNotifierProvider(create: (_) => AiProvider()),
      ChangeNotifierProvider(create: (_) => VlmProvider()),
      ChangeNotifierProvider(create: (_) => NotesProvider()..initialize()),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: flavor == _Flavor.night ? AppTheme.nightTheme : AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: screen,
    ),
  );
}

Future<void> _render(WidgetTester tester, Widget screen, String name,
    {required Size logical, required _Flavor flavor}) async {
  final dpr = 2.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(logical.width * dpr, logical.height * dpr);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(screen, flavor: flavor));
  // Ждём окончания загрузки баз (DataLoadService ~1.1s) — иначе кадр
  // снимается в состоянии «Загрузка баз препаратов...».
  for (int i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    try {
      final p = tester.element(find.byType(screen.runtimeType)).readProvider<VetProvider>();
      if (!p.isLoading) break;
    } catch (_) {
      break; // экран без провайдера в дереве — снимаем как есть
    }
  }
  await tester.pump(const Duration(milliseconds: 300));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('golden/$name.png'),
  );
}

/// Шрифт из кеша SDK: FLUTTER_ROOT (CI, ставит subosito/flutter-action)
/// → жёсткий путь песочницы разработки. null = нет нигде (FONT MISSING).
String? _sdkFont(String name) {
  final fr = Platform.environment['FLUTTER_ROOT'] ?? '';
  for (final d in [
    if (fr.isNotEmpty) '$fr/bin/cache/artifacts/material_fonts',
    '/home/z/flutter/bin/cache/artifacts/material_fonts',
  ]) {
    final f = File('$d/$name');
    if (f.existsSync()) return f.path;
  }
  return null;
}

Future<void> _loadRealFonts() async {
  // Реальные шрифты вместо Ahem — иначе кириллица рисуется тофу-квадратами.
  // v1.1.1: в семью Roboto добавлен NotoColorEmoji — эмодзи-иконки животных
  // (🐄🐑🐴) в golden-кадрах рисуются как в приложении, а не тофу.
  final families = <String, List<String?>>{
    'Roboto': [
      _sdkFont('Roboto-Regular.ttf'),
      _sdkFont('Roboto-Medium.ttf'),
      _sdkFont('Roboto-Bold.ttf'),
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    ],
    'MaterialIcons': [_sdkFont('MaterialIcons-Regular.otf')],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final path in e.value) {
      if (path == null) {
        // ignore: avoid_print
        print('FONT MISSING: ${e.key}');
        continue;
      }
      final f = File(path);
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
      }
    }
    await loader.load();
  }
  // AssetManifest-мок не нужен: иконки/шрифты грузятся через FontLoader выше.
}

Future<void> _mockAssetsChannel() async {
  // В widget-тестах платформенный канал 'flutter/assets' не отвечает —
  // rootBundle.loadString виснет навечно. Отдаём файлы напрямую с диска.
  TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      if (message == null) return null;
      final key = utf8.decode(message.buffer.asUint8List());
      // key приходит вида '/assets/data/xxx.json' — нормализуем к файлу в flutter/.
      final rel = key.startsWith('/') ? key.substring(1) : key;
      final f = File(rel.startsWith('assets/') ? rel : 'assets/$rel');
      if (f.existsSync()) {
        return ByteData.view(f.readAsBytesSync().buffer);
      }
      // ignore: avoid_print
      print('MISSING ASSET MOCK: $key');
      return null;
    },
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await _mockAssetsChannel();
    await _loadRealFonts();
    // ВАЖНО: грузим базы ВНЕ testWidgets fake-async зоны — там канальные
    // ответы rootBundle не доставляются и isLoading висит вечно. Синглтон
    // DataLoadService прогреется здесь, а в тестах initialize() вернётся мгновенно.
    final svc = DataLoadService();
    await svc.loadAll();
    // ignore: avoid_print
    print('PRELOADED: calc=${svc.calcDrugs.length} loaded=${svc.isLoaded}');
  });

  for (final e in <String, Widget Function()>{
    '01_onboarding_light': () => OnboardingScreen(onComplete: () {}),
    '02_onboarding_dark': () => OnboardingScreen(onComplete: () {}),
    '03_notes_light': () => const NotesScreen(),
    '04_notes_dark': () => const NotesScreen(),
    '05_notes_small': () => const NotesScreen(),
    '06_dose_light': () => const DoseCalcScreen(),
    '07_dose_dark': () => const DoseCalcScreen(),
    '08_dose_small': () => const DoseCalcScreen(),
    '09_ai_light': () => const AiAssistantScreen(),
    '11_ai_dark': () => const AiAssistantScreen(),
    '12_ai_small': () => const AiAssistantScreen(),
    '13_settings_light': () => const SettingsScreen(),
    '14_settings_dark': () => const SettingsScreen(),
    '15_reference_light': () => const ReferenceScreen(),
    '16_reference_dark': () => const ReferenceScreen(),
    '17_terms_light': () => const TermsScreen(),
    '18_terms_dark': () => const TermsScreen(),
    '20_shell_light': () => const MainNavigation(),
  }.entries) {
    final name = e.key;
    final logical = name.endsWith('_small') ? const Size(320, 568) : const Size(390, 844);
    final flavor = name.endsWith('_dark') ? _Flavor.dark : _Flavor.light;
    testWidgets('golden: $name', (tester) async {
      await _render(tester, e.value(), name, logical: logical, flavor: flavor);
    });
  }

  testWidgets('golden: 21_shell_statusbar', (tester) async {
    // Симуляция статус-бара: viewPadding сверху 44 логических px.
    // Проверяет фикс v1.1.1 — SafeArea в MainNavigation отодвигает
    // largeTitle-хэдеры от статус-бара (раньше «Записи» залезали под часы).
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(780, 1688);
    final sb = FakeViewPadding(top: 44, left: 0, right: 0, bottom: 24);
    tester.view.viewPadding = sb;
    tester.view.padding = FakeViewPadding(top: 44, left: 0, right: 0, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const MainNavigation(), flavor: _Flavor.light));
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      try {
        final p = tester.element(find.byType(NotesScreen)).readProvider<VetProvider>();
        if (!p.isLoading) break;
      } catch (_) {
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/21_shell_statusbar.png'),
    );
  });

  testWidgets('golden: 10_vlm_light', (tester) async {
    await tester.pumpWidget(_wrap(const AiAssistantScreen(), flavor: _Flavor.light));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Зрение VLM'));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/10_vlm_light.png'),
    );  });

  testWidgets('golden: 19_onboarding_terms', (tester) async {
    await tester.pumpWidget(_wrap(
        OnboardingScreen(onComplete: () {}), flavor: _Flavor.light));
    await tester.pump(const Duration(milliseconds: 500));
    // Свайпы надёжнее тапов по кнопке внутри PageView.
    for (int i = 0; i < 6; i++) {
      await tester.fling(
          find.byType(PageView), const Offset(-500, 0), 1200);
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/19_onboarding_terms.png'),
    );
  });
}

extension _Read on Element {
  T readProvider<T>() => Provider.of<T>(this, listen: false);
}
