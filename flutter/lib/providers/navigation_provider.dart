import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Глобальная навигация между 4 табами + запрос под-вкладки VLM в экране AI.
///
/// Позволяет экрану «Ещё» (Settings) переключить нижнюю навигацию на
/// вкладку AI и попросить [AiAssistantScreen] открыть под-вкладку «Зрение VLM».
class NavigationProvider extends ChangeNotifier {
  static const int notesTab = 0;
  static const int doseCalcTab = 1;
  static const int aiHubTab = 2;
  static const int moreTab = 3;

  int _currentIndex = notesTab;
  int get currentIndex => _currentIndex;

  bool _requestVlm = false;
  bool get requestVlm => _requestVlm;

  void setIndex(int index) {
    if (index == _currentIndex) return;
    _currentIndex = index;
    HapticHelper.selection();
    notifyListeners();
  }

  /// Переключиться на вкладку AI и запросить под-вкладку «Зрение VLM».
  void goToAiVlm() {
    _requestVlm = true;
    _currentIndex = aiHubTab;
    HapticHelper.selection();
    notifyListeners();
  }

  void clearRequestVlm() {
    if (!_requestVlm) return;
    _requestVlm = false;
    notifyListeners();
  }
}
