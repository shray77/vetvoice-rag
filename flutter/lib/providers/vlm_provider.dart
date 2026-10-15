import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../services/glm_ai_service.dart';
import '../services/backend_rag_service.dart';

/// Провайдер VLM (Vision Language Model) диагностики
/// Стратегия: GLM-4V напрямую + опциональный RAG контекст из HF Space
/// Это надёжнее чем Gradio API с файлами (который даёт 400 на изображениях)
class VlmProvider extends ChangeNotifier {
  final GlmAiService _aiService = GlmAiService();
  final BackendRagService _backend = BackendRagService();

  // Изображение
  String? _imageBase64;
  String? _imagePath;

  // Результат
  String _analysisResult = '';
  bool _isAnalyzing = false;
  String _error = '';

  // Режим анализа
  VlmAnalysisMode _mode = VlmAnalysisMode.diagnose;
  String _modelUsed = '';

  // Авто-анализ
  bool _autoAnalyze = true;

  String? get imageBase64 => _imageBase64;
  String? get imagePath => _imagePath;
  String get analysisResult => _analysisResult;
  bool get isAnalyzing => _isAnalyzing;
  String get error => _error;
  bool get hasImage => _imageBase64 != null;
  bool get hasResult => _analysisResult.isNotEmpty;
  VlmAnalysisMode get mode => _mode;
  String get modelUsed => _modelUsed;
  bool get autoAnalyze => _autoAnalyze;

  /// Установить изображение для анализа
  void setImage(String base64, {String? path}) {
    _imageBase64 = base64;
    _imagePath = path;
    _analysisResult = '';
    _error = '';
    _modelUsed = '';
    notifyListeners();

    if (_autoAnalyze) {
      analyzeImage();
    }
  }

  /// Включить/выключить авто-анализ
  void setAutoAnalyze(bool value) {
    _autoAnalyze = value;
    notifyListeners();
  }

  /// Выбрать режим анализа
  void setMode(VlmAnalysisMode newMode) {
    _mode = newMode;
    notifyListeners();

    if (_autoAnalyze && _imageBase64 != null && _analysisResult.isNotEmpty) {
      analyzeImage();
    }
  }

  /// Проанализировать изображение
  Future<void> analyzeImage() async {
    if (_imageBase64 == null) return;

    _isAnalyzing = true;
    _error = '';
    notifyListeners();

    try {
      // 1. Получаем RAG контекст (текстовый запрос, надёжный)
      String? ragContext = await _fetchRagContext();

      // 2. Вызываем GLM-4V напрямую с изображением + RAG контекст
      final prompt = _buildPrompt(ragContext: ragContext);
      final result = await _aiService.analyzeImage(
        imageBase64: _imageBase64!,
        prompt: prompt,
      );

      _analysisResult = result;
      _modelUsed = ragContext != null
          ? 'GLM-4V + RAG'
          : 'GLM-4V Flash';
    } catch (e) {
      _error = 'Ошибка анализа: $e';
      debugPrint('VLM error: $e');
    }

    _isAnalyzing = false;
    notifyListeners();
  }

  /// Получить RAG контекст из VetEco FastAPI backend.
  /// Надёжнее хрупкого Gradio HF Space API (event_id + SSE-поллинг).
  Future<String?> _fetchRagContext() async {
    HapticHelper.light();
    final apiKey = await _aiService.getApiKey();
    // Для VLM берём релевантный контекст по ключевым терминам дерматологии.
    final context = await _backend.fetchRagContext(
      'дерматология кожа диагноз лечение поражения',
      apiKey: apiKey,
    );
    if (context != null && context.length > 3000) {
      return context.substring(0, 3000);
    }
    return context;
  }

  /// Построить промпт с учётом режима и RAG контекста
  String _buildPrompt({String? ragContext}) {
    final basePrompt = _modeToPrompt();
    if (ragContext != null && ragContext.isNotEmpty) {
      return '$basePrompt\n\n## Контекст из ветеринарной базы знаний:\n$ragContext\n\nИспользуй этот контекст для более точного анализа.';
    }
    return basePrompt;
  }

  /// Маппинг режима в промпт
  String _modeToPrompt() {
    return switch (_mode) {
      VlmAnalysisMode.diagnose =>
        '''You are a veterinary dermatologist examining a photo of an animal's skin condition. Provide analysis in Russian.

### First Analysis
- **Patient:** species, breed (if identifiable)
- **Lesion type:** primary + secondary lesions
- **Localization:** body regions
- **Pruritus:** present/absent, severity

### Differential Diagnosis (by probability)
1. **[Diagnosis]** — probability [%] — reasoning
2. **[Diagnosis]** — probability [%] — reasoning
3. **[Diagnosis]** — probability [%] — reasoning

### Recommended Diagnostic Tests
1. [Test] — purpose

### Treatment Recommendations
**Systemic therapy:** drug, dosage (мг/кг), route, duration
**Topical therapy:** drug, frequency, duration
**Monitoring:** what to check

Respond in Russian.
Add: Это AI-ассистированный анализ, не ветеринарный диагноз. Обратитесь к лицензированному ветеринару.''',
      VlmAnalysisMode.describe =>
        'Детально опиши видимые поражения на изображении: морфология, распределение, локализация. Используй ветеринарную терминологию. Отвечай на русском языке.',
      VlmAnalysisMode.severity =>
        'Оцени тяжесть видимого состояния: лёгкая, средняя или тяжёлая. Объясни почему. Укажи прогноз. Отвечай на русском языке.',
      VlmAnalysisMode.treatment =>
        'На основе видимого поражения, предложи подход к лечению. Укажи препараты, дозировки (мг/кг), путь введения, кратность, длительность. Отвечай на русском языке.',
      VlmAnalysisMode.skin =>
        'Определи ветеринарное дерматологическое заболевание на изображении. Укажи диагноз, характеристики, дифференциальный диагноз и лечение. Отвечай на русском языке.',
    };
  }

  /// Сброс
  void reset() {
    _imageBase64 = null;
    _imagePath = null;
    _analysisResult = '';
    _error = '';
    _modelUsed = '';
    notifyListeners();
  }
}

/// Режимы анализа VLM
enum VlmAnalysisMode {
  diagnose,   // Диагноз
  describe,   // Описание поражений
  severity,   // Оценка тяжести
  treatment,  // Рекомендации по лечению
  skin,       // Дерматология
}
