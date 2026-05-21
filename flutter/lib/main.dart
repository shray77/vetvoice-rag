import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'providers/vet_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/vlm_provider.dart';
import 'providers/notes_provider.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/dose_calc/dose_calc_screen.dart';
import 'screens/ai_assistant/ai_assistant_screen.dart';
import 'screens/vetlearn/vetlearn_screen.dart';
import 'screens/vlm/vlm_screen.dart';
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
        ChangeNotifierProvider(create: (_) => VetProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
        ChangeNotifierProvider(create: (_) => VlmProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()..initialize()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainNavigation(),
      ),
    );
  }
}

/// Главная навигация — 6 табов
/// Записи → Калькулятор → AI → VetLearn → Зрение → Настройки
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
    AiAssistantScreen(),  // 2 — AI-ассистент (RAG)
    VetlearnScreen(),     // 3 — VetLearn WebView
    VlmScreen(),          // 4 — VLM зрение (авто-результат)
    SettingsScreen(),     // 5 — Настройки
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.separator, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            HapticFeedback.selectionClick();
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description),
              label: 'Записи',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calculate_outlined),
              activeIcon: Icon(Icons.calculate),
              label: 'Дозы',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: 'AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school),
              label: 'Учёба',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.visibility_outlined),
              activeIcon: Icon(Icons.visibility),
              label: 'Зрение',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Ещё',
            ),
          ],
        ),
      ),
    );
  }
}
