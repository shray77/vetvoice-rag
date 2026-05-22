import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'providers/vet_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/vlm_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/dose_calc/dose_calc_screen.dart';
import 'screens/ai_assistant/ai_assistant_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const VetEcoApp());
}

class VetEcoApp extends StatelessWidget {
  const VetEcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => VetProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
        ChangeNotifierProvider(create: (_) => VlmProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()..initialize()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const MainNavigation(),
          );
        },
      ),
    );
  }
}

/// Главная навигация — 4 таба
/// Записи → Калькулятор → AI (Чат + VLM) → Ещё
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    NotesScreen(),        // 0 — Записи (главный экран)
    DoseCalcScreen(),     // 1 — Калькулятор дозировок
    AiAssistantScreen(),  // 2 — AI (Чат + VLM с табами внутри)
    SettingsScreen(),     // 3 — Настройки + VetLearn
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkSeparator : AppColors.separator,
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            HapticFeedback.selectionClick();
          },
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          indicatorColor: primaryColor.withAlpha(30),
          height: 64,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.description_outlined, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
              selectedIcon: Icon(Icons.description, color: primaryColor),
              label: 'Записи',
            ),
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
              selectedIcon: Icon(Icons.calculate, color: primaryColor),
              label: 'Дозы',
            ),
            NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
              selectedIcon: Icon(Icons.smart_toy, color: primaryColor),
              label: 'AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_outlined, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
              selectedIcon: Icon(Icons.menu, color: primaryColor),
              label: 'Ещё',
            ),
          ],
        ),
      ),
    );
  }
}
